import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/MediaManager.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/Albums/AlbumsScreen.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotosController extends GetxController {
  final RxList<AssetEntity> allMedia = <AssetEntity>[].obs;
  final RxList<AssetEntity> filteredMedia = <AssetEntity>[].obs;
  final Rxn<DateTime> selectedDate = Rxn<DateTime>();
  final RxBool firstPageLoaded = false.obs;
  final RxInt crossAxisCount = 3.obs;
  int _startCrossAxisCount = 3;
  double _lastScale = 1.0;
  bool isLoadingMore = false;
  int currentPage = 0;
  static const int pageSize = 100;
  final ImagePicker _picker = ImagePicker();
  final RxBool filterImages = true.obs;
  final RxBool filterVideos = true.obs;
  final RxBool filterGifs = true.obs;
  final RxBool filterRawImages = true.obs;
  final RxBool filterSvgs = true.obs;
  final RxBool filterPortraits = false.obs;
  final RxString sortBy = "Last modified".obs;
  final RxBool sortAscending = false.obs;
  final Map<String, Uint8List> thumbnailCache = {};
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
  @override
  void onInit() {
    super.onInit();

    // loadInitialMedia();
    loadSavedGridColumns();
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

      await applyMediaFilter();

      firstPageLoaded.value = true;

      print("MEDIA REFRESHED ONCE: ${allMedia.length}");
    } catch (e) {
      print("Refresh Media Error: $e");
    } finally {
      isLoadingMore = false;
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

  // Future<void> loadInitialMedia() async {
  //   try {
  //     final result = await MediaManger.getAllMedia(
  //       page: 0,
  //       size: pageSize,
  //     );
  //
  //     if (result.isNotEmpty) {
  //       allMedia.assignAll(result);
  //       applyMediaFilter();
  //
  //       currentPage = 0;
  //     }
  //
  //     firstPageLoaded.value = true;
  //
  //     print(
  //       "Initial Media Loaded: ${result.length}",
  //     );
  //
  //     unawaited(
  //       loadRemainingMedia(),
  //     );
  //   } catch (e) {
  //     print(
  //       "Initial Media Error: $e",
  //     );
  //
  //     firstPageLoaded.value = true;
  //   }
  // }


  Future<Uint8List?> getThumbnail(AssetEntity asset) async {
    final cachedThumbnail = thumbnailCache[asset.id];

    if (cachedThumbnail != null) {
      return cachedThumbnail;
    }

    final thumbnail = await asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
    );

    if (thumbnail != null) {
      thumbnailCache[asset.id] = thumbnail;
    }

    return thumbnail;
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

      // Complete gallery data ek hi baar assign hoga.
      allMedia.assignAll(loadedMedia);

      currentPage = page;

      // Filter + sort sirf ek baar.
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
            .where((asset) => !existingIds.contains(asset.id))
            .toList();

        // if (newMedia.isNotEmpty) {
        //   allMedia.addAll(newMedia);
        //
        //   if (selectedDate.value == null) {
        //     filteredMedia.addAll(newMedia);
        //   } else {
        //     final selected = selectedDate.value!;
        //
        //     final filtered = newMedia.where((asset) {
        //       final date = asset.createDateTime;
        //
        //       return date.year == selected.year &&
        //           date.month == selected.month &&
        //           date.day == selected.day;
        //     }).toList();
        //
        //     if (filtered.isNotEmpty) {
        //       filteredMedia.addAll(filtered);
        //     }
        //   }
        // }
        if (newMedia.isNotEmpty) {
          allMedia.addAll(newMedia);

          filteredMedia.addAll(newMedia);
        }
        print("Background Page $page : ${result.length}");

        print("Total Media: ${allMedia.length}");

        if (result.length < pageSize) {
          break;
        }

        page++;
      }

      print("================================");

      print("ALL MEDIA LOADED: ${allMedia.length}");

      print("================================");
    } catch (e) {
      print("Background Media Error: $e");
    } finally {
      isLoadingMore = false;
    }
  }

  void filterByDate(DateTime date) {
    selectedDate.value = date;
    applyMediaFilter();
    print(
      "Selected Date: "
      "${date.day}/${date.month}/${date.year}",
    );
    print("Filtered Media: ${filteredMedia.length}");
  }

  Future<void> openCamera() async {
    try {
      await const MethodChannel('native_camera').invokeMethod('openCamera');
    } on PlatformException catch (e) {
      debugPrint("Native Camera Error => ${e.code} : ${e.message}");

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

  void clearDateFilter() {
    selectedDate.value = null;
    applyMediaFilter();
  }

  List<GroupSection> get groupedMedia {
    final List<AssetEntity> media = List<AssetEntity>.from(filteredMedia);

    if (media.isEmpty) {
      return [];
    }

    // Do not group files
    if (groupBy.value == "Do not group files") {
      return [GroupSection(title: "", media: media)];
    }

    final Map<String, List<AssetEntity>> groups = {};

    for (final asset in media) {
      String key;

      switch (groupBy.value) {
        case "Last modified (daily)":
          final date = asset.modifiedDateTime;

          key =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-"
              "${date.day.toString().padLeft(2, '0')}";
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
        final result = a.key.compareTo(b.key);

        return groupAscending.value ? result : -result;
      });
    } else {
      // File type / Extension / Folder
      entries.sort((a, b) {
        final result = a.key.toLowerCase().compareTo(b.key.toLowerCase());

        return groupAscending.value ? result : -result;
      });
    }

    return entries.map((entry) {
      String title = entry.key;

      // Date title formatting
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

  void removeAsset(AssetEntity asset) {
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
      print("Favorite Error: $e");

      return false;
    }
  }

  Future<bool> deleteAsset(AssetEntity asset) async {
    try {
      final deletedIds = await PhotoManager.editor.deleteWithIds([asset.id]);

      if (deletedIds.contains(asset.id)) {
        removeAsset(asset);
        return true;
      }

      return false;
    } catch (e) {
      print("Delete Error: $e");

      return false;
    }
  }

  Future<void> applyMediaFilter() async {
    final result = allMedia.where((asset) {
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

    // Date filter
    if (selectedDate.value != null) {
      final date = selectedDate.value!;

      filtered = result.where((asset) {
        final assetDate = asset.createDateTime;

        return assetDate.year == date.year &&
            assetDate.month == date.month &&
            assetDate.day == date.day;
      }).toList();
    }

    // Current selected sorting bhi maintain rahegi
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
          final result = a.modifiedDateTime.compareTo(b.modifiedDateTime);

          return sortAscending.value ? result : -result;
        });
        break;

      case "Date taken":
        list.sort((a, b) {
          final result = a.createDateTime.compareTo(b.createDateTime);

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

    print("Edited Asset Added: ${asset.id}");
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

    print("Original replaced: ${original.id}");

    print("Edited asset: ${edited.id}");
  }
}

class GroupSection {
  final String title;
  final List<AssetEntity> media;

  GroupSection({required this.title, required this.media});
}
