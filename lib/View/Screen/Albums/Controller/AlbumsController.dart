import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/MediaManager.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

class AlbumsController extends GetxController {
  final RxList<AssetPathEntity> albums = <AssetPathEntity>[].obs;
  final RxMap<String, AssetEntity> albumCovers = <String, AssetEntity>{}.obs;
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
  @override
  void onInit() {
    super.onInit();
    loadAlbums();
    loadSavedAlbumGrid();
    loadCustomAlbums();
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
      GetStorageData.photosGridColumns,
    );
    if (savedColumns != null) {
      final int? columns = int.tryParse(savedColumns.toString());
      if (columns != null) {
        albumCrossAxisCount.value = columns.clamp(2, 6);
        _startAlbumCrossAxisCount = albumCrossAxisCount.value;
      }
    }
  }

  Future<void> loadAlbums() async {
    isLoading.value = true;

    try {
      final List<AssetPathEntity> result = await MediaManger.getAlbums();

      albums.assignAll(result);
      albumCovers.clear();

      for (final album in result) {
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

            debugPrint("COVER => ${album.name} : ${assets.first.id}");
          }
        } catch (e) {
          debugPrint("Cover Error ${album.name}: $e");
        }
      }
    } catch (e) {
      debugPrint("Album Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void onAlbumScaleStart() {
    _startAlbumCrossAxisCount = albumCrossAxisCount.value;
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
        GetStorageData.photosGridColumns,
        newCount.toString(),
      );
    }
  }

  Future<void> openCamera() async {
    try {
      await const MethodChannel('native_camera')
          .invokeMethod('openCamera');
    } on PlatformException catch (e) {
      debugPrint(
        "Native Camera Error => ${e.code} : ${e.message}",
      );

      Get.snackbar(
        "Camera Error",
        e.message ?? "Unable to open camera",
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint("Camera Error => $e");

      Get.snackbar(
        "Camera Error",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
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
        Get.snackbar(
          "Import Failed",
          "Please select at least one photo or video",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // ---------------------------------------------------------
      // EXISTING CUSTOM ALBUMS LOAD
      // ---------------------------------------------------------

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

      // ---------------------------------------------------------
      // SAME ALBUM NAME CHECK
      // ---------------------------------------------------------

      final existingKey = customAlbums.keys.firstWhere(
        (key) => key.toLowerCase().trim() == albumName.toLowerCase().trim(),
        orElse: () => "",
      );

      if (existingKey.isNotEmpty) {
        Get.snackbar(
          "Album already exists",
          "Please use another album name",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // ---------------------------------------------------------
      // SAVE CUSTOM ALBUM
      // ---------------------------------------------------------

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

      // Clear selection
      selectedAlbumMediaIds.clear();
      selectedAlbumMediaIds.refresh();

      // Close selection screen
      Get.back();

      Get.snackbar(
        "Success",
        "$albumName created with ${selectedIds.length} items",
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint("CREATE ALBUM ERROR => $e");

      Get.snackbar(
        "Import Failed",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
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
        Get.snackbar(
          "Delete Album",
          "Normal gallery albums cannot be deleted from this app.",
          snackPosition: SnackPosition.BOTTOM,
        );

        clearAlbumSelection();
        return;
      }

      // Existing custom albums read karo
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

      // Selected custom albums remove
      for (final albumName in customKeysToDelete) {
        data.remove(albumName);
      }

      // Storage update
      await GetStorageData.saveString(
        GetStorageData.customAlbums,
        jsonEncode(data),
      );

      // UI map update
      customAlbums.clear();
      customAlbums.assignAll(data);

      selectedAlbumIds.clear();
      isAlbumSelectionMode.value = false;
      selectedAlbumIds.refresh();
      customAlbums.refresh();

      Get.snackbar(
        "Delete Album",
        "${customKeysToDelete.length} album deleted",
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint("Delete Selected Albums Error => $e");

      Get.snackbar(
        "Delete Album",
        "Unable to delete album",
        snackPosition: SnackPosition.BOTTOM,
      );
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
          final result = a.name
              .toLowerCase()
              .compareTo(b.name.toLowerCase());

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
          final result =
          (counts[a.id] ?? 0).compareTo(counts[b.id] ?? 0);

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
                final assets = await album.getAssetListRange(
                  start: 0,
                  end: 1,
                );

                if (assets.isNotEmpty) {
                  dates[album.id] = assets.first.modifiedDateTime;
                }
              }
            } catch (_) {}
          }),
        );

        normalList.sort((a, b) {
          final aDate = dates[a.id] ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = dates[b.id] ??
              DateTime.fromMillisecondsSinceEpoch(0);

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
                final assets = await album.getAssetListRange(
                  start: 0,
                  end: 1,
                );

                if (assets.isNotEmpty) {
                  dates[album.id] = assets.first.createDateTime;
                }
              }
            } catch (_) {}
          }),
        );

        normalList.sort((a, b) {
          final aDate = dates[a.id] ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = dates[b.id] ??
              DateTime.fromMillisecondsSinceEpoch(0);

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
  bool _albumsLoaded = false;
  final RxInt crossAxisCount = 3.obs;
  int _startCrossAxisCount = 3;
  @override
  void onInit() {
    super.onInit();
    loadAlbumMedia();
  }

  // =========================================================
  // PINCH START
  // =========================================================

  void onGridScaleStart() {
    _startCrossAxisCount = crossAxisCount.value;
  }

  // =========================================================
  // PINCH UPDATE
  // =========================================================

  void onGridScaleUpdate(double scale) {
    int newCrossAxisCount = _startCrossAxisCount;

    // ---------------------------------------------------------
    // FINGERS PAAS -> PHOTOS SMALL -> COLUMNS INCREASE
    // ---------------------------------------------------------

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

      debugPrint(
        "ALBUM MEDIA => ${album.name} | FOUND => ${assets.length}",
      );

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
}
