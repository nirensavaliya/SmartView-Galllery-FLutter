import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/MediaActionService.dart';
import 'package:gallery_photos/Common/MediaManager.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotoViewController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:gallery_photos/View/Setting/FileOperationService.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class _AlbumCardData {
  const _AlbumCardData({
    required this.album,
    required this.count,
    required this.keep,
    this.cover,
  });

  final AssetPathEntity album;
  final int count;
  final AssetEntity? cover;
  final bool keep;
}

class AlbumsController extends GetxController {
  final RxList<AssetPathEntity> albums = <AssetPathEntity>[].obs;
  final RxMap<String, AssetEntity> albumCovers = <String, AssetEntity>{}.obs;
  final RxMap<String, int> albumCounts = <String, int>{}.obs;
  final RxBool isLoading = true.obs;
  final RxInt albumCrossAxisCount = 2.obs;
  int _startAlbumCrossAxisCount = 2;

  final RxList<AssetEntity> createAlbumMedia = <AssetEntity>[].obs;
  final RxSet<String> selectedAlbumMediaIds = <String>{}.obs;
  final RxBool isCreateAlbumLoading = false.obs;
  final RxMap<String, dynamic> customAlbums = <String, dynamic>{}.obs;
  final RxSet<String> selectedAlbumIds = <String>{}.obs;
  final RxBool isAlbumSelectionMode = false.obs;
  final RxBool filterImages = true.obs;
  final RxBool filterVideos = true.obs;
  final RxBool filterGifs = true.obs;
  final RxBool filterRawImages = true.obs;
  final RxBool filterSvgs = true.obs;
  final RxBool filterPortraits = false.obs;
  final RxString albumSortBy = "Album Name".obs;
  final RxBool albumSortAscending = true.obs;
  final RxBool isAlbumListView = false.obs;

  final RxMap<String, bool> albumFilterVisibility = <String, bool>{}.obs;

  Future<void>? _ongoingAlbumsLoad;

  @override
  void onInit() {
    super.onInit();
    loadAlbums();
    loadSavedAlbumGrid();
    _watchGalleryChanges();
  }

  bool _galleryNotifyStarted = false;
  bool _applyingGalleryChange = false;
  Timer? _galleryChangeTimer;
  DateTime? _ignoreGalleryChangesUntil;

  void _watchGalleryChanges() {
    if (_galleryNotifyStarted) return;
    _galleryNotifyStarted = true;
    _ignoreGalleryChangesUntil = DateTime.now().add(const Duration(seconds: 2));
    PhotoManager.addChangeCallback(_onGalleryChanged);
    PhotoManager.startChangeNotify();
  }

  void _onGalleryChanged(MethodCall _) {
    final DateTime? ignoreUntil = _ignoreGalleryChangesUntil;
    if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) {
      return;
    }
    if (_applyingGalleryChange) return;
    _galleryChangeTimer?.cancel();
    _galleryChangeTimer = Timer(const Duration(milliseconds: 700), () async {
      if (_applyingGalleryChange) return;
      _applyingGalleryChange = true;
      try {
        if (Get.isRegistered<PhotosController>()) {
          await Get.find<PhotosController>().showNewPhotosNow();
        } else {
          await refreshAfterNewPhotos();
        }
      } finally {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        _applyingGalleryChange = false;
      }
    });
  }

  @override
  void onClose() {
    _galleryChangeTimer?.cancel();
    if (_galleryNotifyStarted) {
      PhotoManager.removeChangeCallback(_onGalleryChanged);
    }
    super.onClose();
  }

  final RxBool isAlbumDragSelecting = false.obs;

  final Set<String> _albumDragVisitedIds = <String>{};

  String? _lastAlbumDragId;
  final ScrollController albumScrollController = ScrollController();

  Timer? _albumAutoScrollTimer;

  void updateAlbumAutoScroll({
    required double localY,
    required double viewportHeight,
  }) {
    if (!isAlbumDragSelecting.value) {
      stopAlbumAutoScroll();
      return;
    }

    const double edgeSize = 90;

    if (localY < edgeSize) {
      _startAlbumAutoScroll(-1);
    } else if (localY > viewportHeight - edgeSize) {
      _startAlbumAutoScroll(1);
    } else {
      stopAlbumAutoScroll();
    }
  }

  void _startAlbumAutoScroll(int direction) {
    if (_albumAutoScrollTimer != null &&
        _albumAutoScrollTimer!.isActive) {
      return;
    }

    _albumAutoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 35),
          (_) {
        if (!isAlbumDragSelecting.value) {
          stopAlbumAutoScroll();
          return;
        }

        if (!albumScrollController.hasClients) {
          return;
        }

        const double amount = 14;

        double newOffset =
            albumScrollController.offset + (amount * direction);

        newOffset = newOffset.clamp(
          albumScrollController.position.minScrollExtent,
          albumScrollController.position.maxScrollExtent,
        );

        albumScrollController.jumpTo(newOffset);
      },
    );
  }

  void stopAlbumAutoScroll() {
    _albumAutoScrollTimer?.cancel();
    _albumAutoScrollTimer = null;
  }
  void startAlbumDragSelection(String albumId) {
    isAlbumDragSelecting.value = true;

    _albumDragVisitedIds.clear();

    _lastAlbumDragId = albumId;

    _albumDragVisitedIds.add(albumId);

    if (!selectedAlbumIds.contains(albumId)) {
      selectedAlbumIds.add(albumId);
      selectedAlbumIds.refresh();
    }

    isAlbumSelectionMode.value = true;
  }

  void selectAlbumDuringDrag(String albumId) {
    if (!isAlbumDragSelecting.value) {
      return;
    }

    if (_lastAlbumDragId == albumId) {
      return;
    }

    _lastAlbumDragId = albumId;

    if (_albumDragVisitedIds.contains(albumId)) {
      return;
    }

    _albumDragVisitedIds.add(albumId);

    if (!selectedAlbumIds.contains(albumId)) {
      selectedAlbumIds.add(albumId);
      selectedAlbumIds.refresh();
    }

    isAlbumSelectionMode.value = true;
  }

  void endAlbumDragSelection() {
    isAlbumDragSelecting.value = false;

    _lastAlbumDragId = null;

    _albumDragVisitedIds.clear();
  }

  bool _isRawImage(String title, String mime) {
    const rawExtensions = [
      ".raw",
      ".dng",
      ".cr2",
      ".cr3",
      ".nef",
      ".nrw",
      ".arw",
      ".srf",
      ".sr2",
      ".raf",
      ".rw2",
      ".orf",
      ".pef",
      ".3fr",
    ];

    return rawExtensions.any(title.endsWith) ||
        mime.contains("raw") ||
        mime.contains("dng");
  }

  bool _isPortrait(AssetEntity asset) {
    final width = asset.width;
    final height = asset.height;

    return height > width;
  }

  bool assetMatchesFilter(AssetEntity asset) {
    final title = (asset.title ?? "").toLowerCase();
    final mime = (asset.mimeType ?? "").toLowerCase();
    if (asset.type == AssetType.video) {
      return filterVideos.value;
    }
    if (asset.type == AssetType.image) {
      if (title.endsWith(".gif") || mime == "image/gif") {
        return filterGifs.value;
      }
      if (_isRawImage(title, mime)) {
        return filterRawImages.value;
      }
      if (title.endsWith(".svg") || mime == "image/svg+xml") {
        return filterSvgs.value;
      }
      if (_isPortrait(asset)) {
        return filterPortraits.value;
      }
      return filterImages.value;
    }

    return false;
  }

  Future<void> refreshAlbums() async {
    try {
      final List<AssetPathEntity> result = await MediaManger.getAlbums();

      final existingIds = albums.map((album) => album.id).toSet();

      final newAlbums = result
          .where((album) => !existingIds.contains(album.id))
          .toList();

      if (newAlbums.isNotEmpty) {
        albums.addAll(newAlbums);

        for (final album in newAlbums) {
          try {
            final int count = await album.assetCountAsync;

            if (count == 0) {
              continue;
            }

            final List<AssetEntity> assets = await album.getAssetListRange(
              start: 0,
              end: 1,
            );

            if (assets.isNotEmpty) {
              albumCovers[album.id] = assets.first;
            }
          } catch (e) {
            debugPrint("Refresh Cover Error ${album.name}: $e");
          }
        }

        albums.refresh();
        albumCovers.refresh();
      }

      await loadCustomAlbums();

      debugPrint("NEW ALBUMS ADDED => ${newAlbums.length}");
    } catch (e) {
      debugPrint("Refresh Albums Error => $e");
    }
  }

  Future<bool> albumMatchesFilter(AssetPathEntity album) async {
    try {
      final count = await album.assetCountAsync;
      if (count == 0) {
        return false;
      }
      final assets = await album.getAssetListRange(start: 0, end: count);

      return assets.any(assetMatchesFilter);
    } catch (e) {
      debugPrint("Album Filter Error ${album.name}: $e");
      return false;
    }
  }

  Future<void> applyAlbumFilter() async {
    albumFilterVisibility.clear();

    for (final album in albums) {
      final visible = await albumMatchesFilter(album);

      albumFilterVisibility[album.id] = visible;
    }

    albumFilterVisibility.refresh();
  }

  void loadSavedAlbumGrid() {
    final savedColumns = GetStorageData.readString(
      GetStorageData.albumsGridColumns,
    );
    if (savedColumns != null) {
      final int? columns = int.tryParse(savedColumns.toString());
      if (columns != null) {
        albumCrossAxisCount.value = columns.clamp(2, 6);
        _startAlbumCrossAxisCount = albumCrossAxisCount.value;
      }
    }
  }

  Future<void>? _refreshingAfterCamera;

  Future<void> refreshAfterNewPhotos() {
    return _refreshingAfterCamera ??= _refreshAfterNewPhotos().whenComplete(() {
      _refreshingAfterCamera = null;
    });
  }

  Future<void> _refreshAfterNewPhotos() async {
    try {
      try {
        await PhotoManager.clearFileCache();
      } catch (_) {}

      final List<AssetPathEntity> freshAlbums = await MediaManger.getAlbums();
      if (freshAlbums.isEmpty) return;

      final Map<String, AssetPathEntity> byId = {
        for (final AssetPathEntity album in freshAlbums) album.id: album,
      };
      final List<AssetPathEntity> updated = <AssetPathEntity>[];
      for (final AssetPathEntity album in albums) {
        updated.add(byId[album.id] ?? album);
      }
      final Set<String> knownIds = albums.map((album) => album.id).toSet();
      for (final AssetPathEntity album in freshAlbums) {
        if (!knownIds.contains(album.id)) {
          updated.add(album);
        }
      }

      final bool deleteEmptyFolders = GetStorageData.readBoolean(
        GetStorageData.deleteEmptyFolders,
        defaultValue: true,
      );
      await _publishAlbums(updated, dropEmpty: deleteEmptyFolders);

      for (final AssetPathEntity album in albums) {
        if (Get.isRegistered<AlbumPhotosController>(tag: album.id)) {
          await Get.find<AlbumPhotosController>(tag: album.id).reloadFrom(album);
        }
      }
    } catch (e) {
      debugPrint('ALBUM REFRESH AFTER CAMERA: $e');
    }
  }

  Future<void> loadAlbums() {
    return _ongoingAlbumsLoad ??= _loadAlbumsBody().whenComplete(() {
      _ongoingAlbumsLoad = null;
    });
  }

  Future<void> _loadAlbumsBody() async {
    final bool showLoadingState = albums.isEmpty;

    if (showLoadingState) {
      isLoading.value = true;
    }

    try {
      final List<AssetPathEntity> result = await MediaManger.getAlbums();
      final bool deleteEmptyFolders = GetStorageData.readBoolean(
        GetStorageData.deleteEmptyFolders,
        defaultValue: true,
      );

      final List<AssetPathEntity> source;
      if (deleteEmptyFolders || albums.isEmpty) {
        source = result;
      } else {
        final Set<String> existingIds = albums.map((album) => album.id).toSet();
        source = <AssetPathEntity>[
          ...albums,
          ...result.where((album) => !existingIds.contains(album.id)),
        ];
      }

      await _publishAlbums(source, dropEmpty: deleteEmptyFolders);
    } catch (e) {
      debugPrint("Album Error: $e");
    } finally {
      if (showLoadingState) {
        await loadCustomAlbums();
        isLoading.value = false;
      }
    }
  }

  Future<void> _publishAlbums(
    List<AssetPathEntity> source, {
    required bool dropEmpty,
  }) async {
    final List<_AlbumCardData> rows = await _mapAlbumBatches(source, (
      AssetPathEntity album,
    ) async {
      try {
        final int count = await album.assetCountAsync;
        if (count <= 0) {
          return _AlbumCardData(album: album, count: 0, keep: !dropEmpty);
        }
        final List<AssetEntity> assets = await album.getAssetListRange(
          start: 0,
          end: 1,
        );
        return _AlbumCardData(
          album: album,
          count: count,
          cover: assets.isEmpty ? null : assets.first,
          keep: true,
        );
      } catch (e) {
        debugPrint("Cover Error ${album.name}: $e");
        return _AlbumCardData(album: album, count: 0, keep: true);
      }
    });

    final List<AssetPathEntity> next = <AssetPathEntity>[];
    final Map<String, AssetEntity> covers = <String, AssetEntity>{};
    final Map<String, int> counts = <String, int>{};
    for (final _AlbumCardData row in rows) {
      if (!row.keep) continue;
      next.add(row.album);
      counts[row.album.id] = row.count;
      final AssetEntity? cover = row.cover;
      if (cover != null) {
        covers[row.album.id] = cover;
      }
    }

    albums.assignAll(next);
    albumCovers.assignAll(covers);
    albumCounts.assignAll(counts);
  }

  Future<List<R>> _mapAlbumBatches<R>(
    List<AssetPathEntity> items,
    Future<R> Function(AssetPathEntity album) action,
  ) async {
    const int batchSize = 4;
    final List<R> out = <R>[];
    for (var start = 0; start < items.length; start += batchSize) {
      final int end = start + batchSize > items.length
          ? items.length
          : start + batchSize;
      out.addAll(await Future.wait(items.sublist(start, end).map(action)));
    }
    return out;
  }

  void onAlbumScaleStart() {
    _startAlbumCrossAxisCount = albumCrossAxisCount.value;
  }

  Future<void> refreshAlbumCover(AssetPathEntity album) async {
    try {
      final deleteEmptyFolders = GetStorageData.readBoolean(
        GetStorageData.deleteEmptyFolders,
        defaultValue: true,
      );

      final freshAlbums = await MediaManger.getAlbums();

      AssetPathEntity? freshAlbum;

      for (final item in freshAlbums) {
        if (item.id == album.id) {
          freshAlbum = item;
          break;
        }
      }

if (freshAlbum == null) {
        if (deleteEmptyFolders) {

          albums.removeWhere((item) => item.id == album.id);

          albumCovers.remove(album.id);
        } else {

          albumCovers.remove(album.id);

          final index = albums.indexWhere((item) => item.id == album.id);

          if (index != -1) {
            albums[index] = album;
          }
        }

        albums.refresh();
        albumCovers.refresh();

        return;
      }

final count = await freshAlbum.assetCountAsync;

if (count <= 0) {
        if (deleteEmptyFolders) {

          albums.removeWhere((item) => item.id == album.id);

          albumCovers.remove(album.id);

          debugPrint("EMPTY ALBUM REMOVED => ${album.name}");
        } else {

          final index = albums.indexWhere((item) => item.id == album.id);

          if (index != -1) {
            albums[index] = freshAlbum;
          }

          albumCovers.remove(album.id);

          debugPrint("EMPTY ALBUM KEPT => ${album.name}");
        }

        albums.refresh();
        albumCovers.refresh();

        return;
      }

final index = albums.indexWhere((item) => item.id == album.id);

      if (index != -1) {
        albums[index] = freshAlbum;
      }

      final assets = await freshAlbum.getAssetListRange(start: 0, end: 1);

      if (assets.isNotEmpty) {
        albumCovers[album.id] = assets.first;

        debugPrint("NEW ALBUM COVER => ${album.name} : ${assets.first.id}");
      } else {
        albumCovers.remove(album.id);
      }

      albums.refresh();
      albumCovers.refresh();
    } catch (e) {
      debugPrint("Refresh Album Cover Error ${album.name}: $e");
    }
  }

  Future<void> refreshCustomAlbums() async {
    try {
      final savedData = GetStorageData.readString(GetStorageData.customAlbums);

      if (savedData == null || savedData.toString().isEmpty) {
        customAlbums.clear();
        customAlbums.refresh();
        return;
      }

      final decoded = jsonDecode(savedData);

      if (decoded is! Map) {
        return;
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

      final Set<String> existingAssetIds = {};

      const int pageSize = 100;
      int page = 0;

      while (true) {
        final List<AssetEntity> result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        if (result.isEmpty) {
          break;
        }

        for (final asset in result) {
          existingAssetIds.add(asset.id);
        }

        if (result.length < pageSize) {
          break;
        }

        page++;
      }

      final List<String> albumsToRemove = [];

      for (final entry in data.entries) {
        final albumName = entry.key;

        if (entry.value is! Map) {
          albumsToRemove.add(albumName);
          continue;
        }

        final albumData = Map<String, dynamic>.from(entry.value);

        final List<String> oldAssetIds = List<String>.from(
          albumData["assetIds"] ?? [],
        );
        final List<String> validAssetIds = oldAssetIds
            .where((id) => existingAssetIds.contains(id))
            .toList();

        if (validAssetIds.isEmpty) {
          albumsToRemove.add(albumName);
          continue;
        }

        albumData["assetIds"] = validAssetIds;
        data[albumName] = albumData;
      }
      for (final albumName in albumsToRemove) {
        data.remove(albumName);
      }
      await GetStorageData.saveString(
        GetStorageData.customAlbums,
        jsonEncode(data),
      );
      customAlbums.clear();
      customAlbums.assignAll(data);
      customAlbums.refresh();

      debugPrint("CUSTOM ALBUMS REFRESHED => ${customAlbums.length}");
    } catch (e) {
      debugPrint("Refresh Custom Albums Error => $e");
    }
  }

  void onAlbumScaleUpdate(double scale) {
    int newCount = _startAlbumCrossAxisCount;
    if (scale < 0.90) {
      newCount = _startAlbumCrossAxisCount + 1;
    }

    if (scale < 0.78) {
      newCount = _startAlbumCrossAxisCount + 2;
    }
    if (scale > 1.10) {
      newCount = _startAlbumCrossAxisCount - 1;
    }

    if (scale > 1.25) {
      newCount = _startAlbumCrossAxisCount - 2;
    }

    newCount = newCount.clamp(2, 6);
    if (newCount != albumCrossAxisCount.value) {
      albumCrossAxisCount.value = newCount;

      GetStorageData.saveString(
        GetStorageData.albumsGridColumns,
        newCount.toString(),
      );
    }
  }

  Future<void> openCamera() async {
    if (Get.isRegistered<PhotosController>()) {
      Get.find<PhotosController>().watchForNewPhotos();
    }
    try {
      await const MethodChannel('native_camera').invokeMethod('openCamera');
    } on PlatformException catch (e) {
      debugPrint("Native Camera Error => ${e.code} : ${e.message}");
      AppToast.show(e.message ?? "Unable to open camera");
    } catch (e) {
      debugPrint("Camera Error => $e");
      AppToast.show("Camera Error: ${e.toString()}");
    }
  }

  Future<void> loadCreateAlbumMedia() async {
    try {
      isCreateAlbumLoading.value = true;

      createAlbumMedia.clear();
      selectedAlbumMediaIds.clear();

      const int pageSize = 100;

      int page = 0;

      while (true) {
        final List<AssetEntity> result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        if (result.isEmpty) {
          break;
        }

        createAlbumMedia.addAll(result);

        if (result.length < pageSize) {
          break;
        }
        page++;
      }
      debugPrint("Create Album Media: ${createAlbumMedia.length}");
    } catch (e) {
      debugPrint("Create Album Media Error: $e");
    } finally {
      isCreateAlbumLoading.value = false;
    }
  }

  void toggleCreateAlbumSelection(AssetEntity asset) {
    if (selectedAlbumMediaIds.contains(asset.id)) {
      selectedAlbumMediaIds.remove(asset.id);
    } else {
      selectedAlbumMediaIds.add(asset.id);
    }

    selectedAlbumMediaIds.refresh();
  }

  bool isCreateAlbumSelected(AssetEntity asset) {
    return selectedAlbumMediaIds.contains(asset.id);
  }

  Future<void> createAlbumAndImport({required String albumName}) async {
    try {
      isCreateAlbumLoading.value = true;

      final List<String> selectedIds = selectedAlbumMediaIds.toList();

      if (selectedIds.isEmpty) {
        AppToast.show("Please select at least one photo or video");
        return;
      }

      final savedData = GetStorageData.readString(GetStorageData.customAlbums);

      Map<String, dynamic> customAlbums = {};

      if (savedData != null && savedData.toString().isNotEmpty) {
        try {
          final decoded = jsonDecode(savedData);

          if (decoded is Map) {
            customAlbums = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint("Custom Album Decode Error => $e");
        }
      }

      final existingKey = customAlbums.keys.firstWhere(
        (key) => key.toLowerCase().trim() == albumName.toLowerCase().trim(),
        orElse: () => "",
      );

      if (existingKey.isNotEmpty) {
        AppToast.show("Please use another album name");
        return;
      }

      customAlbums[albumName] = {
        "name": albumName,
        "assetIds": selectedIds,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      };

      await GetStorageData.saveString(
        GetStorageData.customAlbums,
        jsonEncode(customAlbums),
      );
      await loadCustomAlbums();
      debugPrint("CUSTOM ALBUM CREATED => $albumName");
      debugPrint("SELECTED MEDIA => ${selectedIds.length}");
      selectedAlbumMediaIds.clear();
      selectedAlbumMediaIds.refresh();
      Get.back();

      AppToast.show("$albumName created with ${selectedIds.length} items");
    } catch (e) {
      debugPrint("CREATE ALBUM ERROR => $e");

      AppToast.show("Import Failed: ${e.toString()}");
    } finally {
      isCreateAlbumLoading.value = false;
    }
  }

  Future<void> loadCustomAlbums() async {
    try {
      final savedData = GetStorageData.readString(GetStorageData.customAlbums);

      customAlbums.clear();

      if (savedData == null || savedData.toString().isEmpty) {
        return;
      }

      final decoded = jsonDecode(savedData);

      if (decoded is Map) {
        customAlbums.assignAll(Map<String, dynamic>.from(decoded));
      }

      debugPrint("CUSTOM ALBUMS => ${customAlbums.length}");
    } catch (e) {
      debugPrint("Load Custom Albums Error => $e");
    }
  }

  Future<AssetEntity?> getCustomAlbumCover(List<String> assetIds) async {
    try {
      const int pageSize = 100;

      int page = 0;

      while (true) {
        final List<AssetEntity> result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        if (result.isEmpty) {
          break;
        }

        for (final asset in result) {
          if (assetIds.contains(asset.id)) {
            return asset;
          }
        }

        if (result.length < pageSize) {
          break;
        }

        page++;
      }
    } catch (e) {
      debugPrint("Custom Album Cover Error => $e");
    }

    return null;
  }

  Future<List<AssetEntity>> getCustomAlbumMedia(List<String> assetIds) async {
    try {
      final Set<String> targetIds = assetIds.toSet();
      final List<AssetEntity> foundAssets = [];

      const int pageSize = 100;
      int page = 0;
      while (true) {
        final List<AssetEntity> result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        if (result.isEmpty) {
          break;
        }

        for (final asset in result) {
          if (targetIds.contains(asset.id)) {
            foundAssets.add(asset);
          }
        }

        if (foundAssets.length == targetIds.length) {
          break;
        }

        if (result.length < pageSize) {
          break;
        }

        page++;
      }

      foundAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

      return foundAssets;
    } catch (e) {
      debugPrint("Custom Album Media Error => $e");
      return [];
    }
  }

  void startAlbumSelection(String albumId) {
    isAlbumSelectionMode.value = true;
    selectedAlbumIds.add(albumId);
    selectedAlbumIds.refresh();
  }

  void toggleAlbumSelection(String albumId) {
    if (selectedAlbumIds.contains(albumId)) {
      selectedAlbumIds.remove(albumId);
    } else {
      selectedAlbumIds.add(albumId);
    }

    if (selectedAlbumIds.isEmpty) {
      isAlbumSelectionMode.value = false;
    }
    selectedAlbumIds.refresh();
  }

  Future<List<AssetEntity>> getSelectedAlbumsMedia() async {
    final Set<String> ids = selectedAlbumIds.toSet();

    if (ids.isEmpty) {
      return [];
    }

    final List<AssetEntity> result = [];
    final Set<String> addedIds = {};
    for (final album in albums) {
      if (!ids.contains(album.id)) {
        continue;
      }

      try {
        final int count = await album.assetCountAsync;

        if (count <= 0) {
          continue;
        }

        final List<AssetEntity> media = await album.getAssetListRange(
          start: 0,
          end: count,
        );

        for (final asset in media) {
          if (addedIds.add(asset.id)) {
            result.add(asset);
          }
        }
      } catch (e) {
        debugPrint("Selected Album Media Error => ${album.name}: $e");
      }
    }
    for (final id in ids) {
      if (!id.startsWith("custom_")) {
        continue;
      }

      final String albumName = id.substring("custom_".length);

      final data = customAlbums[albumName];

      if (data is! Map) {
        continue;
      }

      final List<String> assetIds = List<String>.from(data["assetIds"] ?? []);

      final media = await getCustomAlbumMedia(assetIds);

      for (final asset in media) {
        if (addedIds.add(asset.id)) {
          result.add(asset);
        }
      }
    }

    result.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    return result;
  }

  Future<void> shareSelectedAlbums() async {
    try {
      final media = await getSelectedAlbumsMedia();

      if (media.isEmpty) {
        AppToast.show("No media found in selected album");
        return;
      }

      final files = <XFile>[];

      for (final asset in media) {
        final file = await asset.file;

        if (file != null && await file.exists()) {
          files.add(XFile(file.path));
        }
      }

      if (files.isEmpty) {
        AppToast.show("Unable to access selected media");
        return;
      }

      await SharePlus.instance.share(ShareParams(files: files, title: "Share"));
    } catch (e) {
      debugPrint("Share Selected Albums Error => $e");

      AppToast.show("Unable to share selected albums");
    }
  }

  Future<void> favoriteSelectedAlbums() async {
    try {
      final media = await getSelectedAlbumsMedia();

      if (media.isEmpty) {
        return;
      }

      for (final asset in media) {
        try {
          await PhotoManager.plugin.favoriteAsset(asset.id, true);
        } catch (e) {
          debugPrint("Favorite Error => ${asset.id}: $e");
        }
      }

      AppToast.show("${media.length} items added to favorites");
    } catch (e) {
      debugPrint("Favorite Selected Albums Error => $e");

      AppToast.show("Unable to add selected media to favorites");
    }
  }

  Future<void> deleteSelectedAlbumMedia() async {
    try {
      final media = await getSelectedAlbumsMedia();

      if (media.isEmpty) {
        clearAlbumSelection();
        return;
      }

      final bool? confirm = await Get.dialog<bool>(
        ChromeDialog(
          title: 'Delete',
          message: 'Delete ${media.length} selected items?',
          actions: [
            ChromeButton.cancel(onPressed: () => Get.back(result: false)),
            ChromeButton.danger(
              label: 'Delete',
              onPressed: () => Get.back(result: true),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }

      final ids = media.map((e) => e.id).toList();

      final deletedIds = await MediaActionService.deleteIds(ids);

      if (deletedIds.isNotEmpty) {
        await loadAlbums();

        await loadCustomAlbums();

        clearAlbumSelection();

        AppToast.show("${deletedIds.length} items deleted");
      }
    } catch (e) {
      debugPrint("Delete Selected Album Media Error => $e");

      AppToast.show("Unable to delete selected items");
    }
  }

  bool isAlbumSelected(String albumId) {
    return selectedAlbumIds.contains(albumId);
  }

  void clearAlbumSelection() {
    selectedAlbumIds.clear();
    isAlbumSelectionMode.value = false;
    selectedAlbumIds.refresh();
  }

  Future<void> deleteSelectedAlbums() async {
    try {
      final selected = selectedAlbumIds.toList();

      if (selected.isEmpty) {
        return;
      }
      final List<String> customKeysToDelete = [];

      for (final id in selected) {
        if (id.startsWith("custom_")) {
          customKeysToDelete.add(id.substring("custom_".length));
        }
      }

      if (customKeysToDelete.isEmpty) {
        AppToast.show("Normal gallery albums cannot be deleted from this app.");

        clearAlbumSelection();
        return;
      }
      final savedData = GetStorageData.readString(GetStorageData.customAlbums);

      Map<String, dynamic> data = {};

      if (savedData != null && savedData.toString().isNotEmpty) {
        try {
          final decoded = jsonDecode(savedData);

          if (decoded is Map) {
            data = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint("Delete Album Decode Error => $e");
        }
      }
      for (final albumName in customKeysToDelete) {
        data.remove(albumName);
      }
      await GetStorageData.saveString(
        GetStorageData.customAlbums,
        jsonEncode(data),
      );
      customAlbums.clear();
      customAlbums.assignAll(data);

      selectedAlbumIds.clear();
      isAlbumSelectionMode.value = false;
      selectedAlbumIds.refresh();
      customAlbums.refresh();

      AppToast.show("${customKeysToDelete.length} album deleted");
    } catch (e) {
      debugPrint("Delete Selected Albums Error => $e");

      AppToast.show("Unable to delete album");
    }
  }

  Future<void> removeAssetFromCustomAlbum(
    String albumName,
    String assetId,
  ) async {
    try {
      final savedData = GetStorageData.readString(GetStorageData.customAlbums);

      if (savedData == null || savedData.toString().isEmpty) {
        return;
      }

      final decoded = jsonDecode(savedData);

      if (decoded is! Map) {
        return;
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

      if (!data.containsKey(albumName)) {
        return;
      }

      final albumData = Map<String, dynamic>.from(data[albumName]);

      final List<String> assetIds = List<String>.from(
        albumData["assetIds"] ?? [],
      );
      assetIds.remove(assetId);
      albumData["assetIds"] = assetIds;
      data[albumName] = albumData;
      await GetStorageData.saveString(
        GetStorageData.customAlbums,
        jsonEncode(data),
      );

      customAlbums.clear();
      customAlbums.assignAll(data);
      customAlbums.refresh();

      debugPrint(
        "CUSTOM ALBUM UPDATED => $albumName | ITEMS => ${assetIds.length}",
      );
    } catch (e) {
      debugPrint("Remove Custom Album Asset Error => $e");
    }
  }

  Future<void> applyAlbumSort({
    required String sortType,
    required bool ascending,
  }) async {
    albumSortBy.value = sortType;
    albumSortAscending.value = ascending;

    final normalList = albums.toList();

    switch (sortType) {
      case "Album Name":
        normalList.sort((a, b) {
          final result = a.name.toLowerCase().compareTo(b.name.toLowerCase());

          return ascending ? result : -result;
        });
        break;

      case "File Path":
        normalList.sort((a, b) {
          final aPath = a.name.toLowerCase();
          final bPath = b.name.toLowerCase();

          final result = aPath.compareTo(bPath);

          return ascending ? result : -result;
        });
        break;

      case "File Size":
        final Map<String, int> counts = {};

        await Future.wait(
          normalList.map((album) async {
            counts[album.id] = await album.assetCountAsync;
          }),
        );

        normalList.sort((a, b) {
          final result = (counts[a.id] ?? 0).compareTo(counts[b.id] ?? 0);

          return ascending ? result : -result;
        });
        break;

      case "Last modified":
        final Map<String, DateTime> dates = {};

        await Future.wait(
          normalList.map((album) async {
            try {
              final count = await album.assetCountAsync;

              if (count > 0) {
                final assets = await album.getAssetListRange(start: 0, end: 1);

                if (assets.isNotEmpty) {
                  dates[album.id] = assets.first.modifiedDateTime;
                }
              }
            } catch (_) {}
          }),
        );

        normalList.sort((a, b) {
          final aDate = dates[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = dates[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);

          final result = aDate.compareTo(bDate);

          return ascending ? result : -result;
        });
        break;

      case "Date taken":
        final Map<String, DateTime> dates = {};

        await Future.wait(
          normalList.map((album) async {
            try {
              final count = await album.assetCountAsync;

              if (count > 0) {
                final assets = await album.getAssetListRange(start: 0, end: 1);

                if (assets.isNotEmpty) {
                  dates[album.id] = assets.first.createDateTime;
                }
              }
            } catch (_) {}
          }),
        );

        normalList.sort((a, b) {
          final aDate = dates[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = dates[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);

          final result = aDate.compareTo(bDate);

          return ascending ? result : -result;
        });
        break;
    }

    albums.assignAll(normalList);
    albums.refresh();
  }

  AssetPathEntity? getAlbumByName(String name) {
    try {
      return albums.firstWhere(
        (album) => album.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  AssetPathEntity? getAlbumContains(String name) {
    try {
      return albums.firstWhere(
        (album) => album.name.toLowerCase().contains(name.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  AssetPathEntity? get cameraAlbum {
    return getAlbumContains("camera");
  }

  AssetPathEntity? get screenshotAlbum {
    return getAlbumContains("screenshot");
  }

  AssetPathEntity? get downloadAlbum {
    return getAlbumContains("download");
  }

  AssetPathEntity? get recentAlbum {
    return getAlbumContains("recent");
  }

  AssetPathEntity? get picturesAlbum {
    return getAlbumContains("picture");
  }

  AssetPathEntity? get collageAlbum {
    return getAlbumContains("collage");
  }

  List<AssetPathEntity> get priorityAlbums {
    final result = <AssetPathEntity>[];

    final recent = recentAlbum;
    final camera = cameraAlbum;
    final screenshot = screenshotAlbum;
    final download = downloadAlbum;

    if (camera != null) result.add(camera);
    if (recent != null && !result.any((a) => a.id == recent.id)) {
      result.add(recent);
    }
    if (screenshot != null && !result.any((a) => a.id == screenshot.id)) {
      result.add(screenshot);
    }
    if (download != null && !result.any((a) => a.id == download.id)) {
      result.add(download);
    }

    return result;
  }

  List<AssetPathEntity> get otherAlbums {
    final priorityIds = priorityAlbums.map((album) => album.id).toSet();

    return albums.where((album) {
      final name = album.name.toLowerCase().trim();

      if (priorityIds.contains(album.id)) return false;

      return !name.contains("recent") &&
          !name.contains("all") &&
          !name.contains("video");
    }).toList();
  }
}

class AlbumPhotosController extends GetxController {
  final AssetPathEntity album;

  AlbumPhotosController({required this.album});
  final RxList<AssetEntity> media = <AssetEntity>[].obs;
  final RxBool isLoading = true.obs;
  final RxInt crossAxisCount = 3.obs;

  final RxSet<String> selectedIds = <String>{}.obs;

  bool get isSelectionMode => selectedIds.isNotEmpty;

  void startSelection(AssetEntity asset) {
    selectedIds.clear();
    selectedIds.add(asset.id);
    selectedIds.refresh();
  }

  void toggleSelection(AssetEntity asset) {
    if (selectedIds.contains(asset.id)) {
      selectedIds.remove(asset.id);
    } else {
      selectedIds.add(asset.id);
    }

    selectedIds.refresh();
  }

  Future<void> reloadFrom(AssetPathEntity fresh) async {
    try {
      final List<AssetEntity> recent = await fresh.getAssetListRange(
        start: 0,
        end: 40,
      );
      final Set<String> known = media.map((asset) => asset.id).toSet();
      final List<AssetEntity> added = recent
          .where((asset) => known.add(asset.id))
          .toList();
      if (added.isEmpty) return;
      media.insertAll(0, added);
      media.refresh();
    } catch (e) {
      debugPrint('ALBUM OPEN REFRESH ERROR: $e');
    }
  }

  Future<void> refreshAlbumMedia() async {
    try {
      final int count = await album.assetCountAsync;

      if (count <= 0) {
        media.clear();
        selectedIds.clear();
        media.refresh();
        selectedIds.refresh();
        return;
      }

      final List<AssetEntity> freshAssets = await album.getAssetListRange(
        start: 0,
        end: count,
      );

      media.assignAll(freshAssets);
      media.refresh();

      selectedIds.clear();
      selectedIds.refresh();

      debugPrint(
        "ALBUM MEDIA REFRESHED => ${album.name} | ${freshAssets.length}",
      );
    } catch (e) {
      debugPrint("Refresh Album Media Error => $e");
    }
  }

  bool isSelected(AssetEntity asset) {
    return selectedIds.contains(asset.id);
  }

  final ScrollController albumScrollController = ScrollController();

  Timer? _autoScrollTimer;

  void updateAutoScroll({
    required double localY,
    required double viewportHeight,
  }) {
    if (!isDragSelecting.value) {
      stopAutoScroll();
      return;
    }

    const double edgeSize = 90;

    if (localY < edgeSize) {
      _startAutoScroll(-1);
    } else if (localY > viewportHeight - edgeSize) {
      _startAutoScroll(1);
    } else {
      stopAutoScroll();
    }
  }

  void _startAutoScroll(int direction) {
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) {
      return;
    }

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!isDragSelecting.value) {
        stopAutoScroll();
        return;
      }

      if (!albumScrollController.hasClients) {
        return;
      }

      const double amount = 14;

      double newOffset = albumScrollController.offset + (amount * direction);

      newOffset = newOffset.clamp(
        albumScrollController.position.minScrollExtent,
        albumScrollController.position.maxScrollExtent,
      );

      albumScrollController.jumpTo(newOffset);
    });
  }

  void stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void clearSelection() {
    selectedIds.clear();
    selectedIds.refresh();
  }

  final RxBool isDragSelecting = false.obs;

  final Set<String> _dragVisitedIds = <String>{};

  String? _lastDragAssetId;

  void startDragSelection(AssetEntity asset) {
    isDragSelecting.value = true;

    _dragVisitedIds.clear();

    _lastDragAssetId = asset.id;

    _dragVisitedIds.add(asset.id);

    if (!selectedIds.contains(asset.id)) {
      selectedIds.add(asset.id);
      selectedIds.refresh();
    }
  }

  void selectDuringDrag(AssetEntity asset) {
    if (!isDragSelecting.value) {
      return;
    }

    if (_lastDragAssetId == asset.id) {
      return;
    }

    _lastDragAssetId = asset.id;

    if (_dragVisitedIds.contains(asset.id)) {
      return;
    }

    _dragVisitedIds.add(asset.id);

    if (!selectedIds.contains(asset.id)) {
      selectedIds.add(asset.id);
      selectedIds.refresh();
    }
  }

  void endDragSelection() {
    isDragSelecting.value = false;

    _lastDragAssetId = null;

    _dragVisitedIds.clear();

  }

  int _startCrossAxisCount = 3;
  @override
  void onInit() {
    super.onInit();
    loadAlbumMedia();
  }

  List<AssetEntity> getSelectedAssets() {
    return media.where((asset) => selectedIds.contains(asset.id)).toList();
  }

  AssetEntity? getFirstSelected() {
    for (final asset in media) {
      if (selectedIds.contains(asset.id)) {
        return asset;
      }
    }

    return null;
  }

  PhotoViewController? _getSelectedPhotoController() {
    final AssetEntity? selectedAsset = getFirstSelected();

    if (selectedAsset == null) {
      return null;
    }

    final PhotoViewController controller = PhotoViewController(
      selectedAsset,
      albumMedia: media.toList(),
    );

    controller.initializePhotoView();

    return controller;
  }

bool _requireSingleSelection(String actionName) {
    if (selectedIds.length > 1) {
      AppToast.show("Please select only one item for $actionName");
      return false;
    }

    return true;
  }

  PhotoViewController _photoControllerForBatch(List<AssetEntity> assets) {
    return PhotoViewController(assets.first, albumMedia: media.toList());
  }

Future<void> shareSelected() async {
    final List<AssetEntity> assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final PhotoViewController controller = _photoControllerForBatch(assets);

    await controller.shareAssets(assets);
  }

Future<void> lockSelected() async {
    final List<AssetEntity> assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final PhotoViewController controller = _photoControllerForBatch(assets);

    final List<String> hiddenIds = await controller.hideAssets(assets);

    if (hiddenIds.isNotEmpty) {
      media.removeWhere((asset) => hiddenIds.contains(asset.id));
      media.refresh();
    }

    clearSelection();
  }

Future<void> copySelected() async {
    final List<AssetEntity> assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final PhotoViewController controller = _photoControllerForBatch(assets);

    await controller.copyAssets(assets);

    clearSelection();
  }

Future<void> moveSelected() async {
    final List<AssetEntity> assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final PhotoViewController controller = _photoControllerForBatch(assets);

    final List<String> movedIds = await controller.moveAssets(assets);

    if (movedIds.isNotEmpty) {
      media.removeWhere((asset) => movedIds.contains(asset.id));
      media.refresh();
    }

    clearSelection();
  }

  Future<void> renameSelected() async {
    if (!_requireSingleSelection("Rename")) {
      return;
    }

    final PhotoViewController? photoController = _getSelectedPhotoController();

    if (photoController == null) {
      return;
    }

    await photoController.renamePhoto();

    await refreshAlbumMedia();
  }

  void replaceRenamedAsset(String oldAssetId, AssetEntity newAsset) {
    final int index = media.indexWhere((asset) => asset.id == oldAssetId);

    if (index == -1) {
      return;
    }

    media[index] = newAsset;
    media.refresh();

    debugPrint("RENAMED ASSET REPLACED => $oldAssetId -> ${newAsset.id}");
  }

  Future<void> editSelected() async {
    if (!_requireSingleSelection("Edit")) {
      return;
    }

    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.editPhoto();
  }

  Future<void> setAsSelected() async {
    if (!_requireSingleSelection("Set as wallpaper")) {
      return;
    }

    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.setAsWallpaper();
  }

  Future<void> resizeSelected() async {
    if (!_requireSingleSelection("Resize")) {
      return;
    }

    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.resizePhoto();
  }

  Future<void> infoSelected() async {
    if (!_requireSingleSelection("Info")) {
      return;
    }

    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.showDetails();
  }

  void onGridScaleStart() {
    _startCrossAxisCount = crossAxisCount.value;
  }

  void onGridScaleUpdate(double scale) {
    int newCrossAxisCount = _startCrossAxisCount;

    if (scale < 0.90) {
      newCrossAxisCount = _startCrossAxisCount + 1;
    }

    if (scale < 0.78) {
      newCrossAxisCount = _startCrossAxisCount + 2;
    }

    if (scale < 0.66) {
      newCrossAxisCount = _startCrossAxisCount + 3;
    }

    if (scale > 1.10) {
      newCrossAxisCount = _startCrossAxisCount - 1;
    }

    if (scale > 1.25) {
      newCrossAxisCount = _startCrossAxisCount - 2;
    }

    if (scale > 1.40) {
      newCrossAxisCount = _startCrossAxisCount - 3;
    }
    newCrossAxisCount = newCrossAxisCount.clamp(2, 6);

    if (newCrossAxisCount != crossAxisCount.value) {
      crossAxisCount.value = newCrossAxisCount;
    }
  }

  Future<void> loadAlbumMedia() async {
    isLoading.value = true;

    try {
      final int count = await album.assetCountAsync;

      debugPrint(
        "OPEN ALBUM => ${album.name} | ID => ${album.id} | COUNT => $count",
      );

      if (count == 0) {
        media.clear();
        return;
      }

      final List<AssetEntity> assets = await album.getAssetListRange(
        start: 0,
        end: count,
      );

      debugPrint("ALBUM MEDIA => ${album.name} | FOUND => ${assets.length}");

      media.assignAll(assets);
      media.refresh();
    } catch (e, stackTrace) {
      debugPrint("Album Media Error => $e");
      debugPrint("$stackTrace");
      media.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Map<DateTime, List<AssetEntity>> get groupedMedia {
    final Map<DateTime, List<AssetEntity>> grouped = {};

    for (final asset in media) {
      final DateTime date = DateTime(
        asset.createDateTime.year,
        asset.createDateTime.month,
        asset.createDateTime.day,
      );

      grouped.putIfAbsent(date, () => []);

      grouped[date]!.add(asset);
    }

    return grouped;
  }

  Future<void> deleteSelected() async {
    final List<AssetEntity> selected = getSelectedAssets();

    if (selected.isEmpty) {
      return;
    }

final String? action = await Get.dialog<String>(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 35),

        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  "Are you sure you want to delete the file(s)?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg(Color(0xff222222)),
                  ),
                ),
              ),

              const SizedBox(height: 22),

SizedBox(
                width: double.infinity,
                height: 40,

                child: ElevatedButton(
                  onPressed: () {
                    Get.back(result: "recycle");
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: InnerChrome.dialogPrimaryBg,
                    foregroundColor: InnerChrome.dialogPrimaryFg,
                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  child: const Text(
                    "Add to Recycle Bin",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

SizedBox(
                width: double.infinity,
                height: 40,

                child: ElevatedButton(
                  onPressed: () {
                    Get.back(result: "permanent");
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: InnerChrome.dialogSecondaryBg,
                    foregroundColor: InnerChrome.dialogSecondaryFg,
                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  child: const Text(
                    "Delete permanently",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null) {
      return;
    }

    if (!await MediaActionService.ensureMediaManagement()) {
      return;
    }

    try {
      final Set<String> deletedIds = {};
      if (action == "recycle") {
        final RecycleBinController recycleController =
        Get.isRegistered<RecycleBinController>()
            ? Get.find<RecycleBinController>()
            : Get.put(RecycleBinController());

        for (final asset in selected) {
          try {
            final bool saved =
            await recycleController.addToRecycleBin(asset);

            if (!saved) {
              debugPrint(
                "Recycle Bin save failed => ${asset.id}",
              );

              continue;
            }

            final List<String> result =
            await MediaActionService.deleteIds([
              asset.id,
            ]);

            if (result.contains(asset.id)) {
              deletedIds.add(asset.id);

              final File? file = await asset.file;

              if (file != null) {
                await FileOperationService.deleteEmptyParentFolder(
                  file.parent,
                );
              }
            }
          } catch (e) {
            debugPrint(
              "Recycle delete error ${asset.id} => $e",
            );
          }
        }

        if (deletedIds.isNotEmpty) {
          media.removeWhere(
                (asset) => deletedIds.contains(asset.id),
          );

          media.refresh();
        }

        clearSelection();

        AppToast.show(
          "${deletedIds.length} item"
            "${deletedIds.length == 1 ? "" : "s"} moved to Recycle Bin",
        );

        return;
      }

if (action == "permanent") {
        final List<String> ids =
        selected.map((asset) => asset.id).toList();

        final List<String> result =
        await MediaActionService.deleteIds(ids);

        deletedIds.addAll(result);

        if (deletedIds.isNotEmpty) {
          for (final asset in selected) {
            if (!deletedIds.contains(asset.id)) {
              continue;
            }

            final File? file = await asset.file;

            if (file != null) {
              await FileOperationService.deleteEmptyParentFolder(
                file.parent,
              );
            }
          }

          media.removeWhere(
                (asset) => deletedIds.contains(asset.id),
          );

          media.refresh();
        }

        clearSelection();

        AppToast.show(
          "${deletedIds.length} item"
            "${deletedIds.length == 1 ? "" : "s"} deleted permanently",
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        "Album Delete Selected Error => $e",
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      AppToast.show("Unable to delete selected files");
    }
  }
  Future<void> favoriteSelected() async {
    final List<AssetEntity> selected = getSelectedAssets();

    if (selected.isEmpty) {
      return;
    }

    try {
      for (final AssetEntity asset in selected) {
        await PhotoManager.plugin.favoriteAsset(asset.id, true);
      }

      clearSelection();

      AppToast.show("${selected.length} items added to favorites");
    } catch (e) {
      debugPrint("Favorite Error => $e");

      AppToast.show("Unable to add selected items to favorites");
    }
  }

  @override
  void onClose() {
    stopAutoScroll();
    albumScrollController.dispose();
    selectedIds.clear();
    super.onClose();
  }
}
