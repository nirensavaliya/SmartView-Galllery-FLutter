import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/BiometricController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/IntruderSelfieService.dart';
import 'package:gallery_photos/View/Screen/Lock/DecoyVaultScreen.dart';
import 'package:gallery_photos/View/Screen/Lock/PrivateScreen.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/Common/AppToast.dart';

enum LockMode { pattern, pin }

class LockSetupController extends GetxController {
  final Rx<LockMode> mode = LockMode.pin.obs;

  final RxString pin = ''.obs;

  final RxString pendingPin = ''.obs;

  final RxBool isConfirmingPin = false.obs;

  static const int pinLength = 4;

  final RxList<int> selectedPattern = <int>[].obs;

  final Rx<Offset?> currentFingerPosition = Rx<Offset?>(null);

  final List<GlobalKey> patternKeys = List.generate(9, (_) => GlobalKey());

  static const String lockModeKey = 'private_lock_mode';

  static const String pinKey = 'private_lock_pin';

  static const String patternKey = 'private_lock_pattern';

  static const String securityQuestionKey = 'private_security_question';

  static const String securityAnswerKey = 'private_security_answer';

  static const int minimumPatternLength = 4;
  final BiometricController biometricController =
      Get.find<BiometricController>();

  @override
  void onInit() {
    super.onInit();

    loadSavedLockMode();
    loadConfiguredLock();
  }

  Future<void> unlockWithFingerprint() async {
    biometricController.loadBiometricSetting();
    if (!biometricController.isEnabled.value) {
      return;
    }
    if (!hasConfiguredLock.value) {
      return;
    }
    final bool authenticated = await biometricController.authenticate();
    if (!authenticated || isClosed) {
      return;
    }
    debugPrint('FINGERPRINT VERIFIED');
    debugPrint('OPENING PRIVATE SCREEN');
    Get.off(() => PrivateScreen());
  }

  void loadConfiguredLock() {
    final dynamic savedMode = GetStorageData.readString(lockModeKey);
    hasConfiguredLock.value =
        savedMode?.toString() == 'pin' || savedMode?.toString() == 'pattern';
    debugPrint('PRIVATE LOCK CONFIGURED: ${hasConfiguredLock.value}');
  }

  void loadSavedLockMode() {
    final dynamic savedMode = GetStorageData.readString(lockModeKey);

    if (savedMode?.toString() == 'pin') {
      mode.value = LockMode.pin;
    } else if (savedMode?.toString() == 'pattern') {
      mode.value = LockMode.pattern;
    }

    debugPrint('PRIVATE LOCK MODE: ${mode.value.name}');
  }

  void switchMode() {
    if (mode.value == LockMode.pattern) {
      switchToPin();
    } else {
      switchToPattern();
    }
  }

  void switchToPin() {
    mode.value = LockMode.pin;

    clearPin();
    clearPattern();
    pendingPin.value = '';
    isConfirmingPin.value = false;
  }

  void switchToPattern() {
    mode.value = LockMode.pattern;

    clearPin();
    clearPattern();
    pendingPin.value = '';
    isConfirmingPin.value = false;
  }

  void handleHorizontalSwipe(double velocity) {
    if (velocity > 0) {
      switchToPattern();
    } else if (velocity < 0) {
      switchToPin();
    }
  }

  final RxBool hasConfiguredLock = false.obs;

  void addPinDigit(String digit) {
    if (pin.value.length >= pinLength) {
      return;
    }

    pin.value += digit;

    debugPrint('PIN LENGTH: ${pin.value.length}');
  }

  void removePinDigit() {
    if (pin.value.isEmpty) {
      return;
    }

    pin.value = pin.value.substring(0, pin.value.length - 1);
  }

  void clearPin() {
    pin.value = '';
  }

  Future<bool> savePin() async {
    if (pin.value.length != pinLength) {
      return false;
    }

    try {
      final String value = pin.value;

      await GetStorageData.saveString(pinKey, value);

      await GetStorageData.saveString(lockModeKey, 'pin');

      hasConfiguredLock.value = true;

      mode.value = LockMode.pin;

      debugPrint('PRIVATE LOCK PIN SAVED');
      debugPrint('PRIVATE LOCK MODE SAVED: pin');

      return true;
    } catch (e) {
      debugPrint('Save PIN Error: $e');

      return false;
    }
  }

  Future<bool> submitSetupPin() async {
    if (pin.value.length != pinLength) {
      return false;
    }

    if (!isConfirmingPin.value) {
      pendingPin.value = pin.value;
      isConfirmingPin.value = true;
      clearPin();
      return false;
    }

    if (pin.value != pendingPin.value) {
      AppToast.show('PIN does not match. Set it again.');
      isConfirmingPin.value = false;
      pendingPin.value = '';
      clearPin();
      return false;
    }

    final bool saved = await savePin();
    isConfirmingPin.value = false;
    pendingPin.value = '';
    return saved;
  }

  Future<bool> saveDecoyPin(String decoyPin) async {
    if (decoyPin.length != pinLength) {
      return false;
    }

    final String savedRealPin =
        GetStorageData.readString(pinKey)?.toString() ?? '';

    if (savedRealPin.isNotEmpty && decoyPin == savedRealPin) {
      AppToast.show('Decoy PIN cannot be same as real PIN');
      return false;
    }

    await GetStorageData.saveString(GetStorageData.decoyPinKey, decoyPin);
    return true;
  }

  void verifyUnlockPin({
    required VoidCallback onSuccess,
  }) {
    final String enteredPin = pin.value;
    final dynamic savedPinValue = GetStorageData.readString(pinKey);
    final String savedPin = savedPinValue?.toString() ?? '';
    final String decoyPin =
        GetStorageData.readString(GetStorageData.decoyPinKey)?.toString() ?? '';

    if (enteredPin == savedPin && savedPin.isNotEmpty) {
      debugPrint('REAL PIN VERIFIED');
      clearPin();
      onSuccess();
      return;
    }

    if (decoyPin.isNotEmpty && enteredPin == decoyPin) {
      debugPrint('DECOY PIN VERIFIED');
      clearPin();
      Get.off(() => DecoyVaultScreen());
      return;
    }

    debugPrint('WRONG PIN');
    unawaited(IntruderSelfieService.capture());
    clearPin();
    AppToast.show('Wrong PIN');
  }
  void startPattern(Offset position) {
    selectedPattern.clear();
    currentFingerPosition.value = position;
    final int? index = getPointFromPosition(position);
    if (index != null) {
      selectedPattern.add(index);
    }
  }

  void updatePattern(Offset position) {
    currentFingerPosition.value = position;
    final int? index = getPointFromPosition(position);
    if (index == null) {
      return;
    }
    if (!selectedPattern.contains(index)) {
      selectedPattern.add(index);
    }
  }

  Future<bool> finishPattern() async {
    currentFingerPosition.value = null;

    if (selectedPattern.length < minimumPatternLength) {
      selectedPattern.clear();
      return false;
    }

    try {
      final List<int> pattern = List<int>.from(selectedPattern);
      await GetStorageData.saveObject(patternKey, pattern);
      await GetStorageData.saveString(lockModeKey, 'pattern');
      hasConfiguredLock.value = true;
      mode.value = LockMode.pattern;
      debugPrint(
        'PRIVATE LOCK PATTERN SAVED: '
        '${pattern.join('-')}',
      );
      return true;
    } catch (e) {
      debugPrint('Save Pattern Error: $e');
      return false;
    }
  }

  void finishUnlockPattern({required VoidCallback onSuccess}) {
    currentFingerPosition.value = null;
    if (selectedPattern.length < minimumPatternLength) {
      selectedPattern.clear();
      AppToast.show('Pattern must contain at least 4 points');
      return;
    }

    final dynamic savedObject = GetStorageData.readObject(patternKey);

    if (savedObject == null) {
      clearPattern();
      AppToast.show('Pattern is not configured');
      return;
    }

    final List<int> savedPattern = _convertPatternToIntList(savedObject);
    if (savedPattern.isEmpty) {
      clearPattern();

      AppToast.show('Pattern is not configured');

      return;
    }

    final List<int> enteredPattern = List<int>.from(selectedPattern);

    debugPrint(
      'ENTERED PATTERN: '
      '${enteredPattern.join('-')}',
    );

    debugPrint(
      'SAVED PATTERN: '
      '${savedPattern.join('-')}',
    );

    if (_listEquals(enteredPattern, savedPattern)) {
      debugPrint('PRIVATE PATTERN VERIFIED');

      clearPattern();

      onSuccess();

      return;
    }

    debugPrint('WRONG PATTERN');

    unawaited(IntruderSelfieService.capture());

    clearPattern();

    AppToast.show('Wrong pattern');
  }

  void clearPattern() {
    selectedPattern.clear();

    currentFingerPosition.value = null;
  }

  int? getPointFromPosition(Offset localPosition) {
    const double hitRadius = 36;

    for (int i = 0; i < 9; i++) {
      final int row = i ~/ 3;
      final int column = i % 3;
      final Offset center = Offset(column * 75.0 + 38, row * 75.0 + 23);

      if ((localPosition - center).distance <= hitRadius) {
        return i;
      }
    }

    return null;
  }

  bool get isPinMode => mode.value == LockMode.pin;

  bool get isPatternMode => mode.value == LockMode.pattern;

  bool get isPinComplete => pin.value.length == pinLength;

  bool get isPatternComplete => selectedPattern.length >= minimumPatternLength;

  List<int> _convertPatternToIntList(dynamic value) {
    if (value is! List) {
      return <int>[];
    }

    return value
        .map<int?>((element) {
          if (element is int) {
            return element;
          }

          return int.tryParse(element.toString());
        })
        .whereType<int>()
        .toList();
  }

  bool _listEquals(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    for (int i = 0; i < first.length; i++) {
      if (first[i] != second[i]) {
        return false;
      }
    }

    return true;
  }

  void resetUnlockInput() {
    clearPin();
    clearPattern();

    debugPrint('PRIVATE LOCK INPUT RESET');
  }

  Future<void> saveSecurityQuestion({
    required String question,
    required String answer,
  }) async {
    await GetStorageData.saveString(securityQuestionKey, question);

    await GetStorageData.saveString(securityAnswerKey, answer.trim());

    debugPrint('SECURITY QUESTION SAVED: $question');
  }

  String? get savedSecurityQuestion {
    final value = GetStorageData.readString(securityQuestionKey);

    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    return value.toString();
  }

  String get controllerAnswerForEdit {
    final dynamic value = GetStorageData.readString(securityAnswerKey);

    return value?.toString() ?? '';
  }

  bool verifySecurityAnswer({
    required String question,
    required String answer,
  }) {
    final dynamic savedQuestion = GetStorageData.readString(
      securityQuestionKey,
    );

    final dynamic savedAnswer = GetStorageData.readString(securityAnswerKey);

    if (savedQuestion == null || savedAnswer == null) {
      return false;
    }

    final String storedQuestion = savedQuestion.toString().trim();

    final String storedAnswer = savedAnswer.toString().trim();

    final String enteredQuestion = question.trim();

    final String enteredAnswer = answer.trim();

    return storedQuestion == enteredQuestion && storedAnswer == enteredAnswer;
  }

  Future<void> resetConfiguredLock() async {
    await GetStorageData.removeData(pinKey);
    await GetStorageData.removeData(patternKey);
    await GetStorageData.removeData(lockModeKey);
    await GetStorageData.removeData(GetStorageData.decoyPinKey);

    clearPin();
    clearPattern();
    pendingPin.value = '';
    isConfirmingPin.value = false;

    mode.value = LockMode.pin;

    hasConfiguredLock.value = false;

    debugPrint('PRIVATE LOCK RESET SUCCESSFULLY');

    debugPrint('SECURITY QUESTION PRESERVED');
  }

  void reset() {
    pin.value = '';

    selectedPattern.clear();

    currentFingerPosition.value = null;
  }

  void reloadLockMode() {
    reset();

    loadSavedLockMode();
  }
}
