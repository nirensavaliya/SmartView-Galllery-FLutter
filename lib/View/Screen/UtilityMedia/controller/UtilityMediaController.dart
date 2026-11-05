import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotoViewController.dart';
import 'package:gallery_photos/View/Screen/UtilityMedia/FavoriteImportScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/Common/MediaActionService.dart';

enum UtilityMediaType { videos, screenshots, favorites, gifs }

class UtilityMediaController extends GetxController {
  final UtilityMediaType mediaType;

  UtilityMediaController(this.mediaType);
  final RxList<AssetEntity> media = <AssetEntity>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxInt gridColumns = 3.obs;
  final RxBool selectionMode = false.obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  AssetPathEntity? _allPath;
  int _page = 0;
  static const int _pageSize = 100;
  bool _hasMore = true;
  final RxBool isListView = false.obs;

  final RxString sortBy = 'Last modified'.obs;
  final RxBool sortAscending = false.obs;
  final RxString groupBy = 'Last modified (daily)'.obs;
  final RxBool groupAscending = false.obs;

  void toggleViewMode() {
    isListView.value = !isListView.value;
  }

  void changeGridColumns(int columns) {
    gridColumns.value = columns;
  }

  void changeSort(String value) {
    if (sortBy.value == value) {
      sortAscending.value = !sortAscending.value;
    } else {
      sortBy.value = value;
      sortAscending.value = false;
    }

    _sortMedia();
  }

  final Map<String, Future<Uint8List?>> _thumbnailCache = {};

  Future<Uint8List?> getThumbnail(AssetEntity asset, {int size = 500}) {
    return _thumbnailCache.putIfAbsent(
      '${asset.id}_$size',
      () => asset.thumbnailDataWithSize(ThumbnailSize(size, size)),
    );
  }

  void changeGroup(String value) {
    if (groupBy.value == value) {
      groupAscending.value = !groupAscending.value;
    } else {
      groupBy.value = value;
      groupAscending.value = false;
    }

    _groupMedia();
  }

  @override
  void onInit() {
    super.onInit();

    loadMedia();
  }

  String get title {
    switch (mediaType) {
      case UtilityMediaType.videos:
        return 'Videos';

      case UtilityMediaType.screenshots:
        return 'Screenshots';

      case UtilityMediaType.favorites:
        return 'Favorites';

      case UtilityMediaType.gifs:
        return 'GIFs & Live Photos';
    }
  }

  Future<void> loadMedia() async {
    if (isLoading.value) {
    } else {
      isLoading.value = true;
    }

    try {
      media.clear();
      selectedIds.clear();
      selectionMode.value = false;

      _page = 0;
      _hasMore = true;

      PhotoManager.setIgnorePermissionCheck(true);

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (albums.isEmpty) {
        _allPath = null;
        return;
      }

      _allPath = albums.first;

      await _loadNextPage();
    } catch (e) {
      debugPrint('UTILITY MEDIA ERROR: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _sortMedia() {
    final list = media.toList();

    list.sort((a, b) {
      int result = 0;

      switch (sortBy.value) {
        case 'Name':
          result = (a.title ?? '').toLowerCase().compareTo(
            (b.title ?? '').toLowerCase(),
          );
          break;

        case 'Date taken':
          final aDate = a.createDateTime;
          final bDate = b.createDateTime;

          result = aDate.compareTo(bDate);
          break;

        case 'Last modified':
        default:
          final aDate = a.modifiedDateTime;
          final bDate = b.modifiedDateTime;

          result = aDate.compareTo(bDate);
          break;
      }

      return sortAscending.value ? result : -result;
    });

    media.assignAll(list);
  }

  void _groupMedia() {
    media.refresh();
  }

  Future<void> _loadNextPage() async {
    if (_allPath == null || !_hasMore || isLoadingMore.value) {
      return;
    }

    isLoadingMore.value = true;

    try {
      final assets = await _allPath!.getAssetListPaged(
        page: _page,
        size: _pageSize,
      );

      if (assets.isEmpty) {
        _hasMore = false;
        return;
      }

      final filtered = <AssetEntity>[];

      for (final asset in assets) {
        if (_matchesType(asset)) {
          filtered.add(asset);
        }
      }

      final existingIds = media.map((e) => e.id).toSet();

      for (final asset in filtered) {
        if (!existingIds.contains(asset.id)) {
          media.add(asset);
        }
      }

      _page++;

      if (assets.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('LOAD NEXT PAGE ERROR: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  bool _matchesType(AssetEntity asset) {
    switch (mediaType) {
      case UtilityMediaType.videos:
        return asset.type == AssetType.video;

      case UtilityMediaType.screenshots:
        final title = asset.title?.toLowerCase() ?? '';
        final relativePath = asset.relativePath?.toLowerCase() ?? '';

        return title.contains('screenshot') ||
            title.contains('screen_shot') ||
            title.contains('screen-shot') ||
            relativePath.contains('screenshot') ||
            relativePath.contains('screen_shot') ||
            relativePath.contains('screen-shot');

      case UtilityMediaType.favorites:
        return asset.isFavorite;

      case UtilityMediaType.gifs:
        final mimeType = asset.mimeType?.toLowerCase() ?? '';

        final title = asset.title?.toLowerCase() ?? '';

        final isGif = mimeType == 'image/gif' || title.endsWith('.gif');

        final isLivePhoto = asset.isLivePhoto;

        return isGif || isLivePhoto;
    }
  }

  Future<void> loadMoreIfNeeded(int index) async {
    if (index >= media.length - 15) {
      await _loadNextPage();
    }
  }

  Future<void> showSortDialog() async {
    final RxString selectedSort = sortBy.value.obs;
    final RxBool selectedOrder = sortAscending.value.obs;

    await Get.dialog(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Sort by",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _sortRow(title: "File Name", selectedSort: selectedSort),

              _sortRow(title: "File Path", selectedSort: selectedSort),

              _sortRow(title: "File Size", selectedSort: selectedSort),

              _sortRow(title: "Last modified", selectedSort: selectedSort),

              _sortRow(title: "Date taken", selectedSort: selectedSort),

              const Divider(height: 18),

              _orderRow(
                title: "Ascending",
                value: true,
                selectedOrder: selectedOrder,
              ),

              _orderRow(
                title: "Descending",
                value: false,
                selectedOrder: selectedOrder,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: InnerChrome.dialogSecondaryBg,
                          foregroundColor: InnerChrome.dialogSecondaryFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          sortBy.value = selectedSort.value;
                          sortAscending.value = selectedOrder.value;

                          _sortMedia();

                          Get.back();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: InnerChrome.dialogPrimaryBg,
                          foregroundColor: InnerChrome.dialogPrimaryFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text("OK", style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortRow({required String title, required RxString selectedSort}) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedSort.value = title;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: FontFamily.robotoRegular,
                      color: AppColors.fg(const Color(0xff333333)),
                    ),
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                selectedSort.value = title;
              },
              child: Icon(
                selectedSort.value == title
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedSort.value == title
                    ? AppColors.fg(const Color(0xff444444))
                    : AppColors.fg(const Color(0xffAAAAAA)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderRow({
    required String title,
    required bool value,
    required RxBool selectedOrder,
  }) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedOrder.value = value;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: FontFamily.robotoRegular,
                      color: AppColors.fg(const Color(0xff333333)),
                    ),
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                selectedOrder.value = value;
              },
              child: Icon(
                selectedOrder.value == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedOrder.value == value
                    ? AppColors.fg(const Color(0xff444444))
                    : AppColors.fg(const Color(0xffAAAAAA)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showGroupDialog() async {
    final RxString selectedGroup = groupBy.value.obs;
    final RxBool selectedOrder = groupAscending.value.obs;

    await Get.dialog(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Group by",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _groupRow(
                title: "Last modified (daily)",
                selectedGroup: selectedGroup,
              ),

              _groupRow(title: "Date taken", selectedGroup: selectedGroup),

              const Divider(height: 18),

              _orderRow(
                title: "Ascending",
                value: true,
                selectedOrder: selectedOrder,
              ),

              _orderRow(
                title: "Descending",
                value: false,
                selectedOrder: selectedOrder,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: InnerChrome.dialogSecondaryBg,
                          foregroundColor: InnerChrome.dialogSecondaryFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          groupBy.value = selectedGroup.value;
                          groupAscending.value = selectedOrder.value;

                          _groupMedia();

                          Get.back();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: InnerChrome.dialogPrimaryBg,
                          foregroundColor: InnerChrome.dialogPrimaryFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text("OK", style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupRow({required String title, required RxString selectedGroup}) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedGroup.value = title;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: FontFamily.robotoRegular,
                      color: AppColors.fg(const Color(0xff333333)),
                    ),
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                selectedGroup.value = title;
              },
              child: Icon(
                selectedGroup.value == title
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedGroup.value == title
                    ? AppColors.fg(const Color(0xff444444))
                    : AppColors.fg(const Color(0xffAAAAAA)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showColumnsDialog() async {
    final RxInt selectedColumns = gridColumns.value.obs;

    await Get.dialog(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Columns",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              _columnRow(
                title: "2 Grid",
                value: 2,
                selectedColumns: selectedColumns,
              ),

              _columnRow(
                title: "3 Grid",
                value: 3,
                selectedColumns: selectedColumns,
              ),

              _columnRow(
                title: "4 Grid",
                value: 4,
                selectedColumns: selectedColumns,
              ),

              _columnRow(
                title: "5 Grid",
                value: 5,
                selectedColumns: selectedColumns,
              ),

              _columnRow(
                title: "6 Grid",
                value: 6,
                selectedColumns: selectedColumns,
              ),

              _columnRow(
                title: "7 Grid",
                value: 7,
                selectedColumns: selectedColumns,
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () {
                    gridColumns.value = selectedColumns.value;

                    Get.back();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: InnerChrome.dialogPrimaryBg,
                    foregroundColor: InnerChrome.dialogPrimaryFg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text("OK", style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _columnRow({
    required String title,
    required int value,
    required RxInt selectedColumns,
  }) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedColumns.value = value;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: FontFamily.robotoRegular,
                      color: AppColors.fg(const Color(0xff333333)),
                    ),
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                selectedColumns.value = value;
              },
              child: Icon(
                selectedColumns.value == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedColumns.value == value
                    ? AppColors.fg(const Color(0xff444444))
                    : AppColors.fg(const Color(0xffAAAAAA)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> refreshMedia() async {
    await loadMedia();
  }

  void zoomIn() {
    if (gridColumns.value > 2) {
      gridColumns.value--;
    }
  }

  void zoomOut() {
    if (gridColumns.value < 7) {
      gridColumns.value++;
    }
  }

  void setGridColumns(int value) {
    gridColumns.value = value.clamp(2, 7);
  }

  double _lastScale = 1.0;

  void onScaleStart(double scale) {
    _lastScale = scale;
  }

  void onScaleUpdate(double scale) {
    final difference = scale - _lastScale;

    if (difference.abs() < 0.08) {
      return;
    }

    if (difference > 0) {
      zoomIn();
    } else {
      zoomOut();
    }

    _lastScale = scale;
  }

  void toggleSelection(AssetEntity asset) {
    if (selectedIds.contains(asset.id)) {
      selectedIds.remove(asset.id);
    } else {
      selectedIds.add(asset.id);
    }

    selectionMode.value = selectedIds.isNotEmpty;
  }

  void selectAll() {
    selectedIds.clear();

    for (final asset in media) {
      selectedIds.add(asset.id);
    }

    selectionMode.value = selectedIds.isNotEmpty;
  }

  void clearSelection() {
    selectedIds.clear();
    selectionMode.value = false;
  }

  bool isSelected(AssetEntity asset) {
    return selectedIds.contains(asset.id);
  }

  List<AssetEntity> get selectedAssets {
    return media.where((asset) => selectedIds.contains(asset.id)).toList();
  }

  PhotoViewController? _getSelectedPhotoController() {
    final AssetEntity? selectedAsset = selectedAssets.isEmpty
        ? null
        : selectedAssets.first;

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

  Future<void> shareSelected() async {
    final assets = selectedAssets;

    if (assets.isEmpty) {
      return;
    }

    final files = <XFile>[];

    for (final asset in assets) {
      final file = await asset.file;

      if (file != null) {
        files.add(XFile(file.path));
      }
    }

    if (files.isEmpty) {
      return;
    }

    await Share.shareXFiles(files, text: 'Shared from Gallery');
  }

  Future<void> deleteSelected() async {
    final assets = selectedAssets;

    if (assets.isEmpty) {
      return;
    }

    final confirmed = await Get.dialog<bool>(
      ChromeDialog(
        title: 'Delete',
        message:
            'Delete ${assets.length} item${assets.length == 1 ? '' : 's'}?',
        actions: [
          ChromeButton.cancel(onPressed: () => Get.back(result: false)),
          ChromeButton.danger(
            label: 'Delete',
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final ids = assets.map((e) => e.id).toList();

      final deletedIds = await MediaActionService.deleteIds(ids);

      if (deletedIds.isNotEmpty) {
        media.removeWhere((asset) => deletedIds.contains(asset.id));

        clearSelection();

        AppToast.show('${deletedIds.length} item(s) deleted');
      }
    } catch (e) {
      debugPrint('DELETE ERROR: $e');

      AppToast.show("Delete failed: ${e.toString()}");
    }
  }

  Future<void> toggleFavoriteSelected() async {
    final assets = selectedAssets;

    if (assets.isEmpty) {
      return;
    }

    try {
      for (final asset in assets) {
        final bool newFavoriteStatus = !asset.isFavorite;

        if (Platform.isIOS || Platform.isMacOS) {
          await PhotoManager.editor.darwin.favoriteAsset(
            entity: asset,
            favorite: newFavoriteStatus,
          );
        } else {
          final result = await PhotoManager.plugin.favoriteAsset(
            asset.id,
            !asset.isFavorite,
          );
        }
      }
      if (mediaType == UtilityMediaType.favorites) {
        media.removeWhere((asset) => selectedIds.contains(asset.id));
      }

      clearSelection();

      await refreshMedia();

      AppToast.show('Favorite updated successfully');
    } catch (e, stackTrace) {
      debugPrint('FAVORITE ERROR: $e');
      debugPrint('STACKTRACE: $stackTrace');

      AppToast.show("Favorite Error: ${e.toString()}");
    }
  }

  Future<void> showMoreMenu(AssetEntity asset) async {
    final isDark =
        Get.context != null &&
        Theme.of(Get.context!).brightness == Brightness.dark;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff181818) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),

              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 15),

              _MoreItem(
                icon: Icons.copy_rounded,
                title: 'Copy to',
                isDark: isDark,
                onTap: () async {
                  Get.back();

                  final controller = _getSelectedPhotoController();

                  if (controller == null) {
                    return;
                  }

                  await controller.copyPhoto();
                },
              ),

              _MoreItem(
                icon: Icons.drive_file_move_rounded,
                title: 'Move to',
                isDark: isDark,
                onTap: () async {
                  Get.back();

                  final controller = _getSelectedPhotoController();

                  if (controller == null) {
                    return;
                  }

                  await controller.movePhoto();
                },
              ),

              _MoreItem(
                icon: Icons.drive_file_rename_outline,
                title: 'Rename',
                isDark: isDark,
                onTap: () async {
                  Get.back();

                  final controller = _getSelectedPhotoController();

                  if (controller == null) {
                    return;
                  }

                  await controller.renamePhoto();
                },
              ),

              _MoreItem(
                icon: Icons.auto_fix_high_outlined,
                title: 'Edit',
                isDark: isDark,
                onTap: () async {
                  Get.back();

                  final controller = _getSelectedPhotoController();

                  if (controller == null) {
                    return;
                  }

                  await controller.editPhoto();
                },
              ),

              _MoreItem(
                icon: Icons.wallpaper_outlined,
                title: 'Set as wallpaper',
                isDark: isDark,
                onTap: () async {
                  Get.back();

                  final controller = _getSelectedPhotoController();

                  if (controller == null) {
                    return;
                  }

                  await controller.setAsWallpaper();
                },
              ),

              _MoreItem(
                icon: Icons.photo_size_select_large_outlined,
                title: 'Resize',
                isDark: isDark,
                onTap: () async {
                  Get.back();

                  final controller = _getSelectedPhotoController();

                  if (controller == null) {
                    return;
                  }

                  await controller.resizePhoto();
                },
              ),

              _MoreItem(
                icon: Icons.info_outline_rounded,
                title: 'Info',
                isDark: isDark,
                onTap: () async {
                  Get.back();

                  await showInfo(asset);
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
  Future<void> handleMoreAction(String value) async {
    if (value == 'remove_favorite') {
      await removeSelectedFromFavorites();
      return;
    }

    final photoController = _getSelectedPhotoController();

    if (photoController == null) {
      return;
    }

    switch (value) {
      case 'copy':
        await photoController.copyPhoto();
        break;

      case 'move':
        await photoController.movePhoto();
        break;

      case 'rename':
        await photoController.renamePhoto();
        break;

      case 'edit':
        await photoController.editPhoto();
        break;

      case 'wallpaper':
        await photoController.setAsWallpaper();
        break;

      case 'resize':
        await photoController.resizePhoto();
        break;

      case 'info':
        final asset = selectedAssets.first;
        await showInfo(asset);
        break;
    }
  }
  Future<void> removeSelectedFromFavorites() async {
    final assets = selectedAssets;

    if (assets.isEmpty) {
      return;
    }

    try {
      for (final asset in assets) {
        if (Platform.isIOS || Platform.isMacOS) {
          await PhotoManager.editor.darwin.favoriteAsset(
            entity: asset,
            favorite: false,
          );
        } else {
          await PhotoManager.plugin.favoriteAsset(
            asset.id,
            false,
          );
        }
      }

      media.removeWhere(
            (asset) => assets.any((selected) => selected.id == asset.id),
      );

      clearSelection();

      AppToast.show('${assets.length} item${assets.length == 1 ? '' : 's'} removed from favorites');
    } catch (e) {
      debugPrint('REMOVE FAVORITE ERROR: $e');

      AppToast.show("Favorite Error: ${e.toString()}");
    }
  }
  Future<void> openFavoriteImportScreen() async {
    Get.to(
          () => FavoriteImportScreen(),
    );
  }
  Future<void> showInfo(AssetEntity asset) async {
    final file = await asset.file;

    final sizeText = file == null ? 'Unknown' : await _fileSize(file);

    Get.dialog(
      ChromeDialog(
        title: 'Information',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${asset.title ?? 'Unknown'}', style: ChromeText.body),
            const SizedBox(height: 8),
            Text('Type: ${asset.type.name}', style: ChromeText.body),
            const SizedBox(height: 8),
            Text('Size: $sizeText', style: ChromeText.body),
            const SizedBox(height: 8),
            Text(
              'Resolution: ${asset.width} × ${asset.height}',
              style: ChromeText.body,
            ),
            const SizedBox(height: 8),
            Text(
              'Favorite: ${asset.isFavorite ? 'Yes' : 'No'}',
              style: ChromeText.body,
            ),
          ],
        ),
        actions: [
          ChromeButton.ok(label: 'Close', onPressed: Get.back),
        ],
      ),
    );
  }

  Future<String> _fileSize(File file) async {
    try {
      final bytes = await file.length();

      if (bytes < 1024) {
        return '$bytes B';
      }

      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }

      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }

      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (_) {
      return 'Unknown';
    }
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDark;

  const _MoreItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isDark ? Colors.white : Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontFamily: FontFamily.robotoRegular,
          fontSize: 15,
        ),
      ),
    );
  }
}
