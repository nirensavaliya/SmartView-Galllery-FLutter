import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class RecycleBinController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool autoClearAfter30Days = true.obs;

  final RxList<RecycleBinItem> recycleItems = <RecycleBinItem>[].obs;
  Directory? _recycleDirectory;
  File? _databaseFile;
  final RxList<RecycleBinItem> selectedItems = <RecycleBinItem>[].obs;
  bool get isSelectionMode => selectedItems.isNotEmpty;
  @override
  void onInit() {
    super.onInit();
    loadRecycleBin();
  }
  void startSelection(RecycleBinItem item) {
    if (!selectedItems.contains(item)) {
      selectedItems.add(item);
    }
  }

  void toggleSelection(RecycleBinItem item) {
    if (selectedItems.contains(item)) {
      selectedItems.remove(item);
    } else {
      selectedItems.add(item);
    }
  }

  void clearSelection() {
    selectedItems.clear();
  }

  bool isSelected(RecycleBinItem item) {
    return selectedItems.contains(item);
  }
  Future<void> restoreSelectedItems() async {
    final items = selectedItems.toList();
    if (items.isEmpty) return;
    isLoading.value = true;
    try {
      for (final item in items) {
        await restoreItem(item);
      }

      selectedItems.clear();

      await _saveDatabase();

      Get.snackbar(
        "Restore",
        "Selected files restored successfully",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint("Restore Selected Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> permanentlyDeleteSelectedItems() async {
    final items = selectedItems.toList();

    if (items.isEmpty) return;

    isLoading.value = true;

    try {
      for (final item in items) {
        final file = File(item.recyclePath);

        if (await file.exists()) {
          await file.delete();
        }

        recycleItems.remove(item);
      }

      selectedItems.clear();

      await _saveDatabase();

      Get.snackbar(
        "Recycle Bin",
        "Selected files permanently deleted",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint("Delete Selected Error: $e");
    } finally {
      isLoading.value = false;
    }
  }
  Future<void> _initStorage() async {
    final appDir = await getApplicationDocumentsDirectory();

    _recycleDirectory = Directory('${appDir.path}/RecycleBin');

    if (!await _recycleDirectory!.exists()) {
      await _recycleDirectory!.create(recursive: true);
    }

    _databaseFile = File('${_recycleDirectory!.path}/recycle_bin.json');
  }

  Future<void> loadRecycleBin() async {
    try {
      isLoading.value = true;

      final result = GetStorageData.readObject(
        GetStorageData.recycleBin,
      );

      if (result != null && result is List) {
        recycleItems.assignAll(
          result
              .map(
                (e) => RecycleBinItem.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
              .toList(),
        );
      } else {
        recycleItems.clear();
      }

      await _removeExpiredItems();

      debugPrint(
        "Recycle Bin loaded: ${recycleItems.length}",
      );
    } catch (e) {
      debugPrint("Recycle Bin Load Error: $e");
      recycleItems.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveDatabase() async {
    try {
      await _initStorage();

      final data = recycleItems.map((e) => e.toJson()).toList();
      await GetStorageData.saveObject(
        GetStorageData.recycleBin,
        data,
      );
      await _databaseFile!.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint("Recycle Bin Database Error: $e");
    }
  }


  Future<bool> addToRecycleBin(AssetEntity asset) async {
    try {
      await _initStorage();

      final File? sourceFile = await asset.file;

      if (sourceFile == null || !await sourceFile.exists()) {
        return false;
      }

      final originalName = asset.title ?? sourceFile.path.split('/').last;

      final extension = originalName.contains('.')
          ? originalName.substring(originalName.lastIndexOf('.'))
          : '';

      final uniqueName =
          "${DateTime.now().millisecondsSinceEpoch}_"
          "${asset.id.hashCode}$extension";

      final destination = File('${_recycleDirectory!.path}/$uniqueName');

      // Copy original file to RecycleBin
      await sourceFile.copy(destination.path);

      final item = RecycleBinItem(
        id: asset.id,
        name: originalName,
        recyclePath: destination.path,
        isVideo: asset.type == AssetType.video,
        deletedDate: DateTime.now(),
        originalDate: asset.createDateTime,
        originalRelativePath: asset.relativePath,
      );

      recycleItems.add(item);

      await _saveDatabase();

      return true;
    } catch (e) {
      debugPrint("Add Recycle Bin Error: $e");

      return false;
    }
  }

  Future<bool> restoreItem(RecycleBinItem item) async {
    try {
      final file = File(item.recyclePath);

      if (!await file.exists()) {
        recycleItems.remove(item);
        await _saveDatabase();
        return false;
      }

      final fileName = item.name;

      AssetEntity? restoredAsset;

      if (item.isVideo) {
        restoredAsset = await PhotoManager.editor.saveVideo(
          file,
          title: fileName,
          creationDate: item.originalDate,
          relativePath: item.originalRelativePath,
        );
      }

      else {
        restoredAsset = await PhotoManager.editor.saveImageWithPath(
          file.path,
          title: fileName,
          creationDate: item.originalDate,
          relativePath: item.originalRelativePath,
        );
      }

      if (restoredAsset == null) {
        Get.snackbar(
          "Restore",
          "Unable to restore item",
          snackPosition: SnackPosition.BOTTOM,
        );

        return false;
      }
      if (await file.exists()) {
        await file.delete();
      }

      recycleItems.remove(item);
      await _saveDatabase();
      await PhotoManager.clearFileCache();
      return true;
    } catch (e) {
      debugPrint("Restore Error: $e");

      Get.snackbar(
        "Restore",
        "Unable to restore item",
        snackPosition: SnackPosition.BOTTOM,
      );

      return false;
    }
  }

  Future<void> restoreAllItems() async {
    try {
      final items = recycleItems.toList();

      if (items.isEmpty) {
        return;
      }

      isLoading.value = true;

      for (final item in items) {
        await restoreItem(item);
      }
      recycleItems.clear();
      await _saveDatabase();

      Get.snackbar(
        "Restore",
        "All files restored successfully",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint("Restore All Error: $e");
      Get.snackbar(
        "Restore",
        "Unable to restore all files",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> permanentlyDelete(RecycleBinItem item) async {
    try {
      final file = File(item.recyclePath);

      if (await file.exists()) {
        await file.delete();
      }

      recycleItems.remove(item);

      await _saveDatabase();

      Get.snackbar(
        "Recycle Bin",
        "${item.name} permanently deleted",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );

      return true;
    } catch (e) {
      debugPrint("Permanent Delete Error: $e");

      return false;
    }
  }

  Future<void> permanentlyDeleteAll() async {
    try {
      for (final item in recycleItems.toList()) {
        final file = File(item.recyclePath);

        if (await file.exists()) {
          await file.delete();
        }
      }

      recycleItems.clear();

      await _saveDatabase();

      Get.snackbar(
        "Recycle Bin",
        "All items permanently deleted",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      debugPrint("Delete All Error: $e");
    }
  }

  Future<void> _removeExpiredItems() async {
    if (!autoClearAfter30Days.value) {
      return;
    }

    final now = DateTime.now();

    final expired = recycleItems.where((item) {
      final difference = now.difference(item.deletedDate).inDays;

      return difference >= 30;
    }).toList();

    if (expired.isEmpty) {
      return;
    }

    for (final item in expired) {
      final file = File(item.recyclePath);

      if (await file.exists()) {
        await file.delete();
      }

      recycleItems.remove(item);
    }

    await _saveDatabase();
  }

  void toggleAutoClear(bool value) {
    autoClearAfter30Days.value = value;
  }

  Future<void> refreshRecycleBin() async {
    await loadRecycleBin();
  }


  Map<String, List<RecycleBinItem>> get groupedItems {
    final Map<String, List<RecycleBinItem>> grouped = {};

    for (final item in recycleItems) {
      final month =
          "${_monthName(item.deletedDate.month)} "
          "${item.deletedDate.year}";

      grouped.putIfAbsent(month, () => []);

      grouped[month]!.add(item);
    }

    return grouped;
  }

  String _monthName(int month) {
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

    return months[month - 1];
  }

  Future<void> permanentlyDeleteSilentlyById(String id) async {
    try {
      final itemIndex = recycleItems.indexWhere((item) => item.id == id);

      if (itemIndex == -1) {
        return;
      }

      final item = recycleItems[itemIndex];

      final file = File(item.recyclePath);

      if (await file.exists()) {
        await file.delete();
      }

      recycleItems.removeAt(itemIndex);

      await _saveDatabase();
    } catch (e) {
      debugPrint("Recycle Bin Rollback Error: $e");
    }
  }


}

class RecycleBinItem {
  final String id;
  final String name;
  final String recyclePath;
  final bool isVideo;
  final DateTime deletedDate;
  final DateTime originalDate;
  final String? originalRelativePath;

  RecycleBinItem({
    required this.id,
    required this.name,
    required this.recyclePath,
    required this.isVideo,
    required this.deletedDate,
    required this.originalDate,
    this.originalRelativePath,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "recyclePath": recyclePath,
      "isVideo": isVideo,
      "deletedDate": deletedDate.toIso8601String(),
      "originalDate": originalDate.toIso8601String(),
      "originalRelativePath": originalRelativePath,
    };
  }

  factory RecycleBinItem.fromJson(Map<String, dynamic> json) {
    return RecycleBinItem(
      id: json["id"] ?? "",
      name: json["name"] ?? "",
      recyclePath: json["recyclePath"] ?? "",
      isVideo: json["isVideo"] ?? false,
      deletedDate: DateTime.parse(json["deletedDate"]),
      originalDate: DateTime.parse(json["originalDate"]),
      originalRelativePath: json["originalRelativePath"],
    );
  }
}
