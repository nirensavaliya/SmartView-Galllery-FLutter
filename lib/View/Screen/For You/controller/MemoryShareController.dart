import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

class MemoryShareController extends GetxController {
  final List<AssetEntity> assets;

  MemoryShareController({
    required this.assets,
  });

  // Initially NOTHING is selected
  final RxSet<int> selectedIndexes = <int>{}.obs;

  final RxBool isSharing = false.obs;

  bool isSelected(int index) {
    return selectedIndexes.contains(index);
  }

  void toggleSelection(int index) {
    if (selectedIndexes.contains(index)) {
      selectedIndexes.remove(index);
    } else {
      selectedIndexes.add(index);
    }
  }

  void selectAll() {
    selectedIndexes
      ..clear()
      ..addAll(
        List<int>.generate(
          assets.length,
              (index) => index,
        ),
      );
  }

  void clearSelection() {
    selectedIndexes.clear();
  }

  Future<void> shareSelected() async {
    if (selectedIndexes.isEmpty) {
      Get.snackbar(
        'Share',
        'Please select at least one photo',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isSharing.value) return;

    try {
      isSharing.value = true;

      final List<XFile> files = [];
      final List<String> fileNames = [];

      // Keep selected order
      final List<int> indexes =
      selectedIndexes.toList()..sort();

      for (final index in indexes) {
        final AssetEntity asset = assets[index];

        // ---------------------------------------
        // FIRST TRY: original file
        // ---------------------------------------
        final file = await asset.originFile;

        if (file != null) {
          files.add(
            XFile(
              file.path,
              mimeType: 'image/jpeg',
            ),
          );

          fileNames.add(
            'memory_${index + 1}.jpg',
          );

          continue;
        }

        // ---------------------------------------
        // FALLBACK: original bytes
        // ---------------------------------------
        final Uint8List? bytes =
        await asset.originBytes;

        if (bytes != null && bytes.isNotEmpty) {
          files.add(
            XFile.fromData(
              bytes,
              mimeType: 'image/jpeg',
            ),
          );

          fileNames.add(
            'memory_${index + 1}.jpg',
          );
        }
      }

      // No files could be loaded
      if (files.isEmpty) {
        Get.snackbar(
          'Share',
          'Unable to load selected photos',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // ---------------------------------------
      // SHARE
      // ---------------------------------------
      await Share.shareXFiles(
        files,
        fileNameOverrides: fileNames,
      );
    } catch (e) {
      print('MEMORY SHARE ERROR: $e');

      Get.snackbar(
        'Share Error',
        'Unable to share photos',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSharing.value = false;
    }
  }
  Future<void> createMemory(String name) async {
    try {
      final List<AssetEntity> selectedAssets = selectedIndexes
          .map((index) => assets[index])
          .toList();

      if (selectedAssets.isEmpty) {
        return;
      }

      final ForYouController forYouController =
      Get.find<ForYouController>();

      // New memory create
      final MemoryGroup newMemory = MemoryGroup(
        title: name,
        date: DateTime.now(),
        assets: selectedAssets,
      );

      // Current UI me immediately add
      forYouController.memories.add(newMemory);
      forYouController.memories.refresh();

      debugPrint(
        'MEMORY CREATED => $name | PHOTOS = ${selectedAssets.length}',
      );
    } catch (e, stack) {
      debugPrint('CREATE MEMORY ERROR => $e');
      debugPrint(stack.toString());
    }
  }

}