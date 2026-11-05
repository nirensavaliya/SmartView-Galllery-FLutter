import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class MemoryShareController extends GetxController {
  final List<AssetEntity> assets;

  MemoryShareController({required this.assets,});

  final RxSet<int> selectedIndexes = RxSet<int>();
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
      AppToast.show('Please select at least one photo');
      return;
    }

    if (isSharing.value) return;

    try {
      isSharing.value = true;

      final List<XFile> files = [];
      final List<String> fileNames = [];

      final List<int> indexes =
      selectedIndexes.toList()..sort();

      for (final index in indexes) {
        final AssetEntity asset = assets[index];

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

      if (files.isEmpty) {
        AppToast.show('Unable to load selected photos');
        return;
      }

      await Share.shareXFiles(
        files,
        fileNameOverrides: fileNames,
      );
    } catch (e) {
      log('MEMORY SHARE ERROR: $e');

      AppToast.show('Unable to share photos');
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

      final MemoryGroup newMemory = MemoryGroup(
        title: name,
        date: DateTime.now(),
        assets: selectedAssets,
      );

      forYouController.memories.add(newMemory);
      forYouController.memories.sort((a, b) => b.date.compareTo(a.date),);
      forYouController.memories.refresh();

      await forYouController.saveCustomMemory(newMemory);

      debugPrint('MEMORY CREATED + SAVED => $name | ''PHOTOS = ${selectedAssets.length}',);

      debugPrint('MEMORY CREATED => $name | PHOTOS = ${selectedAssets.length}',
      );
    } catch (e, stack) {
      debugPrint('CREATE MEMORY ERROR => $e');
      debugPrint(stack.toString());
    }
  }

}