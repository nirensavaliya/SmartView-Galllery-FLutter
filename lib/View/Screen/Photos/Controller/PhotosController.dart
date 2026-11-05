import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/MediaActionService.dart';
import 'package:gallery_photos/Common/MediaManager.dart';
import 'package:gallery_photos/Common/SmartSearchService.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/Albums/AlbumsScreen.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotoViewController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/SmartSearchController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:gallery_photos/View/Setting/FileOperationService.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class PhotosController extends GetxController {
  final RxList<AssetEntity> allMedia = <AssetEntity>[].obs;
  final RxList<AssetEntity> filteredMedia = <AssetEntity>[].obs;
  final Rxn<DateTime> selectedDate = Rxn<DateTime>();
  final RxBool firstPageLoaded = false.obs;
  Future<void>? _initialMediaLoad;
  final RxInt crossAxisCount = 3.obs;
  int _startCrossAxisCount = 3;
  double _lastScale = 1.0;
  bool isLoadingMore = false;
  final RxBool isAlbumSelectionMode = false.obs;
  int currentPage = 0;
  static const int pageSize = 100;
  final RxBool filterImages = true.obs;
  final RxBool filterVideos = true.obs;
  final RxBool filterGifs = true.obs;
  final RxBool filterRawImages = true.obs;
  final RxBool filterSvgs = true.obs;
  final RxBool filterPortraits = false.obs;
  final RxString sortBy = "Last modified".obs;
  final RxBool sortAscending = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final Map<String, Uint8List> thumbnailCache = {};
  static const int _maxThumbnailCache = 400;
  final SmartSearchController smartSearchController =
  Get.put(SmartSearchController());
  List<GroupSection>? _groupedCache;
  String _groupedSignature = '';
  List<GalleryRow>? _rowsCache;
  int _rowsColumns = -1;
  Timer? _searchTimer;
  void invalidateGalleryCache() {
    _groupedCache = null;
    _groupedSignature = '';
    _rowsCache = null;
    _rowsColumns = -1;
  }
  Future<void> searchPhotos(String query) async {
    _searchTimer?.cancel();

    final text = query.trim().toLowerCase();

    searchQuery.value = text;

    if (text.isEmpty) {
      smartSearchController.isAnalyzing.value = false;
      await applyMediaFilter();
      return;
    }

    _searchTimer = Timer(
      const Duration(milliseconds: 350),
          () async {
        if (searchQuery.value != text) {
          return;
        }

        smartSearchController.isAnalyzing.value = true;

        try {
          final results =
          await smartSearchController.searchByImageContent(
            allMedia.toList(),
            text,
          );

          if (searchQuery.value != text) {
            return;
          }

          final byId = <String, AssetEntity>{
            for (final asset in results) asset.id: asset,
          };
          for (final asset in allMedia) {
            if (SmartSearchService.instance.assetMatchesQuery(asset, text)) {
              byId.putIfAbsent(asset.id, () => asset);
            }
          }

          filteredMedia.assignAll(byId.values.toList());

          debugPrint(
            "SMART SEARCH => $text | RESULTS => ${results.length}",
          );
        } catch (e) {
          debugPrint("Search Error => $e");

          if (searchQuery.value == text) {
            filteredMedia.clear();
          }
        } finally {
          if (searchQuery.value == text) {
            smartSearchController.isAnalyzing.value = false;
          }
        }
      },
    );
  }


  Future<void> _indexSmartSearch() async {
    try {
      await SmartSearchService.instance.init();
      for (var i = 0; i < 20 && allMedia.isEmpty; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (allMedia.isEmpty) return;
      await SmartSearchService.instance.indexAssets(allMedia.toList());
    } catch (e) {
      debugPrint("SmartSearch indexing failed: $e");
    }
  }

  void trimThumbnailCache({int keep = 60}) {
    if (thumbnailCache.length <= keep) {
      return;
    }

    final keys = thumbnailCache.keys.toList();
    final removeCount = thumbnailCache.length - keep;

    for (int i = 0; i < removeCount; i++) {
      thumbnailCache.remove(keys[i]);
    }
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

  final RxString groupBy = "Last modified (daily)".obs;
  final RxBool groupAscending = false.obs;
  final RxBool showFileCount = false.obs;
  final RxSet<String> selectedMediaIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

  final RxBool isDragSelecting = false.obs;

  final Map<String, GlobalKey> _selectionKeys = {};

  Offset? _dragStartPosition;
  String? _dragStartAssetId;
  String? _lastDragSelectedId;

  GlobalKey selectionKeyFor(String assetId) {
    return _selectionKeys.putIfAbsent(assetId, () => GlobalKey());
  }

  void removeSelectionKey(String assetId) {
    _selectionKeys.remove(assetId);
  }

  void startDragSelection(AssetEntity asset, Offset position) {
    _dragStartPosition = position;
    _dragStartAssetId = asset.id;
    _lastDragSelectedId = null;
    isDragSelecting.value = false;
  }

  void updateDragSelection(Offset position) {
    if (_dragStartPosition == null || _dragStartAssetId == null) {
      return;
    }

    final distance = (position - _dragStartPosition!).distance;
    if (!isDragSelecting.value && distance < 8) {
      return;
    }

    if (!isDragSelecting.value) {
      isDragSelecting.value = true;
      final firstAsset = _findAssetById(_dragStartAssetId!);

      if (firstAsset != null) {
        startPhotoSelection(firstAsset);
        _lastDragSelectedId = firstAsset.id;
      }
    }

    final asset = _assetAtPosition(position);

    if (asset == null) {
      return;
    }
    if (_lastDragSelectedId == asset.id) {
      return;
    }

    _lastDragSelectedId = asset.id;

    if (!selectedMediaIds.contains(asset.id)) {
      selectedMediaIds.add(asset.id);
      selectedMediaIds.refresh();
    }
  }

  AssetEntity? _findAssetById(String id) {
    for (final asset in filteredMedia) {
      if (asset.id == id) {
        return asset;
      }
    }

    return null;
  }

  AssetEntity? _assetAtPosition(Offset position) {
    for (final entry in _selectionKeys.entries) {
      final key = entry.value;
      final context = key.currentContext;

      if (context == null) {
        continue;
      }

      final renderObject = context.findRenderObject();

      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      if (rect.contains(position)) {
        return _findAssetById(entry.key);
      }
    }

    return null;
  }

  void endDragSelection() {
    _dragStartPosition = null;
    _dragStartAssetId = null;
    _lastDragSelectedId = null;

    isDragSelecting.value = false;
  }

  @override
  void onInit() {
    super.onInit();
    loadSavedGridColumns();
    ever<List<AssetEntity>>(filteredMedia, (_) => invalidateGalleryCache());
    ever<String>(groupBy, (_) => invalidateGalleryCache());
    ever<bool>(groupAscending, (_) => invalidateGalleryCache());
    ever<bool>(showFileCount, (_) => invalidateGalleryCache());
    ever<int>(crossAxisCount, (_) => invalidateGalleryCache());
  }

  Future<void> refreshMedia() async {
    if (isLoadingMore) {
      return;
    }

    try {
      isLoadingMore = true;

      await PhotoManager.clearFileCache();

      final result = await MediaManger.getAllMedia(page: 0, size: pageSize);

      final uniqueIds = <String>{};
      final uniqueMedia = <AssetEntity>[];
      for (final asset in result) {
        if (uniqueIds.add(asset.id)) {
          uniqueMedia.add(asset);
        }
      }

      allMedia.assignAll(uniqueMedia);

      currentPage = 0;

      thumbnailCache.clear();

      await applyMediaFilter();

      firstPageLoaded.value = true;

      log("MEDIA REFRESHED ONCE: ${allMedia.length}");
    } catch (e) {
      log("Refresh Media Error: $e");
    } finally {
      isLoadingMore = false;

      unawaited(loadRemainingMediaInBackground());
    }
  }

  void startPhotoSelection(AssetEntity asset) {
    isSelectionMode.value = true;

    selectedMediaIds.clear();
    selectedMediaIds.add(asset.id);

    selectedMediaIds.refresh();
  }

  void togglePhotoSelection(AssetEntity asset) {
    if (selectedMediaIds.contains(asset.id)) {
      selectedMediaIds.remove(asset.id);
    } else {
      selectedMediaIds.add(asset.id);
    }

    if (selectedMediaIds.isEmpty) {
      isSelectionMode.value = false;
    }

    selectedMediaIds.refresh();
  }

  bool isPhotoSelected(AssetEntity asset) {
    return selectedMediaIds.contains(asset.id);
  }

  void selectAllPhotos() {
    if (filteredMedia.isEmpty) return;

    final bool allSelected = filteredMedia.every(
      (asset) => selectedMediaIds.contains(asset.id),
    );

    if (allSelected) {
      selectedMediaIds.clear();
      isSelectionMode.value = false;
    } else {
      isSelectionMode.value = true;
      selectedMediaIds
        ..clear()
        ..addAll(filteredMedia.map((asset) => asset.id));
    }

    selectedMediaIds.refresh();
  }

  void clearPhotoSelection() {
    selectedMediaIds.clear();
    isSelectionMode.value = false;
    selectedMediaIds.refresh();
  }

  List<AssetEntity> getSelectedAssets() {
    return filteredMedia
        .where((asset) => selectedMediaIds.contains(asset.id))
        .toList();
  }

  AssetEntity? getFirstSelected() {
    for (final asset in filteredMedia) {
      if (selectedMediaIds.contains(asset.id)) {
        return asset;
      }
    }

    return null;
  }

  PhotoViewController? _getSelectedPhotoController() {
    final AssetEntity? asset = getFirstSelected();

    if (asset == null) {
      return null;
    }

    final PhotoViewController controller = PhotoViewController(
      asset,
      albumMedia: filteredMedia.toList(),
    );

    controller.initializePhotoView();

    return controller;
  }

  PhotoViewController _photoControllerForBatch(List<AssetEntity> assets) {
    return PhotoViewController(
      assets.first,
      albumMedia: filteredMedia.toList(),
    );
  }

  bool _requireSingleSelection(String actionName) {
    if (selectedMediaIds.length > 1) {
      AppToast.show("Please select only one item for $actionName");

      return false;
    }

    return true;
  }

Future<void> shareSelected() async {
    final assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final controller = _photoControllerForBatch(assets);

    await controller.shareAssets(assets);
  }

Future<void> lockSelected() async {
    final assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final controller = _photoControllerForBatch(assets);

    final hiddenIds = await controller.hideAssets(assets);

    if (hiddenIds.isNotEmpty) {
      allMedia.removeWhere((asset) => hiddenIds.contains(asset.id));

      filteredMedia.removeWhere((asset) => hiddenIds.contains(asset.id));

      for (final id in hiddenIds) {
        thumbnailCache.remove(id);
      }

      allMedia.refresh();
      filteredMedia.refresh();
    }

    clearPhotoSelection();
  }

Future<void> copySelected() async {
    final assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final controller = _photoControllerForBatch(assets);

    await controller.copyAssets(assets);

    clearPhotoSelection();
  }

Future<void> moveSelected() async {
    final assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    final controller = _photoControllerForBatch(assets);

    final movedIds = await controller.moveAssets(assets);

    if (movedIds.isNotEmpty) {
      allMedia.removeWhere((asset) => movedIds.contains(asset.id));

      filteredMedia.removeWhere((asset) => movedIds.contains(asset.id));

      for (final id in movedIds) {
        thumbnailCache.remove(id);
      }

      allMedia.refresh();
      filteredMedia.refresh();
    }

    clearPhotoSelection();
  }

Future<void> renameSelected() async {
    if (!_requireSingleSelection("Rename")) {
      return;
    }

    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.renamePhoto();

    await refreshMedia();

    clearPhotoSelection();
  }

Future<void> editSelected() async {
    if (!_requireSingleSelection("Edit")) {
      return;
    }

    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.editPhoto();
  }

Future<void> setAsSelected() async {
    if (!_requireSingleSelection("Set as wallpaper")) {
      return;
    }

    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.setAsWallpaper();
  }

Future<void> resizeSelected() async {
    if (!_requireSingleSelection("Resize")) {
      return;
    }

    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.resizePhoto();
  }

Future<void> infoSelected() async {
    if (!_requireSingleSelection("Info")) {
      return;
    }

    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.showDetails();
  }

Future<void> deleteSelected() async {
    await deleteSelectedPhotos();
  }

Future<void> favoriteSelected() async {
    final assets = getSelectedAssets();

    if (assets.isEmpty) {
      return;
    }

    try {
      for (final asset in assets) {
        await PhotoManager.plugin.favoriteAsset(asset.id, true);
      }

      clearPhotoSelection();

      AppToast.show("${assets.length} items added to favorites");
    } catch (e) {
      debugPrint("Favorite Selected Error => $e");

      AppToast.show("Unable to add selected items to favorites");
    }
  }

  void loadSavedGridColumns() {
    final savedColumns = GetStorageData.readString(
      GetStorageData.photosGridColumns,
    );

    if (savedColumns == null) {
      crossAxisCount.value = 3;
      _startCrossAxisCount = 3;
      return;
    }

    final columns = int.tryParse(savedColumns.toString());

    if (columns != null && columns >= 2 && columns <= 8) {
      crossAxisCount.value = columns;
      _startCrossAxisCount = columns;
    } else {
      crossAxisCount.value = 3;
      _startCrossAxisCount = 3;
    }
  }

  void saveGridColumns(int columns) {
    columns = columns.clamp(2, 8);
    crossAxisCount.value = columns;
    _startCrossAxisCount = columns;

    GetStorageData.saveString(
      GetStorageData.photosGridColumns,
      columns.toString(),
    );
  }

  void onGridScaleStart() {
    _startCrossAxisCount = crossAxisCount.value;
    _lastScale = 1.0;
  }

  void onGridScaleUpdate(double scale) {
    if (scale == 1.0) {
      return;
    }
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
    if (newCrossAxisCount == crossAxisCount.value) {
      return;
    }

    crossAxisCount.value = newCrossAxisCount;
    GetStorageData.saveString(
      GetStorageData.photosGridColumns,
      newCrossAxisCount.toString(),
    );
  }

Future<Uint8List?> getThumbnail(AssetEntity asset) async {
    final cachedThumbnail = thumbnailCache[asset.id];

    if (cachedThumbnail != null) {
      return cachedThumbnail;
    }

    final thumbnail = await asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
    );

    if (thumbnail != null) {
      if (thumbnailCache.length >= _maxThumbnailCache) {
        final oldestKeys = thumbnailCache.keys
            .take(thumbnailCache.length - _maxThumbnailCache + 1)
            .toList();

        for (final key in oldestKeys) {
          thumbnailCache.remove(key);
        }
      }

      thumbnailCache[asset.id] = thumbnail;
    }

    return thumbnail;
  }

  Future<void> loadInitialMediaFast() {
    return _initialMediaLoad ??= _loadInitialMediaFast().whenComplete(() {
      _initialMediaLoad = null;
    });
  }

  Future<void> _loadInitialMediaFast() async {
    try {
      firstPageLoaded.value = false;

      final result = await MediaManger.getAllMedia(page: 0, size: pageSize);

      final loadedIds = <String>{};
      final loadedMedia = <AssetEntity>[];

      for (final asset in result) {
        if (loadedIds.add(asset.id)) {
          loadedMedia.add(asset);
        }
      }

      allMedia.assignAll(loadedMedia);

      currentPage = 0;

      await applyMediaFilter();

      firstPageLoaded.value = true;
    } catch (e) {
      debugPrint("Fast Media Load Error: $e");

      firstPageLoaded.value = true;
    }
  }

  Future<void> loadRemainingMediaInBackground() async {
    if (isLoadingMore) {
      return;
    }

    isLoadingMore = true;

    try {
      int page = currentPage + 1;
      int pagesSinceRefresh = 0;
      bool addedAnything = false;

      final existingIds = allMedia.map((e) => e.id).toSet();

      while (true) {
        final result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        if (result.isEmpty) {
          break;
        }

        final newMedia = <AssetEntity>[];

        for (final asset in result) {
          if (hiddenAssetIds.contains(asset.id)) {
            continue;
          }
          if (existingIds.add(asset.id)) {
            newMedia.add(asset);
          }
        }

        if (newMedia.isNotEmpty) {
          allMedia.addAll(newMedia);
          addedAnything = true;
          pagesSinceRefresh++;
        }

        currentPage = page;

        if (pagesSinceRefresh >= 10) {
          pagesSinceRefresh = 0;
          await applyMediaFilter();
        }

        if (result.length < pageSize) {
          break;
        }

        page++;

        await Future.delayed(const Duration(milliseconds: 120));
      }

      if (addedAnything) {
        await applyMediaFilter();
      }

      debugPrint("ALL MEDIA LOADED (background): ${allMedia.length}");
    } catch (e) {
      debugPrint("Background Media Error: $e");
    } finally {
      isLoadingMore = false;
    }
    unawaited(
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (isClosed) return;
        _indexSmartSearch();
      }),
    );
  }

  Future<void> loadInitialMedia() async {
    try {
      firstPageLoaded.value = false;

      final List<AssetEntity> loadedMedia = [];
      final Set<String> loadedIds = <String>{};

      int page = 0;

      while (true) {
        final result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        if (result.isEmpty) {
          break;
        }

        for (final asset in result) {
          if (loadedIds.add(asset.id)) {
            loadedMedia.add(asset);
          }
        }

        debugPrint("Splash/Startup Page $page : ${result.length}");

        if (result.length < pageSize) {
          break;
        }

        page++;
      }

      allMedia.assignAll(loadedMedia);

      currentPage = page;

      await applyMediaFilter();

      firstPageLoaded.value = true;

      debugPrint("================================");
      debugPrint("ALL MEDIA READY: ${allMedia.length}");
      debugPrint("================================");
    } catch (e, stack) {
      debugPrint("Initial Media Error: $e");
      debugPrint("$stack");

      firstPageLoaded.value = true;
    }
  }

  Future<void> loadRemainingMedia() async {
    if (isLoadingMore) {
      return;
    }

    isLoadingMore = true;

    try {
      int page = 1;

      while (true) {
        final result = await MediaManger.getAllMedia(
          page: page,
          size: pageSize,
        );

        if (result.isEmpty) {
          break;
        }

        final existingIds = allMedia.map((e) => e.id).toSet();

        final newMedia = result
            .where(
              (asset) =>
                  !hiddenAssetIds.contains(asset.id) &&
                  !existingIds.contains(asset.id),
            )
            .toList();
        if (newMedia.isNotEmpty) {
          allMedia.addAll(newMedia);
          filteredMedia.addAll(newMedia);
        }
        log("Background Page $page : ${result.length}");
        log("Total Media: ${allMedia.length}");
        if (result.length < pageSize) {
          break;
        }
        page++;
      }
    } catch (e) {
      log("Background Media Error: $e");
    } finally {
      isLoadingMore = false;
    }
  }

  void filterByDate(DateTime date) {
    selectedDate.value = date;
    applyMediaFilter();
    log(
      "Selected Date: "
      "${date.day}/${date.month}/${date.year}",
    );
    log("Filtered Media: ${filteredMedia.length}");
  }

  bool _watchNewPhotos = false;
  int _newPhotoTries = 0;
  Future<void>? _pullingNewPhotos;

  void watchForNewPhotos() {
    _watchNewPhotos = true;
    _newPhotoTries = 0;
  }

  Future<void> showNewPhotosNow() {
    return _pullingNewPhotos ??= _prependMissingRecent().then((bool added) async {
      if (!added) {
        _refreshAlbumsOnce();
      }
      await _refreshUtilityCounts();
    }).whenComplete(() {
      _pullingNewPhotos = null;
    });
  }

  Future<void> pullNewPhotosIfNeeded() {
    if (!_watchNewPhotos || _newPhotoTries >= 4) {
      return Future<void>.value();
    }
    return _pullingNewPhotos ??= _pullNewPhotos().whenComplete(() {
      _pullingNewPhotos = null;
    });
  }

  Future<void> _pullNewPhotos() async {
    if (!_watchNewPhotos) return;
    _newPhotoTries++;
    final bool added = await _prependMissingRecent();
    if (added) {
      await _refreshUtilityCounts();
    }
    if (added || _newPhotoTries >= 4) {
      _watchNewPhotos = false;
    }
  }

  Future<bool> _prependMissingRecent() async {
    try {
      try {
        await PhotoManager.clearFileCache();
      } catch (_) {}

      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
      );
      if (paths.isEmpty) return false;

      final List<AssetEntity> recent = await paths.first.getAssetListRange(
        start: 0,
        end: 40,
      );
      final Set<String> known = allMedia.map((asset) => asset.id).toSet();
      final List<AssetEntity> fresh = recent
          .where(
            (asset) =>
                !hiddenAssetIds.contains(asset.id) && known.add(asset.id),
          )
          .toList();
      if (fresh.isEmpty) return false;

      allMedia.insertAll(0, fresh);
      await applyMediaFilter();
      _refreshAlbumsOnce();
      return true;
    } catch (e) {
      debugPrint('NEW PHOTO REFRESH ERROR: $e');
      return false;
    }
  }

  void _refreshAlbumsOnce() {
    if (!Get.isRegistered<AlbumsController>()) return;
    Get.find<AlbumsController>().refreshAfterNewPhotos();
  }

  Future<void> _refreshUtilityCounts() {
    if (!Get.isRegistered<ForYouController>()) return Future<void>.value();
    return Get.find<ForYouController>().refreshScreenshotAndVideoCounts();
  }

  Future<void> openCamera() async {
    watchForNewPhotos();
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

  void clearDateFilter() {
    selectedDate.value = null;
    applyMediaFilter();
  }

  List<GroupSection> get groupedMedia {
    final signature =
        "${filteredMedia.length}|"
        "${groupBy.value}|"
        "${groupAscending.value}|"
        "${filteredMedia.isEmpty ? '' : filteredMedia.first.id}|"
        "${filteredMedia.isEmpty ? '' : filteredMedia.last.id}";
    final cached = _groupedCache;
    if (cached != null && _groupedSignature == signature) {
      return cached;
    }
    final computed = _computeGroupedMedia();
    _groupedCache = computed;
    _groupedSignature = signature;
    _rowsCache = null;
    _rowsColumns = -1;
    return computed;
  }

  List<GalleryRow> get galleryRows {
    final int columns = crossAxisCount.value;
    showFileCount.value;
    final sections = groupedMedia;
    final cached = _rowsCache;

    if (cached != null && _rowsColumns == columns) {
      return cached;
    }

    final rows = <GalleryRow>[];

    for (final section in sections) {
      if (section.title.isNotEmpty) {
        rows.add(GalleryRow.header(section.title, section.media.length));
      }

      for (int start = 0; start < section.media.length; start += columns) {
        final end = (start + columns > section.media.length)
            ? section.media.length
            : start + columns;

        rows.add(GalleryRow.media(section.media.sublist(start, end)));
      }
    }

    _rowsCache = rows;
    _rowsColumns = columns;

    return rows;
  }

  List<GroupSection> _computeGroupedMedia() {
    final List<AssetEntity> media = List<AssetEntity>.from(filteredMedia);

    if (media.isEmpty) {
      return [];
    }

    if (groupBy.value == "Do not group files") {
      return [GroupSection(title: "", media: media)];
    }

    final Map<String, List<AssetEntity>> groups = {};

    for (final asset in media) {
      String key;

      switch (groupBy.value) {
        case "Last modified (daily)":
          final date = asset.modifiedDateTime;
          final now = DateTime.now();

          final today = DateTime(now.year, now.month, now.day);

          final yesterday = today.subtract(const Duration(days: 1));

          final assetDate = DateTime(date.year, date.month, date.day);

          if (assetDate == today) {
            key = "Today";
          } else if (assetDate == yesterday) {
            key = "Yesterday";
          } else {
            key =
                "${date.year}-${date.month.toString().padLeft(2, '0')}-"
                "${date.day.toString().padLeft(2, '0')}";
          }

          break;

        case "Last modified (monthly)":
          final date = asset.modifiedDateTime;

          key = "${date.year}-${date.month.toString().padLeft(2, '0')}";
          break;

        case "Date taken (daily)":
          final date = asset.createDateTime;

          key =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-"
              "${date.day.toString().padLeft(2, '0')}";
          break;

        case "Date taken (monthly)":
          final date = asset.createDateTime;

          key = "${date.year}-${date.month.toString().padLeft(2, '0')}";
          break;

        case "File type":
          key = asset.type == AssetType.video ? "Video" : "Image";
          break;

        case "Extension":
          final title = (asset.title ?? "").toLowerCase();

          if (title.contains(".")) {
            key = title.substring(title.lastIndexOf(".") + 1).toUpperCase();
          } else {
            key = "Unknown";
          }
          break;

        case "Folder":
          final path = asset.relativePath ?? "";

          if (path.isEmpty) {
            key = "Unknown";
          } else {
            final parts = path
                .replaceAll("\\", "/")
                .split("/")
                .where((e) => e.trim().isNotEmpty)
                .toList();

            key = parts.isNotEmpty ? parts.last.trim() : "Unknown";
          }
          break;

        default:
          key = "Other";
      }

      groups.putIfAbsent(key, () => []);
      groups[key]!.add(asset);
    }

    final entries = groups.entries.toList();

    if (groupBy.value == "Last modified (daily)" ||
        groupBy.value == "Last modified (monthly)" ||
        groupBy.value == "Date taken (daily)" ||
        groupBy.value == "Date taken (monthly)") {
      entries.sort((a, b) {
        final result = _groupSortDate(a.key).compareTo(_groupSortDate(b.key));

        return groupAscending.value ? result : -result;
      });
    } else {
      entries.sort((a, b) {
        final result = a.key.toLowerCase().compareTo(b.key.toLowerCase());

        return groupAscending.value ? result : -result;
      });
    }

    return entries.map((entry) {
      String title = entry.key;

      if (groupBy.value == "Last modified (daily)" ||
          groupBy.value == "Date taken (daily)") {
        final parts = entry.key.split("-");

        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );

          title = formatGalleryDate(date);
        }
      }

      if (groupBy.value == "Last modified (monthly)" ||
          groupBy.value == "Date taken (monthly)") {
        final parts = entry.key.split("-");

        if (parts.length == 2) {
          const months = [
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
          ];

          final month = int.parse(parts[1]);

          title = "${months[month - 1]} ${parts[0]}";
        }
      }

      return GroupSection(title: title, media: entry.value);
    }).toList();
  }

  DateTime _groupSortDate(String key) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (key == "Today") return today;
    if (key == "Yesterday") {
      return today.subtract(const Duration(days: 1));
    }
    final List<String> parts = key.split("-");
    if (parts.length >= 3) {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    if (parts.length == 2) {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  final Set<String> hiddenAssetIds = <String>{};

  void removeAsset(AssetEntity asset) {
    hiddenAssetIds.add(asset.id);
    thumbnailCache.remove(asset.id);
    allMedia.removeWhere((element) => element.id == asset.id);
    filteredMedia.removeWhere((element) => element.id == asset.id);
    allMedia.refresh();
    filteredMedia.refresh();
  }

  Future<bool> toggleFavorite(AssetEntity asset) async {
    try {
      final newValue = !asset.isFavorite;

      final result = await PhotoManager.plugin.favoriteAsset(
        asset.id,
        newValue,
      );
      if (result) {
        final updatedAsset = asset.copyWith(isFavorite: newValue);
        final allIndex = allMedia.indexWhere(
          (element) => element.id == asset.id,
        );
        if (allIndex != -1) {
          allMedia[allIndex] = updatedAsset;
        }
        final filteredIndex = filteredMedia.indexWhere(
          (element) => element.id == asset.id,
        );
        if (filteredIndex != -1) {
          filteredMedia[filteredIndex] = updatedAsset;
        }
        allMedia.refresh();
        filteredMedia.refresh();
        return true;
      }
      return false;
    } catch (e) {
      log("Favorite Error: $e");
      return false;
    }
  }

  static Future<void> deleteEmptyParentFolder(Directory directory) async {
    final enabled = GetStorageData.readBoolean(
      GetStorageData.deleteEmptyFolders,
      defaultValue: true,
    );
    if (!enabled) {
      return;
    }
    try {
      if (!await directory.exists()) {
        return;
      }
      final entities = await directory.list(followLinks: false).toList();
      if (entities.isEmpty) {
        await directory.delete();
      }
    } catch (e) {
      debugPrint("Delete Empty Folder Error: $e");
    }
  }

  Future<bool> deleteAsset(AssetEntity asset) async {
    try {
      String? parentFolderPath;

      final file = await asset.file;

      if (file != null) {
        parentFolderPath = file.parent.path;
      }

      final deletedIds = await MediaActionService.deleteIds([asset.id]);

      if (deletedIds.contains(asset.id)) {
        removeAsset(asset);

        if (parentFolderPath != null) {
          await FileOperationService.deleteEmptyParentFolder(
            Directory(parentFolderPath),
          );
        }

        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Delete Error: $e");

      return false;
    }
  }

  Future<void> deleteSelectedPhotos() async {
    final List<AssetEntity> selectedAssets = allMedia
        .where((asset) => selectedMediaIds.contains(asset.id))
        .toList();

    if (selectedAssets.isEmpty) {
      return;
    }

    final String? action = await Get.dialog<String>(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

        for (final asset in selectedAssets) {
          try {
            final bool saved = await recycleController.addToRecycleBin(asset);

            if (!saved) {
              debugPrint("Recycle Bin save failed => ${asset.id}");
              continue;
            }

            final List<String> result = await MediaActionService.deleteIds(
              [asset.id],
            );

            if (result.contains(asset.id)) {
              deletedIds.add(asset.id);

              final file = await asset.file;

              if (file != null) {
                await FileOperationService.deleteEmptyParentFolder(file.parent);
              }
            }
          } catch (e) {
            debugPrint("Recycle delete error ${asset.id} => $e");
          }
        }

        if (deletedIds.isNotEmpty) {
          allMedia.removeWhere((asset) => deletedIds.contains(asset.id));

          filteredMedia.removeWhere((asset) => deletedIds.contains(asset.id));

          for (final id in deletedIds) {
            thumbnailCache.remove(id);
          }

          allMedia.refresh();
          filteredMedia.refresh();
        }

        clearPhotoSelection();

        AppToast.show(
          "${deletedIds.length} item"
            "${deletedIds.length == 1 ? "" : "s"} moved to Recycle Bin",
        );

        return;
      }

if (action == "permanent") {
        final List<String> ids = selectedAssets
            .map((asset) => asset.id)
            .toList();

        final List<String> result = await MediaActionService.deleteIds(
          ids,
        );

        deletedIds.addAll(result);

        if (deletedIds.isNotEmpty) {
          for (final asset in selectedAssets) {
            if (!deletedIds.contains(asset.id)) {
              continue;
            }

            final file = await asset.file;

            if (file != null) {
              await FileOperationService.deleteEmptyParentFolder(file.parent);
            }
          }

          allMedia.removeWhere((asset) => deletedIds.contains(asset.id));

          filteredMedia.removeWhere((asset) => deletedIds.contains(asset.id));

          for (final id in deletedIds) {
            thumbnailCache.remove(id);
          }

          allMedia.refresh();
          filteredMedia.refresh();
        }

        clearPhotoSelection();

        AppToast.show(
          "${deletedIds.length} item"
            "${deletedIds.length == 1 ? "" : "s"} deleted permanently",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("Delete Selected Photos Error => $e");
      debugPrintStack(stackTrace: stackTrace);

      AppToast.show("Unable to delete selected files");
    }
  }

  Future<void> applyMediaFilter() async {
    final result = allMedia.where((asset) {
      if (hiddenAssetIds.contains(asset.id)) {
        return false;
      }
      final title = (asset.title ?? '').toLowerCase();
      final mime = (asset.mimeType ?? '').toLowerCase();

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

        if (filterPortraits.value && _isPortrait(asset)) {
          return true;
        }

        return filterImages.value;
      }

      return false;
    }).toList();

    List<AssetEntity> filtered = result;

    if (selectedDate.value != null) {
      final date = selectedDate.value!;

      filtered = result.where((asset) {
        final assetDate = asset.createDateTime;

        return assetDate.year == date.year &&
            assetDate.month == date.month &&
            assetDate.day == date.day;
      }).toList();
    }

    await _sortList(filtered);

    filteredMedia.assignAll(filtered);
  }

  Future<void> _sortList(List<AssetEntity> list) async {
    switch (sortBy.value) {
      case "File Name":
        list.sort((a, b) {
          final aName = (a.title ?? "").toLowerCase();
          final bName = (b.title ?? "").toLowerCase();

          final result = aName.compareTo(bName);

          return sortAscending.value ? result : -result;
        });
        break;

      case "File Path":
        list.sort((a, b) {
          final aPath = (a.relativePath ?? "").toLowerCase();
          final bPath = (b.relativePath ?? "").toLowerCase();

          final result = aPath.compareTo(bPath);

          return sortAscending.value ? result : -result;
        });
        break;

      case "File Size":
        final sizes = <String, int>{};

        await Future.wait(
          list.map((asset) async {
            sizes[asset.id] = await asset.fileSize;
          }),
        );

        list.sort((a, b) {
          final aSize = sizes[a.id] ?? 0;
          final bSize = sizes[b.id] ?? 0;

          final result = aSize.compareTo(bSize);

          return sortAscending.value ? result : -result;
        });
        break;

      case "Last modified":
        list.sort((a, b) {
          // int seconds: same order as modifiedDateTime, no DateTime objects
          final result = (a.modifiedDateSecond ?? 0).compareTo(
            b.modifiedDateSecond ?? 0,
          );

          return sortAscending.value ? result : -result;
        });
        break;

      case "Date taken":
        list.sort((a, b) {
          // int seconds: same order as createDateTime, no DateTime objects
          final result = (a.createDateSecond ?? 0).compareTo(
            b.createDateSecond ?? 0,
          );

          return sortAscending.value ? result : -result;
        });
        break;
    }
  }

  bool _isPortrait(AssetEntity asset) {
    return false;
  }

  Future<void> applySort({
    required String sortType,
    required bool ascending,
  }) async {
    sortBy.value = sortType;
    sortAscending.value = ascending;

    await applyMediaFilter();
  }

  void addEditedAsset(AssetEntity asset) {
    allMedia.removeWhere((element) => element.id == asset.id);

    filteredMedia.removeWhere((element) => element.id == asset.id);

    allMedia.insert(0, asset);

    if (selectedDate.value == null) {
      filteredMedia.insert(0, asset);
    } else {
      final selected = selectedDate.value!;
      final date = asset.createDateTime;

      if (date.year == selected.year &&
          date.month == selected.month &&
          date.day == selected.day) {
        filteredMedia.insert(0, asset);
      }
    }

    allMedia.refresh();
    filteredMedia.refresh();

    log("Edited Asset Added: ${asset.id}");
  }

  void replaceAsset(AssetEntity original, AssetEntity edited) {
    allMedia.removeWhere((element) => element.id == original.id);

    filteredMedia.removeWhere((element) => element.id == original.id);

    allMedia.removeWhere((element) => element.id == edited.id);

    filteredMedia.removeWhere((element) => element.id == edited.id);

    allMedia.insert(0, edited);

    if (selectedDate.value == null) {
      filteredMedia.insert(0, edited);
    } else {
      final selected = selectedDate.value!;
      final date = edited.createDateTime;

      if (date.year == selected.year &&
          date.month == selected.month &&
          date.day == selected.day) {
        filteredMedia.insert(0, edited);
      }
    }

    allMedia.refresh();
    filteredMedia.refresh();

    log("Original replaced: ${original.id}");

    log("Edited asset: ${edited.id}");
  }
}

class GroupSection {
  final String title;
  final List<AssetEntity> media;

  GroupSection({required this.title, required this.media});
}

class GalleryRow {
  final bool isHeader;
  final String title;
  final int count;
  final List<AssetEntity> media;

  const GalleryRow.header(this.title, this.count)
    : isHeader = true,
      media = const [];

  const GalleryRow.media(this.media) : isHeader = false, title = '', count = 0;
}
