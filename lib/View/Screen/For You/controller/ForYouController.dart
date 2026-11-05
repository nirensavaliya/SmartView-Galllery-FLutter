import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/Common/MediaManager.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/For%20You/OfflineGeocoder.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/BiometricController.dart';
import 'package:gallery_photos/View/Utils/App_Routes.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class ForYouController extends GetxController {
  final BiometricController biometricController =
  Get.isRegistered<BiometricController>()
      ? Get.find<BiometricController>()
      : Get.put(BiometricController(), permanent: true);
  final RxList<AssetEntity> media = <AssetEntity>[].obs;

  final RxList<MemoryGroup> memories = <MemoryGroup>[].obs;

  final RxList<PlaceGroup> places = <PlaceGroup>[].obs;

  final Map<String, Future<Uint8List?>> memoryImageCache = {};
  static const int _maxMemoryImageCache = 30;
  final RxBool isLoading = false.obs;

  final RxBool isRefreshing = false.obs;

  final RxBool hasMore = true.obs;

  final RxString errorMessage = ''.obs;

  final ImagePicker _picker = ImagePicker();

  static const int pageSize = 100;

  /// Rebuild memories / places after this many extra pages
  static const int _rebuildEveryPages = 12;

  int currentPage = 0;

  bool isLoadingMore = false;
  final Map<String, LatLng?> _locationCache = {};
  final Map<String, String> _locationNameCache = {};
  static const Duration memoryTimeGap = Duration(hours: 6);
  static const double memoryLocationRadiusKm = 2.0;
  static const int minimumMemoryPhotos = 2;
  final RxInt videosCount = 0.obs;
  final RxInt screenshotsCount = 0.obs;
  final RxInt favoritesCount = 0.obs;
  final RxInt gifsCount = 0.obs;
  final RxInt livePhotosCount = 0.obs;
  bool _preloadStarted = false;

  /// Memories start after the photo pages, or immediately if For You is opened.
  void startPreload() {
    if (_preloadStarted || isClosed) return;
    _preloadStarted = true;
    unawaited(OfflineGeocoder.instance.warmUp());
    loadForYouMedia();
  }

  /// Splash waits on this, so For You is already filled when the app opens.
  Future<void> waitForFirstLoad({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final Stopwatch sw = Stopwatch()..start();

    // give onInit a moment to flip isLoading to true
    await Future<void>.delayed(const Duration(milliseconds: 50));

    while (isLoading.value && sw.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  Future<void> openPrivate() async {
    try {
      debugPrint('================ PRIVATE CLICK ================');

      Get.toNamed(AppRoutes.LockScreen);
    } catch (e) {
      debugPrint('PRIVATE ERROR = $e');

      AppToast.show("Private Error: ${e.toString()}");
    }
  }

  final RxSet<String> likedMemoryIds = <String>{}.obs;
  Future<Uint8List?> loadMemoryImage(AssetEntity asset) {
    final String id = asset.id;

    if (memoryImageCache.containsKey(id)) {
      return memoryImageCache[id]!;
    }
    final Future<Uint8List?> future = asset.thumbnailDataWithSize(
      const ThumbnailSize(1800, 1800),
    );

    if (memoryImageCache.length >= _maxMemoryImageCache) {
      final oldKeys = memoryImageCache.keys
          .take(memoryImageCache.length - _maxMemoryImageCache + 1)
          .toList();

      for (final key in oldKeys) {
        memoryImageCache.remove(key);
      }
    }

    memoryImageCache[id] = future;

    return future;
  }

  Future<void> refreshScreenshotAndVideoCounts() async {
    try {
      final MediaUtilityCounts counts =
          await MediaManger.getScreenshotAndVideoCounts();
      videosCount.value = counts.videos;
      screenshotsCount.value = counts.screenshots;
    } catch (e) {
      debugPrint('UTILITY COUNT ERROR: $e');
    }
  }

  Future<void> loadUtilityCounts() async {
    try {
      final counts = await MediaManger.getUtilityCounts();

      videosCount.value = counts.videos;
      screenshotsCount.value = counts.screenshots;
      favoritesCount.value = counts.favorites;
      gifsCount.value = counts.gifs;
      livePhotosCount.value = counts.livePhotos;

      debugPrint('================ UTILITY COUNTS ================');
      debugPrint('Videos       : ${counts.videos}');
      debugPrint('Screenshots  : ${counts.screenshots}');
      debugPrint('Favorites    : ${counts.favorites}');
      debugPrint('GIFs         : ${counts.gifs}');
      debugPrint('Live Photos  : ${counts.livePhotos}');
      debugPrint('GIF + Live   : ${counts.gifsAndLivePhotos}');
      debugPrint('================================================');
    } catch (e) {
      debugPrint('UTILITY COUNT ERROR: $e');
    }
  }

  Future<void> preloadMemoryImages(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return;
    }

    const int maxPreload = 4;

    final List<AssetEntity> target = assets.length > maxPreload
        ? assets.sublist(0, maxPreload)
        : assets;

    for (final AssetEntity asset in target) {
      try {
        await loadMemoryImage(asset);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  String memoryLikeId(MemoryGroup memory) {
    if (memory.assets.isNotEmpty) {
      return memory.assets.map((asset) => asset.id).join('_');
    }

    return '${memory.title}_${memory.date.millisecondsSinceEpoch}';
  }

  bool isMemoryLiked(MemoryGroup memory) {
    return likedMemoryIds.contains(memoryLikeId(memory));
  }

  void toggleMemoryLike(MemoryGroup memory) {
    final String id = memoryLikeId(memory);

    if (likedMemoryIds.contains(id)) {
      likedMemoryIds.remove(id);
    } else {
      likedMemoryIds.add(id);
    }

    likedMemoryIds.refresh();
  }

  Future<void> loadForYouMedia() async {
    if (isLoading.value) {
      return;
    }

    try {
      isLoading.value = true;

      errorMessage.value = '';

      currentPage = 0;

      hasMore.value = true;

      debugPrint('========== FOR YOU LOAD START ==========');

      media.clear();
      memories.clear();
      places.clear();

      final List<AssetEntity> result = await MediaManger.getAllMedia(
        page: 0,
        size: pageSize,
      );

      debugPrint('FOR YOU PAGE 0 TOTAL = ${result.length}');

      final List<AssetEntity> firstPage = _onlyImages(result);

      _addUniqueMedia(firstPage);

      await _rebuildGroups();
      await restoreCustomMemories();
      if (result.length < pageSize) {
        hasMore.value = false;
      }

      currentPage = 0;

      debugPrint('FOR YOU INITIAL IMAGES = ${media.length}');

      debugPrint('FOR YOU MEMORY GROUPS = ${memories.length}');

      debugPrint('FOR YOU PLACE GROUPS = ${places.length}');

      if (hasMore.value) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 1500), () {
            if (isClosed) return;
            loadRemainingMedia();
          }),
        );
      }
      await loadUtilityCounts();
    } catch (e, stack) {
      errorMessage.value = e.toString();

      debugPrint('ERROR => $e');

      debugPrint(stack.toString());
    } finally {
      isLoading.value = false;
    }
  }

  List<AssetEntity> _onlyImages(List<AssetEntity> assets) {
    return assets.where((asset) => asset.type == AssetType.image).toList();
  }

  void _addUniqueMedia(List<AssetEntity> assets) {
    if (assets.isEmpty) {
      return;
    }

    final Set<String> existingIds = media.map((asset) => asset.id).toSet();

    final List<AssetEntity> newAssets = [];

    for (final AssetEntity asset in assets) {
      if (!existingIds.contains(asset.id)) {
        existingIds.add(asset.id);

        newAssets.add(asset);
      }
    }

    if (newAssets.isNotEmpty) {
      media.addAll(newAssets);
    }

    // Newest first. Pages arrive already newest-first, so most of the time
    // the list is still in order and the (heavy) full sort is skipped.
    bool inOrder = true;

    for (int i = 1; i < media.length; i++) {
      if ((media[i - 1].createDateSecond ?? 0) <
          (media[i].createDateSecond ?? 0)) {
        inOrder = false;
        break;
      }
    }

    if (!inOrder) {
      media.sort(
        (a, b) => (b.createDateSecond ?? 0).compareTo(a.createDateSecond ?? 0),
      );
    }
  }

  Future<void> loadRemainingMedia() async {
    if (isLoadingMore) {
      return;
    }

    if (!hasMore.value) {
      return;
    }

    isLoadingMore = true;

    try {
      int page = 1;
      bool pendingRebuild = false;
      int pagesSinceRebuild = 0;

      while (hasMore.value) {
        debugPrint('========== FOR YOU LOAD PAGE $page ==========');

        final List<AssetEntity> result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        debugPrint('PAGE $page TOTAL = ${result.length}');

        if (result.isEmpty) {
          hasMore.value = false;
          break;
        }

        final List<AssetEntity> imageAssets = _onlyImages(result);

        final int oldLength = media.length;

        _addUniqueMedia(imageAssets);

        final int addedCount = media.length - oldLength;

        debugPrint('PAGE $page NEW IMAGES = $addedCount');

        if (addedCount > 0) {
          pendingRebuild = true;
          pagesSinceRebuild++;
        }

        // Rebuilding all groups for EVERY page of 100 photos is very heavy.
        // Do it every few pages, and once more at the end.
        if (pendingRebuild && pagesSinceRebuild >= _rebuildEveryPages) {
          await _rebuildGroups();
          await restoreCustomMemories();
          pendingRebuild = false;
          pagesSinceRebuild = 0;
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }

        currentPage = page;

        if (result.length < pageSize) {
          hasMore.value = false;
          break;
        }

        page++;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      if (pendingRebuild) {
        await _rebuildGroups();
        await restoreCustomMemories();
      }
    } catch (e, stack) {
      debugPrint('========== FOR YOU BACKGROUND ERROR ==========');

      debugPrint('ERROR => $e');

      debugPrint(stack.toString());
    } finally {
      isLoadingMore = false;

      debugPrint('FOR YOU FINAL MEDIA = ${media.length}');

      debugPrint('FOR YOU FINAL MEMORIES = ${memories.length}');

      debugPrint('FOR YOU FINAL PLACES = ${places.length}');
    }
  }

  Future<void> _rebuildGroups() async {
    await _loadLocationsForMedia();

    await buildMemories();

    final int preloadCount = memories.length > 6 ? 6 : memories.length;

    for (int i = 0; i < preloadCount; i++) {
      final MemoryGroup memory = memories[i];

      if (memory.assets.isNotEmpty) {
        unawaited(preloadMemoryImages(memory.assets.take(1).toList()));
      }
    }
    await buildPlaces();
    media.refresh();

    memories.refresh();

    places.refresh();
  }

  Future<void> _loadLocationsForMedia() async {
    if (media.isEmpty) {
      return;
    }

    final List<AssetEntity> assetsToLoad = media
        .where((asset) => !_locationCache.containsKey(asset.id))
        .toList();

    if (assetsToLoad.isEmpty) {
      return;
    }

    debugPrint('LOCATION LOAD START = ${assetsToLoad.length}');

    const int batchSize = 20;

    for (int i = 0; i < assetsToLoad.length; i += batchSize) {
      final int end = math.min(i + batchSize, assetsToLoad.length);

      final List<AssetEntity> batch = assetsToLoad.sublist(i, end);

      await Future.wait(
        batch.map((asset) async {
          try {
            final LatLng? location = await asset.latlngAsync();

            _locationCache[asset.id] = location;

            _locationCache[asset.id] = location;
          } catch (e) {
            _locationCache[asset.id] = null;

            debugPrint(
              'LOCATION ERROR => '
                  '${asset.id} | $e',
            );
          }
        }),
      );
    }

    debugPrint('LOCATION LOAD END = ${_locationCache.length}');
  }

  LatLng? _getLocation(AssetEntity asset) {
    return _locationCache[asset.id];
  }

  double? _getLatitude(AssetEntity asset) {
    return _getLocation(asset)?.latitude;
  }

  double? _getLongitude(AssetEntity asset) {
    return _getLocation(asset)?.longitude;
  }

  Future<void> buildMemories() async {
    final List<AssetEntity> sorted = List<AssetEntity>.from(media);

    sorted.sort(
      (a, b) => (a.createDateSecond ?? 0).compareTo(b.createDateSecond ?? 0),
    );

    final List<List<AssetEntity>> groups = [];

    for (final AssetEntity asset in sorted) {
      if (groups.isEmpty) {
        groups.add([asset]);
        continue;
      }

      final List<AssetEntity> currentGroup = groups.last;

      final AssetEntity previous = currentGroup.last;

      final bool closeInTime = _isCloseInTime(previous, asset);

      final bool closeInLocation = _isCloseInLocation(previous, asset);

      bool sameMemory;

      final bool previousHasLocation = _hasLocation(previous);

      final bool currentHasLocation = _hasLocation(asset);

      if (previousHasLocation && currentHasLocation) {
        sameMemory = closeInTime && closeInLocation;
      } else {
        sameMemory = closeInTime;
      }

      if (sameMemory) {
        currentGroup.add(asset);
      } else {
        groups.add([asset]);
      }
    }
    final List<MemoryGroup> result = [];

    for (final List<AssetEntity> group in groups) {
      if (group.isEmpty) {
        continue;
      }
      if (group.length < minimumMemoryPhotos) {
        continue;
      }

      group.sort(
        (a, b) => (b.createDateSecond ?? 0).compareTo(a.createDateSecond ?? 0),
      );

      final AssetEntity cover = group.first;

      final String title = await _createMemoryTitle(group);

      result.add(
        MemoryGroup(
          title: title,
          date: cover.createDateTime,
          assets: group,
          latitude: _averageLatitude(group),
          longitude: _averageLongitude(group),
        ),
      );
    }

    result.sort((a, b) => b.date.compareTo(a.date));

    memories.assignAll(result);

    debugPrint('SMART MEMORY GROUPS = ${memories.length}');

    for (final MemoryGroup memory in memories) {
      debugPrint(
        'MEMORY => ${memory.title} | '
            '${memory.assets.length} photos | '
            '${memory.date}',
      );
    }
  }

  Future<void> saveCustomMemory(MemoryGroup memory) async {
    if (memory.assets.isEmpty) {
      return;
    }

    final List<dynamic> saved =
        GetStorageData.readObject(GetStorageData.customMemories) ?? [];

    final String memoryKey = memory.assets.first.id;

    saved.removeWhere(
          (item) => item is Map && item['key']?.toString() == memoryKey,
    );

    saved.add({
      'key': memoryKey,
      'title': memory.title,
      'date': memory.date.toIso8601String(),
      'assetIds': memory.assets.map((asset) => asset.id).toList(),
      'latitude': memory.latitude,
      'longitude': memory.longitude,
    });

    await GetStorageData.saveObject(GetStorageData.customMemories, saved);

    debugPrint('CUSTOM MEMORY SAVED => ${memory.title}');
  }

  Future<void> restoreCustomMemories() async {
    final List<dynamic> saved =
        GetStorageData.readObject(GetStorageData.customMemories) ?? [];

    if (saved.isEmpty || media.isEmpty) {
      return;
    }

    final Map<String, AssetEntity> assetMap = {
      for (final AssetEntity asset in media) asset.id: asset,
    };

    final List<MemoryGroup> restoredMemories = [];

    for (final dynamic item in saved) {
      if (item is! Map) {
        continue;
      }

      final List<dynamic> savedAssetIds = item['assetIds'] ?? [];

      final List<AssetEntity> memoryAssets = [];

      for (final dynamic id in savedAssetIds) {
        final AssetEntity? asset = assetMap[id.toString()];

        if (asset != null) {
          memoryAssets.add(asset);
        }
      }

      if (memoryAssets.isEmpty) {
        continue;
      }

      final DateTime date =
          DateTime.tryParse(item['date']?.toString() ?? '') ??
              memoryAssets.first.createDateTime;

      restoredMemories.add(
        MemoryGroup(
          title: item['title']?.toString() ?? 'Memory',
          date: date,
          assets: memoryAssets,
          latitude: (item['latitude'] as num?)?.toDouble(),
          longitude: (item['longitude'] as num?)?.toDouble(),
        ),
      );
    }

    if (restoredMemories.isEmpty) {
      return;
    }

    final Set<String> customKeys = restoredMemories
        .map((memory) => memory.assets.isNotEmpty ? memory.assets.first.id : '')
        .toSet();

    memories.removeWhere(
          (memory) =>
      memory.assets.isNotEmpty &&
          customKeys.contains(memory.assets.first.id),
    );

    memories.addAll(restoredMemories);

    memories.sort((a, b) => b.date.compareTo(a.date));

    memories.refresh();

    debugPrint(
      'CUSTOM MEMORIES RESTORED => '
          '${restoredMemories.length}',
    );
  }

  bool _isCloseInTime(AssetEntity first, AssetEntity second) {
    final Duration difference = second.createDateTime
        .difference(first.createDateTime)
        .abs();

    return difference <= memoryTimeGap;
  }

  bool _isCloseInLocation(AssetEntity first, AssetEntity second) {
    final double? lat1 = _getLatitude(first);
    final double? lon1 = _getLongitude(first);

    final double? lat2 = _getLatitude(second);
    final double? lon2 = _getLongitude(second);

    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return true;
    }

    final double distance = _distanceInKm(lat1, lon1, lat2, lon2);

    return distance <= memoryLocationRadiusKm;
  }

  bool _hasLocation(AssetEntity asset) {
    final LatLng? location = _getLocation(asset);

    return location != null;
  }

  double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;

    final double dLat = (lat2 - lat1) * math.pi / 180.0;

    final double dLon = (lon2 - lon1) * math.pi / 180.0;

    final double rLat1 = lat1 * math.pi / 180.0;

    final double rLat2 = lat2 * math.pi / 180.0;

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(rLat1) *
                math.cos(rLat2) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double sin(double value) {
    return _sin(value);
  }

  double cos(double value) {
    return _cos(value);
  }

  double sqrt(double value) {
    return value <= 0 ? 0 : value.pow(0.5);
  }

  double atan2(double y, double x) {
    return _atan2(y, x);
  }

  Future<String> _createMemoryTitle(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return 'Memories';
    }

    final AssetEntity first = assets.first;

    final DateTime date = first.createDateTime;

    final double? latitude = _averageLatitude(assets);

    final double? longitude = _averageLongitude(assets);

    if (latitude != null && longitude != null) {
      final String? locationName = await _getLocationName(latitude, longitude);

      if (locationName != null && locationName.trim().isNotEmpty) {
        return 'A Trip near $locationName';
      }
      return 'A Trip';
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return 'Memories from '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  Future<String?> _getLocationName(double latitude, double longitude) async {
    try {
      // ~1 km cache key
      final String cacheKey =
          '${latitude.toStringAsFixed(2)},'
          '${longitude.toStringAsFixed(2)}';

      if (_locationNameCache.containsKey(cacheKey)) {
        return _locationNameCache[cacheKey];
      }

      // 100% on-device lookup. No network, nothing leaves the phone.
      final String? name = await OfflineGeocoder.instance.nearestPlaceName(
        latitude,
        longitude,
      );

      if (name != null && name.trim().isNotEmpty) {
        _locationNameCache[cacheKey] = name.trim();

        return name.trim();
      }

      return null;
    } catch (e) {
      debugPrint('LOCATION NAME ERROR => $latitude, $longitude | $e');

      return null;
    }
  }

  double? _averageLatitude(List<AssetEntity> assets) {
    final List<double> values = assets
        .map(_getLatitude)
        .whereType<double>()
        .toList();

    if (values.isEmpty) {
      return null;
    }

    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _averageLongitude(List<AssetEntity> assets) {
    final List<double> values = assets
        .map(_getLongitude)
        .whereType<double>()
        .toList();

    if (values.isEmpty) {
      return null;
    }

    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> buildPlaces() async {
    if (media.isEmpty) {
      places.clear();
      places.refresh();
      return;
    }

    const double placeRadiusKm = 2.0;

    // Old logic: the FIRST photo became a fixed anchor and everything within
    // 2 km of that one point joined it (result depended on photo order, and a
    // trip with photos spread out got cut in the wrong places).
    // New logic: photo joins the NEAREST group (not just the first one), and
    // the group centre moves as photos are added.
    final List<AssetEntity> sortedMedia = List<AssetEntity>.from(media)
      ..sort(
        (a, b) => (b.createDateSecond ?? 0).compareTo(a.createDateSecond ?? 0),
      );

    final List<List<AssetEntity>> buckets = <List<AssetEntity>>[];
    final List<double> latSum = <double>[];
    final List<double> lonSum = <double>[];

    for (final AssetEntity asset in sortedMedia) {
      final LatLng? location = _getLocation(asset);

      if (location == null) {
        continue;
      }

      int bestIndex = -1;
      double bestDistance = double.infinity;

      for (int i = 0; i < buckets.length; i++) {
        final int count = buckets[i].length;

        // A group more than ~0.1 degree (11 km) away in latitude can never
        // be within 2 km. Skip it without the expensive distance maths.
        if ((latSum[i] / count - location.latitude).abs() > 0.1) {
          continue;
        }

        final double distance = _distanceInKm(
          latSum[i] / count,
          lonSum[i] / count,
          location.latitude,
          location.longitude,
        );

        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }

      if (bestIndex != -1 && bestDistance <= placeRadiusKm) {
        buckets[bestIndex].add(asset);
        latSum[bestIndex] += location.latitude;
        lonSum[bestIndex] += location.longitude;

        continue;
      }

      buckets.add(<AssetEntity>[asset]);
      latSum.add(location.latitude);
      lonSum.add(location.longitude);
    }

    final List<PlaceGroup> result = <PlaceGroup>[];

    for (int i = 0; i < buckets.length; i++) {
      result.add(
        PlaceGroup(
          latitude: latSum[i] / buckets[i].length,
          longitude: lonSum[i] / buckets[i].length,
          assets: buckets[i],
          title: 'Unknown place',
        ),
      );
    }

    result.removeWhere((place) => place.assets.isEmpty);

    for (final PlaceGroup place in result) {
      place.assets.sort(
        (a, b) => (b.createDateSecond ?? 0).compareTo(a.createDateSecond ?? 0),
      );
    }

    result.sort((a, b) => b.assets.length.compareTo(a.assets.length));

    for (final PlaceGroup place in result) {
      try {
        final String? locationName = await _getLocationName(
          place.latitude,
          place.longitude,
        );

        if (locationName != null && locationName.trim().isNotEmpty) {
          place.title = locationName.trim();
        } else {
          place.title = 'Unknown place';
        }
      } catch (e) {
        debugPrint('PLACE TITLE ERROR => $e');

        place.title = 'Unknown place';
      }
    }

    places.assignAll(result);

    places.refresh();

    debugPrint('PLACE GROUPS = ${places.length}');

    for (final PlaceGroup place in places) {
      debugPrint(
        'PLACE => ${place.title} | '
            '${place.assets.length} photos | '
            '${place.latitude}, ${place.longitude}',
      );
    }
  }

  Future<void> refreshForYou() async {
    if (isRefreshing.value) {
      return;
    }

    try {
      isRefreshing.value = true;

      debugPrint('========== FOR YOU REFRESH START ==========');

      media.clear();
      memories.clear();
      places.clear();

      currentPage = 0;

      hasMore.value = true;

      await loadForYouMedia();
    } catch (e, stack) {
      debugPrint('FOR YOU REFRESH ERROR => $e');

      debugPrint(stack.toString());
    } finally {
      isRefreshing.value = false;

      debugPrint('========== FOR YOU REFRESH END ==========');
    }
  }

  Future<void> openCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) {
        return;
      }

      final Uint8List bytes = await image.readAsBytes();

      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();

      if (!permission.isAuth) {
        debugPrint('Camera save permission denied');
        return;
      }

      final String fileName =
          'Camera_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final AssetEntity? savedAsset = await PhotoManager.editor.saveImage(
        bytes,
        filename: fileName,
        title: fileName,
      );

      if (savedAsset != null) {
        _addUniqueMedia([savedAsset]);

        await _rebuildGroups();

        debugPrint(
          'CAMERA IMAGE ADDED = '
          '${savedAsset.id}',
        );
      }
    } catch (e, stack) {
      debugPrint('========== FOR YOU CAMERA ERROR ==========');

      debugPrint('ERROR => $e');

      debugPrint(stack.toString());
    }
  }

  Future<void> addCustomMemory({
    required String title,
    required List<AssetEntity> assets,
  }) async {
    if (assets.isEmpty) return;

    final String memoryId = DateTime.now().millisecondsSinceEpoch.toString();

    final List<dynamic> savedMemories = List<dynamic>.from(
      GetStorageData.readObject('customMemories') ?? [],
    );

    savedMemories.add({
      'id': memoryId,
      'title': title,
      'date': DateTime.now().toIso8601String(),
      'assetIds': assets.map((asset) => asset.id).toList(),
    });

    GetStorageData.saveString('customMemories', savedMemories);

    memories.insert(
      0,
      MemoryGroup(
        title: title,
        date: DateTime.now(),
        assets: assets,
        latitude: null,
        longitude: null,
      ),
    );

    memories.refresh();
  }

  void clearForYouData() {
    media.clear();

    memories.clear();

    places.clear();
    _locationCache.clear();
    _locationNameCache.clear();
    currentPage = 0;

    hasMore.value = true;

    errorMessage.value = '';
  }

  @override
  void onClose() {
    media.clear();

    memories.clear();

    places.clear();
    _locationCache.clear();
    _locationNameCache.clear();

    super.onClose();
  }
}

class MemoryGroup {
  String title;

  final DateTime date;

  final List<AssetEntity> assets;

  final double? latitude;

  final double? longitude;

  MemoryGroup({
    required this.title,
    required this.date,
    required this.assets,
    this.latitude,
    this.longitude,
  });
}

class PlaceGroup {
  final double latitude;
  final double longitude;
  final List<AssetEntity> assets;
  String title;

  PlaceGroup({
    required this.latitude,
    required this.longitude,
    required this.assets,
    required this.title,
  });
}

Set<String> getDeletedMemoryIds() {
  final List<dynamic> deleted =
      GetStorageData.readObject(GetStorageData.deletedMemories) ?? [];

  return deleted.map((e) => e.toString()).toSet();
}

double _sin(double x) {
  double term = x;
  double sum = x;

  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));

    sum += term;
  }

  return sum;
}

double _cos(double x) {
  double term = 1;
  double sum = 1;

  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i - 1) * (2 * i));

    sum += term;
  }

  return sum;
}

double _atan2(double y, double x) {
  if (x > 0) {
    return _atan(y / x);
  }

  if (x < 0 && y >= 0) {
    return _atan(y / x) + 3.141592653589793;
  }

  if (x < 0 && y < 0) {
    return _atan(y / x) - 3.141592653589793;
  }

  if (x == 0 && y > 0) {
    return 3.141592653589793 / 2;
  }

  if (x == 0 && y < 0) {
    return -3.141592653589793 / 2;
  }

  return 0;
}

double _atan(double x) {
  if (x.abs() <= 1) {
    double result = 0;

    double power = x;

    for (int i = 0; i < 15; i++) {
      final int n = 2 * i + 1;

      result += ((i % 2 == 0) ? 1 : -1) * power / n;

      power *= x * x;
    }

    return result;
  }

  if (x > 0) {
    return 3.141592653589793 / 2 - _atan(1 / x);
  }

  return -3.141592653589793 / 2 - _atan(1 / x);
}

extension _DoublePow on double {
  double pow(double exponent) {
    return _exp(exponent * _ln(this));
  }
}

double _ln(double x) {
  if (x <= 0) {
    return 0;
  }

  double y = 0;

  final double z = (x - 1) / (x + 1);

  double power = z;

  for (int i = 1; i <= 30; i += 2) {
    y += power / i;
    power *= z * z;
  }

  return 2 * y;
}

double _exp(double x) {
  double sum = 1;

  double term = 1;

  for (int i = 1; i <= 30; i++) {
    term *= x / i;

    sum += term;
  }

  return sum;
}
