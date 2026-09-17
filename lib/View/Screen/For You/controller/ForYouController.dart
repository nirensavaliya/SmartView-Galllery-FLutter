import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/Common/MediaManager.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class ForYouController extends GetxController {
  final RxList<AssetEntity> media = <AssetEntity>[].obs;

  final RxList<MemoryGroup> memories = <MemoryGroup>[].obs;

  final RxList<PlaceGroup> places = <PlaceGroup>[].obs;

  final Map<String, Future<Uint8List?>> memoryImageCache = {};
  final RxBool isLoading = false.obs;

  final RxBool isRefreshing = false.obs;

  final RxBool hasMore = true.obs;

  final RxString errorMessage = ''.obs;

  final ImagePicker _picker = ImagePicker();
  final Geocoding _geocoding = Geocoding();

  static const int pageSize = 100;

  int currentPage = 0;

  bool isLoadingMore = false;
  final Map<String, LatLng?> _locationCache = {};
  final Map<String, String> _locationNameCache = {};
  static const Duration memoryTimeGap = Duration(hours: 6);
  static const double memoryLocationRadiusKm = 2.0;
  static const int minimumMemoryPhotos = 2;

  @override
  void onInit() {
    super.onInit();

    loadForYouMedia();
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

    memoryImageCache[id] = future;

    return future;
  }

  Future<void> preloadMemoryImages(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return;
    }

    // Saari images ki Future ek baar create hogi.
    for (final AssetEntity asset in assets) {
      loadMemoryImage(asset);
    }

    // Background me preload complete kar do.
    await Future.wait(assets.map((asset) => loadMemoryImage(asset)));
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
      // await _requestMediaLocationPermission();

      // ========================================================
      // FIRST PAGE
      // ========================================================

      final List<AssetEntity> result = await MediaManger.getAllMedia(
        page: 0,
        size: pageSize,
      );

      debugPrint('FOR YOU PAGE 0 TOTAL = ${result.length}');

      final List<AssetEntity> firstPage = _onlyImages(result);

      _addUniqueMedia(firstPage);

      // ========================================================
      // BUILD SMART MEMORIES
      // ========================================================

      await _rebuildGroups();

      if (result.length < pageSize) {
        hasMore.value = false;
      }

      currentPage = 0;

      debugPrint('FOR YOU INITIAL IMAGES = ${media.length}');

      debugPrint('FOR YOU MEMORY GROUPS = ${memories.length}');

      debugPrint('FOR YOU PLACE GROUPS = ${places.length}');

      // ========================================================
      // LOAD REST IN BACKGROUND
      // ========================================================

      if (hasMore.value) {
        unawaited(loadRemainingMedia());
      }
    } catch (e, stack) {
      errorMessage.value = e.toString();

      debugPrint('========== FOR YOU LOAD ERROR ==========');

      debugPrint('ERROR => $e');

      debugPrint(stack.toString());
    } finally {
      isLoading.value = false;

      debugPrint('========== FOR YOU LOAD END ==========');
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

    // Newest first.
    media.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
  }

  // ============================================================
  // LOAD REMAINING PAGES
  // ============================================================

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

        // ======================================================
        // REBUILD SMART MEMORIES
        // ======================================================

        if (addedCount > 0) {
          await _rebuildGroups();
        }

        currentPage = page;

        if (result.length < pageSize) {
          hasMore.value = false;
          break;
        }

        page++;
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

  // ============================================================
  // REBUILD EVERYTHING
  // ============================================================

  Future<void> _rebuildGroups() async {
    await _loadLocationsForMedia();

    await buildMemories();
    for (final MemoryGroup memory in memories) {
      if (memory.assets.isNotEmpty) {
        unawaited(preloadMemoryImages(memory.assets));
      }
    }
    buildPlaces();

    media.refresh();

    memories.refresh();

    places.refresh();
  }
  // ============================================================
  // LOAD LOCATIONS
  // ============================================================

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

    // Small batches me location fetch karo.
    // Isse ek saath bahut saare platform requests nahi jayenge.
    const int batchSize = 20;

    for (int i = 0; i < assetsToLoad.length; i += batchSize) {
      final int end = math.min(i + batchSize, assetsToLoad.length);

      final List<AssetEntity> batch = assetsToLoad.sublist(i, end);

      await Future.wait(
        batch.map((asset) async {
          try {
            final LatLng? location = await asset.latlngAsync();

            _locationCache[asset.id] = location;

            if (location != null) {
              debugPrint(
                'LOCATION FOUND => '
                '${asset.id} | '
                '${location.latitude}, '
                '${location.longitude}',
              );
            } else {
              debugPrint('LOCATION NOT FOUND => ${asset.id}');
            }
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

  // ============================================================
  // GET ASSET LOCATION
  // ============================================================

  LatLng? _getLocation(AssetEntity asset) {
    return _locationCache[asset.id];
  }

  // ============================================================
  // GET LATITUDE
  // ============================================================

  double? _getLatitude(AssetEntity asset) {
    return _getLocation(asset)?.latitude;
  }

  // ============================================================
  // GET LONGITUDE
  // ============================================================

  double? _getLongitude(AssetEntity asset) {
    return _getLocation(asset)?.longitude;
  }
  // ============================================================
  // SMART MEMORY CREATION
  // ============================================================

  Future<void> buildMemories() async {
    final List<AssetEntity> sorted = List<AssetEntity>.from(media);

    // Oldest → newest for grouping.
    sorted.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));

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

      // ========================================================
      // MEMORY RULE
      //
      // Same activity when:
      //
      // 1. Time is close
      // AND
      // 2. Location is close
      //
      // If GPS is missing, time alone is used.
      // ========================================================

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

      // Newest photo first.
      group.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

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

    // Newest memories first.
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

  // ============================================================
  // TIME CHECK
  // ============================================================

  bool _isCloseInTime(AssetEntity first, AssetEntity second) {
    final Duration difference = second.createDateTime
        .difference(first.createDateTime)
        .abs();

    return difference <= memoryTimeGap;
  }

  // ============================================================
  // LOCATION CHECK
  // ============================================================
  // ============================================================
  // LOCATION CHECK
  // ============================================================

  bool _isCloseInLocation(AssetEntity first, AssetEntity second) {
    final double? lat1 = _getLatitude(first);
    final double? lon1 = _getLongitude(first);

    final double? lat2 = _getLatitude(second);
    final double? lon2 = _getLongitude(second);

    // Agar kisi photo ki location available nahi hai,
    // to existing behaviour ke according time ke basis
    // par grouping allow karo.
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return true;
    }

    final double distance = _distanceInKm(lat1, lon1, lat2, lon2);

    return distance <= memoryLocationRadiusKm;
  }

  // ============================================================
  // HAS LOCATION
  // ============================================================

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

  // double _degreesToRadians(double degrees) {
  //   return degrees * 3.141592653589793 / 180.0;
  // }

  double sin(double value) {
    // Small local implementation so no
    // extra package is required.
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

  // ============================================================
  // MEMORY TITLE
  // ============================================================

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

      // Agar location name fetch nahi ho paya
      // to coordinates mat dikhana.
      return 'A Trip';
    }

    // ==========================================================
    // NO LOCATION
    // ==========================================================

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

  // ============================================================
  // GET LOCATION NAME FROM GPS
  // ============================================================

  Future<String?> _getLocationName(double latitude, double longitude) async {
    try {
      final String cacheKey =
          '${latitude.toStringAsFixed(3)},'
          '${longitude.toStringAsFixed(3)}';

      if (_locationNameCache.containsKey(cacheKey)) {
        return _locationNameCache[cacheKey];
      }

      final List<Placemark> placemarks = await _geocoding
          .placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        return null;
      }

      final Placemark place = placemarks.first;

      String? name;

      if (place.locality != null && place.locality!.trim().isNotEmpty) {
        name = place.locality!.trim();
      } else if (place.subLocality != null &&
          place.subLocality!.trim().isNotEmpty) {
        name = place.subLocality!.trim();
      } else if (place.subAdministrativeArea != null &&
          place.subAdministrativeArea!.trim().isNotEmpty) {
        name = place.subAdministrativeArea!.trim();
      } else if (place.administrativeArea != null &&
          place.administrativeArea!.trim().isNotEmpty) {
        name = place.administrativeArea!.trim();
      }

      if (name == null || name.isEmpty) {
        return null;
      }

      _locationNameCache[cacheKey] = name;

      return name;
    } catch (e) {
      debugPrint(
        'LOCATION NAME ERROR => '
        '$latitude, $longitude | $e',
      );

      return null;
    }
  }
  // ============================================================
  // AVERAGE LATITUDE
  // ============================================================

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
  // ============================================================
  // AVERAGE LONGITUDE
  // ============================================================

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

  // ============================================================
  // PLACES
  // ============================================================

  void buildPlaces() {
    final Map<String, List<AssetEntity>> grouped = {};

    for (final AssetEntity asset in media) {
      final double? latitude = _getLatitude(asset);
      final double? longitude = _getLongitude(asset);

      if (latitude == null || longitude == null) {
        continue;
      }

      final String lat = latitude.toStringAsFixed(3);
      final String lng = longitude.toStringAsFixed(3);

      final String key = '$lat,$lng';

      grouped.putIfAbsent(key, () => <AssetEntity>[]).add(asset);
    }

    final List<PlaceGroup> result = [];

    for (final entry in grouped.entries) {
      final List<String> parts = entry.key.split(',');

      if (parts.length != 2) {
        continue;
      }

      final double? latitude = double.tryParse(parts[0]);

      final double? longitude = double.tryParse(parts[1]);

      if (latitude == null || longitude == null) {
        continue;
      }

      final List<AssetEntity> items = List<AssetEntity>.from(entry.value);

      items.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

      if (items.isEmpty) {
        continue;
      }

      result.add(
        PlaceGroup(latitude: latitude, longitude: longitude, assets: items),
      );
    }

    result.sort((a, b) => b.assets.length.compareTo(a.assets.length));

    places.assignAll(result);

    debugPrint('PLACE GROUPS = ${places.length}');
  }

  // ============================================================
  // REFRESH
  // ============================================================

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

  // ============================================================
  // CAMERA
  // ============================================================

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

    final String memoryId =
    DateTime.now().millisecondsSinceEpoch.toString();

    final List<dynamic> savedMemories =
    List<dynamic>.from(
      GetStorageData.readObject('customMemories') ?? [],
    );

    savedMemories.add({
      'id': memoryId,
      'title': title,
      'date': DateTime.now().toIso8601String(),
      'assetIds': assets.map((asset) => asset.id).toList(),
    });

    GetStorageData.saveString(
      'customMemories',
      savedMemories,
    );

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
  // ============================================================
  // CLEAR
  // ============================================================

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

  // ============================================================
  // CLOSE
  // ============================================================

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

// =================================================================
// MEMORY MODEL
// =================================================================

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

// =================================================================
// PLACE MODEL
// =================================================================

class PlaceGroup {
  final double latitude;

  final double longitude;

  final List<AssetEntity> assets;

  PlaceGroup({
    required this.latitude,
    required this.longitude,
    required this.assets,
  });
}

Set<String> getDeletedMemoryIds() {
  final List<dynamic> deleted =
      GetStorageData.readObject(GetStorageData.deletedMemories) ?? [];

  return deleted.map((e) => e.toString()).toSet();
}
// =================================================================
// MATH HELPERS
// =================================================================

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
