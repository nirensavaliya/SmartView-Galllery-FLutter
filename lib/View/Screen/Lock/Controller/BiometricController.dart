import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class BiometricController extends GetxController
    with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String biometricEnabledKey =
      'advanced_fingerprint';

  static const MethodChannel _settingsChannel =
  MethodChannel('native_camera');

  final RxBool isEnabled = false.obs;
  final RxBool isAuthenticating = false.obs;

  bool waitingForBiometricEnrollment = false;

  @override
  void onInit() {
    super.onInit();

    WidgetsBinding.instance.addObserver(this);

    loadBiometricSetting();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

void loadBiometricSetting() {
    final bool savedValue =
    GetStorageData.readBoolean(
      biometricEnabledKey,
      defaultValue: false,
    );

    isEnabled.value = savedValue;

    debugPrint(
      'BIOMETRIC SETTING LOADED = $savedValue',
    );
  }

Future<void> setBiometricEnabled(
      bool value,
      ) async {
    isEnabled.value = value;

    await GetStorageData.saveBoolean(
      biometricEnabledKey,
      value,
    );

    debugPrint(
      'BIOMETRIC SETTING SAVED = $value',
    );
  }

Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck =
      await _localAuth.canCheckBiometrics;

      final bool supported =
      await _localAuth.isDeviceSupported();

      debugPrint(
        'BIOMETRIC canCheck = $canCheck, supported = $supported',
      );

      return canCheck || supported;
    } on LocalAuthException catch (e) {
      debugPrint(
        'BIOMETRIC CHECK ERROR = ${e.code}',
      );

      return false;
    } catch (e) {
      debugPrint(
        'BIOMETRIC CHECK ERROR = $e',
      );

      return false;
    }
  }

Future<void> showBiometricEnrollmentDialog() async {
    await Get.dialog(
      AlertDialog(
        backgroundColor: InnerChrome.dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20,
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          4,
        ),
        title: Text(
          'No fingerprint detected',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Plus Jakarta Sans',
            color: InnerChrome.dialogInk,
          ),
        ),
        content: Text(
          'Please go to your phone’s setting to record fingerprint.',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontFamily: 'Plus Jakarta Sans',
            color: InnerChrome.muted,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          0,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 43,
            child: ElevatedButton(
              onPressed: () async {
                Get.back();

                await openBiometricSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: InnerChrome.dialogPrimaryBg,
                foregroundColor: InnerChrome.dialogPrimaryFg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 43,
            child: TextButton(
              onPressed: () {
                Get.back();

                isEnabled.value = false;

                GetStorageData.saveBoolean(
                  biometricEnabledKey,
                  false,
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: InnerChrome.dialogSecondaryBg,
                foregroundColor: InnerChrome.dialogSecondaryFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

Future<void> openBiometricSettings() async {
    try {
      waitingForBiometricEnrollment = true;

      debugPrint(
        'OPENING BIOMETRIC SETTINGS...',
      );

      await _settingsChannel.invokeMethod(
        'openBiometricSettings',
      );
    } on PlatformException catch (e) {
      debugPrint(
        'OPEN BIOMETRIC SETTINGS ERROR = ${e.code}',
      );

      waitingForBiometricEnrollment = false;

      AppToast.show('Unable to open biometric settings.');
    } catch (e) {
      debugPrint(
        'OPEN BIOMETRIC SETTINGS ERROR = $e',
      );

      waitingForBiometricEnrollment = false;
    }
  }

@override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed &&
        waitingForBiometricEnrollment) {
      debugPrint(
        'RETURNED FROM BIOMETRIC SETTINGS',
      );

      _checkEnrollmentAfterSettings();
    }
  }

Future<void> _checkEnrollmentAfterSettings() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!waitingForBiometricEnrollment) {
      return;
    }

    final bool available =
    await isBiometricAvailable();

    debugPrint(
      'BIOMETRIC AFTER SETTINGS = $available',
    );

    if (available) {
      waitingForBiometricEnrollment = false;

      await setBiometricEnabled(true);

      debugPrint(
        'BIOMETRIC AUTOMATICALLY ENABLED',
      );

      AppToast.show('Fingerprint authentication enabled successfully.');
    } else {
      debugPrint(
        'NO BIOMETRIC WAS ADDED',
      );
    }
  }

Future<bool> authenticate() async {
    if (isAuthenticating.value) {
      return false;
    }

    try {
      isAuthenticating.value = true;

      final bool canCheck =
      await _localAuth.canCheckBiometrics;

      final bool supported =
      await _localAuth.isDeviceSupported();

      debugPrint(
        '========== BIOMETRIC ==========',
      );

      debugPrint(
        'canCheckBiometrics = $canCheck',
      );

      debugPrint(
        'isDeviceSupported = $supported',
      );

      if (!canCheck && !supported) {
        return false;
      }

      final bool result =
      await _localAuth.authenticate(
        localizedReason:
        'Authenticate to open Private',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      debugPrint(
        'BIOMETRIC RESULT = $result',
      );

      return result;
    } on LocalAuthException catch (e) {
      debugPrint(
        'LOCAL AUTH ERROR CODE = ${e.code}',
      );

      debugPrint(
        'LOCAL AUTH ERROR = $e',
      );

      return false;
    } catch (e) {
      debugPrint(
        'BIOMETRIC ERROR = $e',
      );

      return false;
    } finally {
      isAuthenticating.value = false;
    }
  }
}