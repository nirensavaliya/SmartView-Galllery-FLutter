import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/Language/AppLanguageScreen.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:gallery_photos/View/Setting/AdvancedSettingsScreen.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/View/Setting/CallSettingsScreen.dart';
import 'package:gallery_photos/View/Setting/FeedbackScreen.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

class SettingsController extends GetxController {
  final RxBool darkMode = false.obs;
  final RxBool deleteEmptyFolders = true.obs;
  final RxBool keepLastModified = true.obs;
  static const String editedFileSavingBehaviorKey = 'editedFileSavingBehavior';
  static const String saveCopy = 'saveCopy';
  static const String replaceFile = 'replaceFile';
  static const String alwaysAsk = 'alwaysAsk';
  final RxString editedFileSavingBehaviorValue = alwaysAsk.obs;
  static const String deleteEmptyFoldersKey = 'deleteEmptyFolders';
  static const String keepLastModifiedKey = 'keepLastModified';
  final RxInt selectedRating = 0.obs;
  final RxString cacheSizeLabel = '0 MB'.obs;
  final RxBool callOverlayReady = false.obs;
  final RxBool callPermissionsGranted = false.obs;
  bool _clearingCache = false;

  @override
  void onInit() {
    super.onInit();

    loadSettings();
    loadCacheSize();
    refreshCallOverlay();
  }

  void loadSettings() {
    darkMode.value = GetStorageData.readBoolean(
      GetStorageData.darkMode,
      defaultValue: false,
    );

    deleteEmptyFolders.value = GetStorageData.readBoolean(
      GetStorageData.deleteEmptyFolders,
      defaultValue: true,
    );

    keepLastModified.value = GetStorageData.readBoolean(
      GetStorageData.keepLastModified,
      defaultValue: true,
    );

    editedFileSavingBehaviorValue.value =
        GetStorageData.readString(editedFileSavingBehaviorKey) ?? alwaysAsk;
  }

  static const String deletePhotosAfter30DaysKey = 'deletePhotosAfter30Days';

  final RxBool deletePhotosAfter30Days = true.obs;

  void loadRecycleBinSettings() {
    final recycleBinController = Get.find<RecycleBinController>();

    deletePhotosAfter30Days.value =
        recycleBinController.autoClearAfter30Days.value;
  }

  void toggleDeletePhotosAfter30Days(bool value) {
    deletePhotosAfter30Days.value = value;

    final recycleBinController = Get.find<RecycleBinController>();

    recycleBinController.toggleAutoClear(value);
  }

  Future<void> emptyRecycleBin() async {
    final bool? result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Empty Recycle Bin",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: InnerChrome.dialogInk,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Are you sure you want to empty the Recycle Bin?",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: InnerChrome.muted,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Get.back(result: false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: InnerChrome.dialogInk,
                      side: BorderSide(color: InnerChrome.line, width: 1.4),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back(result: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: InnerChrome.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Clear",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      return;
    }

    final recycleBinController =
    Get.find<RecycleBinController>();

    await recycleBinController.clearRecycleBin();
  }

  void _rebuildEntireApp() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }

  void toggleDarkMode(bool value) {
    darkMode.value = value;

    GetStorageData.saveBoolean(GetStorageData.darkMode, value);

    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildEntireApp();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void toggleDeleteEmptyFolders(bool value) {
    deleteEmptyFolders.value = value;

    GetStorageData.saveBoolean(GetStorageData.deleteEmptyFolders, value);
  }

  void toggleKeepLastModified(bool value) {
    keepLastModified.value = value;

    GetStorageData.saveBoolean(GetStorageData.keepLastModified, value);
  }

Future<void> editedFileSavingBehavior() async {
    final String? selected = await Get.dialog<String>(
      _buildEditedFileSavingDialog(),
      barrierDismissible: true,
    );

    if (selected == null) {
      return;
    }

    editedFileSavingBehaviorValue.value = selected;

    GetStorageData.saveString(editedFileSavingBehaviorKey, selected);
  }

Widget _buildEditedFileSavingDialog() {
    TextStyle optionStyle() => TextStyle(
      fontSize: 15,
      color: InnerChrome.dialogInk,
      fontWeight: FontWeight.w500,
    );

    Widget option(String value, String label) {
      return RadioListTile<String>(
        value: value,
        groupValue: editedFileSavingBehaviorValue.value,
        activeColor: InnerChrome.accent,
        title: Text(label, style: optionStyle()),
        onChanged: (selected) {
          if (selected == null) return;
          Get.back(result: selected);
        },
      );
    }

    return Obx(
      () => AlertDialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Edited-file saving behavior",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: InnerChrome.dialogInk,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(saveCopy, "Save copy"),
            option(replaceFile, "Replace file"),
            option(alwaysAsk, "Always ask"),
          ],
        ),
      ),
    );
  }

void manageExcludedFolders() {}

  Future<void> refreshCallOverlay() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final dynamic status = await const MethodChannel(
        'native_camera',
      ).invokeMethod('callOverlayStatus');
      if (status is Map) {
        callOverlayReady.value = status['enabled'] == true;
        callPermissionsGranted.value =
            status['phone'] == true && status['overlay'] == true;
      }
    } catch (_) {}
  }

  Future<void> callSettings() async {
    await Get.to(() => const CallSettingsScreen());
    await refreshCallOverlay();
  }

  void advancedSettings() {
    Get.to(() => AdvancedSettingsScreen());
  }

  void language() {
    Get.to(() => AppLanguageScreen());
  }

  Future<void> loadCacheSize() async {
    try {
      int bytes = PaintingBinding.instance.imageCache.currentSizeBytes;
      for (final Directory dir in await _cacheDirectories()) {
        bytes += await _folderBytes(dir);
      }
      cacheSizeLabel.value = _formatCache(bytes);
    } catch (e) {
      debugPrint('Cache size error: $e');
    }
  }

  Future<void> clearCache() async {
    if (_clearingCache) return;
    _clearingCache = true;
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();
      imageCache.clearLiveImages();

      try {
        await PhotoManager.clearFileCache();
      } catch (_) {}

      for (final Directory dir in await _cacheDirectories()) {
        if (!await dir.exists()) continue;
        await for (final FileSystemEntity entity
            in dir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }

      cacheSizeLabel.value = '0 MB';
      AppToast.show('Cache cleared');
    } catch (e) {
      debugPrint('Clear cache error: $e');
      AppToast.show('Unable to clear cache');
    } finally {
      _clearingCache = false;
      await loadCacheSize();
    }
  }

  Future<List<Directory>> _cacheDirectories() async {
    final Directory cacheDir = await getApplicationCacheDirectory();
    final Directory tempDir = await getTemporaryDirectory();
    if (tempDir.path == cacheDir.path ||
        tempDir.path.startsWith('${cacheDir.path}${Platform.pathSeparator}')) {
      return <Directory>[cacheDir];
    }
    return <Directory>[cacheDir, tempDir];
  }

  Future<int> _folderBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity entity
        in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  String _formatCache(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    final double mb = bytes / (1024 * 1024);
    if (mb < 10) return '${mb.toStringAsFixed(1)} MB';
    if (mb < 1024) return '${mb.toStringAsFixed(0)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  void rateUs() {
    selectedRating.value = 0;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: InnerChrome.dialogBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: InnerChrome.lift,
          ),
          child: Obx(
            () => Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: InnerChrome.dialogField,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: Get.back,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          height: 32,
                          width: 32,
                          child: Icon(
                            Icons.close_rounded,
                            color: InnerChrome.dialogIcon,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 66,
                    width: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF9B4DFF).withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 36,
                      color: Color(0xFF9B4DFF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rate Us',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: InnerChrome.dialogInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We appreciate your feedback!\n'
                    'Please rate your experience with us.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: InnerChrome.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final int rating = index + 1;
                      final bool isSelected = rating <= selectedRating.value;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            selectedRating.value = rating;
                          },
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 40,
                            color: isSelected
                                ? const Color(0xFFAD43E8)
                                : InnerChrome.faint,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _ratingText(selectedRating.value),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8060F5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedRating.value == 0
                        ? 'Tap a star to share your experience.'
                        : 'Your feedback helps us to improve.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: InnerChrome.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF4388FF),
                            Color(0xFF2970FF),
                            Color(0xFFAA32E8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6255F5).withValues(alpha: 0.30),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: selectedRating.value == 0
                            ? null
                            : () {
                                final int rating = selectedRating.value;
                                Get.back();
                                Get.snackbar(
                                  'Thank You!',
                                  'You rated us $rating out of 5 stars.',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.65),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Submit Rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  String _ratingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }
  void feedback() {
    Get.to(() => const FeedbackScreen());
  }

  Future<void> shareWithFriends() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out SmartView Gallery',
          title: 'Share with friends',
        ),
      );
    } catch (e) {
      debugPrint('Share app error: $e');
      AppToast.show('Unable to share');
    }
  }

  void privacyPolicy() {}
}
