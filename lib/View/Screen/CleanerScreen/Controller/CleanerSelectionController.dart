import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/Controller/CleanerController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/Common/MediaActionService.dart';

class CleanerSelectionController extends GetxController {
  final RxList<AssetEntity> assets;
  final String title;
  final bool groupBySize;
  final bool groupByDate;

  CleanerSelectionController({
    required List<AssetEntity> assets,
    required this.title,
    this.groupBySize = false,
    this.groupByDate = false,
  }) : assets = assets.obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  final RxSet<String> deletedIds = <String>{}.obs;
  final RxInt selectedBytes = 0.obs;
  final RxBool isDeleting = false.obs;

  @override
  void onInit() {
    super.onInit();
    selectedIds.clear();
    selectedBytes.value = 0;
    _calculateSelectedSize();
  }

  int get selectedCount {
    return selectedIds.length;
  }

  bool get isAllSelected {
    return assets.isNotEmpty && selectedIds.length == assets.length;
  }

Future<void> toggleAsset(AssetEntity asset) async {
    if (selectedIds.contains(asset.id)) {
      selectedIds.remove(asset.id);
    } else {
      selectedIds.add(asset.id);
    }

    selectedIds.refresh();

    await _calculateSelectedSize();
  }

Future<void> toggleSelectAll() async {
    if (isAllSelected) {
      selectedIds.clear();
    } else {
      selectedIds.clear();

      for (final asset in assets) {
        selectedIds.add(asset.id);
      }
    }

    selectedIds.refresh();

    await _calculateSelectedSize();
  }

  Future<void> _calculateSelectedSize() async {
    int total = 0;

    for (final asset in assets) {
      if (!selectedIds.contains(asset.id)) {
        continue;
      }

      try {
        final int size = await asset.fileSize;

        if (size > 0) {
          total += size;
        }
      } catch (e) {
        debugPrint(
          'Selected size error ${asset.id}: $e',
        );
      }
    }

    selectedBytes.value = total;
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

String get selectedSizeText {
    return formatBytes(selectedBytes.value);
  }

List<AssetEntity> get selectedAssets {
    return assets
        .where(
          (asset) => selectedIds.contains(asset.id),
    )
        .toList();
  }

Future<void> deleteSelected() async {
    if (isDeleting.value) {
      return;
    }

    if (selectedIds.isEmpty) {
      AppToast.show('Please select at least one item.');

      return;
    }

    final String? action = await Get.dialog<String>(
      Obx(
        () => ChromeDialog(
          title: 'Are you sure you want to delete?',
          message:
              '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} ($selectedSizeText) selected.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChromeButton.ok(
                label: 'Add to Recycle Bin',
                onPressed: () => Get.back(result: 'recycle'),
              ),
              const SizedBox(height: 10),
              ChromeButton.danger(
                label: 'Delete Permanently',
                onPressed: () => Get.back(result: 'permanent'),
              ),
              const SizedBox(height: 10),
              ChromeButton.cancel(
                onPressed: () => Get.back(result: 'cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null || action == 'cancel') {
      return;
    }

    try {
      isDeleting.value = true;

      if (Get.isRegistered<CleanerController>()) {
        await Get.find<CleanerController>().rescan();
      }
      if (action == 'recycle') {
        await _moveSelectedToRecycleBin();
        return;
      }

      if (action == 'permanent') {
        await _deleteSelectedPermanently();
        return;
      }
    }catch (e, stackTrace) {
      debugPrint('====================================');
      debugPrint('CLEANER DELETE ERROR');
      debugPrint('$e');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('====================================');

      AppToast.show('Something went wrong while deleting.');
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> _moveSelectedToRecycleBin() async {
    final List<AssetEntity> selected = selectedAssets;

    if (selected.isEmpty) {
      return;
    }

    if (!await MediaActionService.ensureMediaManagement()) {
      return;
    }

    final RecycleBinController recycleController =
    Get.isRegistered<RecycleBinController>()
        ? Get.find<RecycleBinController>()
        : Get.put(RecycleBinController());

    final List<AssetEntity> successfullySaved = [];

    for (final asset in selected) {
      try {
        final bool saved =
        await recycleController.addToRecycleBin(asset);

        if (saved) {
          successfullySaved.add(asset);
        } else {
          debugPrint(
            'Recycle Bin save failed: ${asset.id}',
          );
        }
      } catch (e) {
        debugPrint(
          'Recycle Bin error ${asset.id}: $e',
        );
      }
    }

    if (successfullySaved.isEmpty) {
      AppToast.show('Unable to save selected files in Recycle Bin.');

      return;
    }

    final List<String> ids = successfullySaved
        .map((asset) => asset.id)
        .toList();

    final List<String> removedIds =
    await MediaActionService.deleteIds(ids);

    if (removedIds.isEmpty) {
      AppToast.show('Files were saved, but could not be removed from gallery.');

      return;
    }

    deletedIds.addAll(removedIds);
    deletedIds.refresh();

    assets.removeWhere(
          (asset) => removedIds.contains(asset.id),
    );

    selectedIds.removeWhere(
          (id) => removedIds.contains(id),
    );

    assets.refresh();
    selectedIds.refresh();

    await _calculateSelectedSize();

AppToast.show(
  '${removedIds.length} '
    '${removedIds.length == 1 ? 'item' : 'items'} '
    'moved to Recycle Bin.',
);

if (assets.isEmpty) {
      Get.back(
        result: deletedIds.toList(),
      );
    }
  }

Future<void> _deleteSelectedPermanently() async {
    final List<String> ids = selectedIds.toList();

    if (ids.isEmpty) {
      return;
    }

    if (!await MediaActionService.ensureMediaManagement()) {
      return;
    }

    final List<String> removedIds =
    await MediaActionService.deleteIds(ids);

    if (removedIds.isEmpty) {
      AppToast.show('Unable to delete selected items.');

      return;
    }

    deletedIds.addAll(removedIds);
    deletedIds.refresh();

    assets.removeWhere(
          (asset) => removedIds.contains(asset.id),
    );

    selectedIds.removeWhere(
          (id) => removedIds.contains(id),
    );

    assets.refresh();
    selectedIds.refresh();

    await _calculateSelectedSize();

    AppToast.show(
      '${removedIds.length} '
        '${removedIds.length == 1 ? 'item' : 'items'} '
        'deleted permanently.',
    );

    if (assets.isEmpty) {
      Get.back(
        result: deletedIds.toList(),
      );
    }
  }

Future<void> recalculate() async {
    await _calculateSelectedSize();
  }
}