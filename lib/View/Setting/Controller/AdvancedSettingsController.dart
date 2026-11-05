import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/Lock/ChangeLockScreen.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/BiometricController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/PrivatePhotoController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/lock_setup_controller.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';

class AdvancedSettingsController extends GetxController {
  static const String rememberLastVideoPositionKey =
      'advanced_rememberLastVideoPosition';

  static const String loopVideosKey = 'advanced_loopVideos';

  static const String videoVolumeBrightnessGesturesKey =
      'advanced_videoVolumeBrightnessGestures';

  static const String seekGestureKey = 'advanced_seekGesture';

  static const String pinchToZoomVideoKey = 'advanced_pinchToZoomVideo';

  static const String maxBrightnessFullscreenKey =
      'advanced_maxBrightnessFullscreen';

  static const String blackBackgroundFullscreenKey =
      'advanced_blackBackgroundFullscreen';

  static const String hideSystemUiFullscreenKey =
      'advanced_hideSystemUiFullscreen';

  static const String instantMediaChangeKey = 'advanced_instantMediaChange';

  static const String photoBrightnessGesturesKey =
      'advanced_photoBrightnessGestures';

  static const String closeFullscreenWithDownGestureKey =
      'advanced_closeFullscreenWithDownGesture';

  static const String showNotchKey = 'advanced_showNotch';

  static const String fingerprintKey = 'advanced_fingerprint';
  static const String biometricEnabledKey = 'advanced_fingerprint';
  static const String deletePhotosAfter30DaysKey =
      'advanced_deletePhotosAfter30Days';

  final RxBool rememberLastVideoPosition = true.obs;

  final RxBool loopVideos = false.obs;

  final RxBool videoVolumeBrightnessGestures = true.obs;

  final RxBool seekGesture = true.obs;

  final RxBool pinchToZoomVideo = true.obs;

  final RxBool maxBrightnessFullscreen = true.obs;

  final RxBool blackBackgroundFullscreen = true.obs;

  final RxBool hideSystemUiFullscreen = false.obs;

  final RxBool instantMediaChange = false.obs;

  final RxBool photoBrightnessGestures = false.obs;

  final RxBool closeFullscreenWithDownGesture = true.obs;

  final RxBool showNotch = true.obs;

  final RxBool fingerprint = false.obs;

  final RxBool deletePhotosAfter30Days = true.obs;
  final BiometricController biometricController = Get.put(
    BiometricController(),
    permanent: true,
  );
  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  void loadSettings() {
    rememberLastVideoPosition.value = GetStorageData.readBoolean(
      rememberLastVideoPositionKey,
      defaultValue: true,
    );
    loopVideos.value = GetStorageData.readBoolean(
      loopVideosKey,
      defaultValue: false,
    );
    videoVolumeBrightnessGestures.value = GetStorageData.readBoolean(
      videoVolumeBrightnessGesturesKey,
      defaultValue: true,
    );
    seekGesture.value = GetStorageData.readBoolean(
      seekGestureKey,
      defaultValue: true,
    );
    pinchToZoomVideo.value = GetStorageData.readBoolean(
      pinchToZoomVideoKey,
      defaultValue: true,
    );
    maxBrightnessFullscreen.value = GetStorageData.readBoolean(
      maxBrightnessFullscreenKey,
      defaultValue: true,
    );
    blackBackgroundFullscreen.value = GetStorageData.readBoolean(
      blackBackgroundFullscreenKey,
      defaultValue: true,
    );
    hideSystemUiFullscreen.value = GetStorageData.readBoolean(
      hideSystemUiFullscreenKey,
      defaultValue: false,
    );
    instantMediaChange.value = GetStorageData.readBoolean(
      instantMediaChangeKey,
      defaultValue: false,
    );
    photoBrightnessGestures.value = GetStorageData.readBoolean(
      photoBrightnessGesturesKey,
      defaultValue: false,
    );
    closeFullscreenWithDownGesture.value = GetStorageData.readBoolean(
      closeFullscreenWithDownGestureKey,
      defaultValue: true,
    );
    showNotch.value = GetStorageData.readBoolean(
      showNotchKey,
      defaultValue: true,
    );
    fingerprint.value = biometricController.isEnabled.value;
    deletePhotosAfter30Days.value = GetStorageData.readBoolean(
      deletePhotosAfter30DaysKey,
      defaultValue: true,
    );
  }

  void _saveBoolean(String key, bool value) {
    GetStorageData.saveBoolean(key, value);
  }

  void toggleRememberLastVideoPosition(bool value) {
    rememberLastVideoPosition.value = value;

    _saveBoolean(rememberLastVideoPositionKey, value);
  }

  void toggleLoopVideos(bool value) {
    loopVideos.value = value;

    _saveBoolean(loopVideosKey, value);
  }

  void toggleVideoVolumeBrightnessGestures(bool value) {
    videoVolumeBrightnessGestures.value = value;

    _saveBoolean(videoVolumeBrightnessGesturesKey, value);
  }

  void toggleSeekGesture(bool value) {
    seekGesture.value = value;

    _saveBoolean(seekGestureKey, value);
  }

  void togglePinchToZoomVideo(bool value) {
    pinchToZoomVideo.value = value;

    _saveBoolean(pinchToZoomVideoKey, value);
  }

  void toggleMaxBrightnessFullscreen(bool value) {
    maxBrightnessFullscreen.value = value;

    _saveBoolean(maxBrightnessFullscreenKey, value);
  }

  void toggleBlackBackgroundFullscreen(bool value) {
    blackBackgroundFullscreen.value = value;

    _saveBoolean(blackBackgroundFullscreenKey, value);
  }

  void toggleHideSystemUiFullscreen(bool value) {
    hideSystemUiFullscreen.value = value;

    _saveBoolean(hideSystemUiFullscreenKey, value);
  }

  void toggleInstantMediaChange(bool value) {
    instantMediaChange.value = value;

    _saveBoolean(instantMediaChangeKey, value);
  }

  void togglePhotoBrightnessGestures(bool value) {
    photoBrightnessGestures.value = value;

    _saveBoolean(photoBrightnessGesturesKey, value);
  }

  void toggleCloseFullscreenWithDownGesture(bool value) {
    closeFullscreenWithDownGesture.value = value;

    _saveBoolean(closeFullscreenWithDownGestureKey, value);
  }

  void toggleShowNotch(bool value) {
    showNotch.value = value;

    _saveBoolean(showNotchKey, value);
  }

  void rotateFullscreenMedia() {
    Get.dialog(
      ChromeDialog(
        title: 'Rotate fullscreen media by',
        child: RadioListTile<String>(
          value: 'System setting',
          groupValue: 'System setting',
          activeColor: InnerChrome.accent,
          title: Text('System setting', style: ChromeText.row),
          contentPadding: EdgeInsets.zero,
          onChanged: (_) {
            Get.back();
          },
        ),
      ),
    );
  }

  Future<void> toggleFingerprint(bool value) async {
    try {
      debugPrint('FINGERPRINT SWITCH = $value');

      if (!value) {
        fingerprint.value = false;

        await biometricController.setBiometricEnabled(false);

        return;
      }

      final bool available = await biometricController.isBiometricAvailable();

      debugPrint('BIOMETRIC AVAILABLE = $available');

      if (!available) {
        fingerprint.value = false;

        await biometricController.setBiometricEnabled(false);

        await biometricController.showBiometricEnrollmentDialog();

        return;
      }

      final bool verified = await biometricController.authenticate();

      if (!verified) {
        fingerprint.value = false;

        await biometricController.setBiometricEnabled(false);

        return;
      }

      fingerprint.value = true;

      await biometricController.setBiometricEnabled(true);
    } catch (e) {
      debugPrint('FINGERPRINT SWITCH ERROR = $e');

      fingerprint.value = false;

      await biometricController.setBiometricEnabled(false);
    }
  }

  void changePassword() {
    final PrivateLockController private =
        Get.isRegistered<PrivateLockController>()
        ? Get.find<PrivateLockController>()
        : Get.put(PrivateLockController());
    private.loadLockMode();

    if (Get.isRegistered<ChangeLockController>()) {
      Get.delete<ChangeLockController>(force: true);
    }

    Get.to(
      () => ChangeLockScreen(
        targetMode: LockMode.pin,
        title: 'Change Password',
        replaceWithPin: true,
      ),
    );
  }

  void changeUnlockMethod() {
    AppToast.show("Change unlock method for vault.");
  }

  void toggleDeletePhotosAfter30Days(bool value) {
    deletePhotosAfter30Days.value = value;

    _saveBoolean(deletePhotosAfter30DaysKey, value);
  }

  Future<void> emptyRecycleBin() async {
    final bool? result = await Get.dialog<bool>(
      ChromeDialog(
        title: 'Empty Recycle Bin',
        message: 'Are you sure you want to empty the Recycle Bin?',
        actions: [
          ChromeButton.cancel(onPressed: () => Get.back(result: false)),
          ChromeButton.danger(
            label: 'Clear',
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
      barrierDismissible: true,
    );

    if (result != true) {
      return;
    }

    if (!Get.isRegistered<RecycleBinController>()) {
      Get.put(RecycleBinController());
    }

    final RecycleBinController recycleBinController =
        Get.find<RecycleBinController>();

    await recycleBinController.clearRecycleBin();
  }
}
