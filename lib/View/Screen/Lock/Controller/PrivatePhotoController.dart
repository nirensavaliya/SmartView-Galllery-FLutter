import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class PrivateLockController extends GetxController {

  final RxString mode = ''.obs;
  final RxString enteredPin = ''.obs;
  final RxList<int> enteredPattern = <int>[].obs;
  final Rx<Offset?> fingerPosition = Rx<Offset?>(null);
  final List<GlobalKey> patternKeys =
  List.generate(9, (_) => GlobalKey());
  final RxBool isLoading = true.obs;
  final RxList<File> privateFiles = <File>[].obs;
  static const String lockModeKey = 'private_lock_mode';
  static const String pinKey = 'private_lock_pin';
  static const String patternKey = 'private_lock_pattern';
  static const String securityQuestionKey = 'private_security_question';
  static const String securityAnswerKey = 'private_security_answer';
  static const int pinLength = 4;
  static const int minimumPatternLength = 4;

@override
  void onInit() {
    super.onInit();
    loadLockMode();
    refreshPrivateFiles();
  }

Future<Directory> _getPrivateDirectory() async {
    final Directory appDirectory =
    await getApplicationDocumentsDirectory();

    final Directory privateDirectory =
    Directory('${appDirectory.path}/Hidden');

    if (!await privateDirectory.exists()) {
      await privateDirectory.create(recursive: true);
    }

    return privateDirectory;
  }

Future<void> refreshPrivateFiles() async {
    try {
      isLoading.value = true;

      final Directory directory =
      await _getPrivateDirectory();

      final List<FileSystemEntity> entities =
      await directory
          .list(
        recursive: false,
        followLinks: false,
      )
          .toList();

      final List<File> files = [];

      for (final FileSystemEntity entity in entities) {
        if (entity is File) {
          files.add(entity);
        }
      }

      files.sort(
            (File a, File b) {
          return b
              .lastModifiedSync()
              .compareTo(a.lastModifiedSync());
        },
      );

      privateFiles.assignAll(files);
    } catch (e) {
      debugPrint(
        'PRIVATE FILE LOAD ERROR: $e',
      );

      privateFiles.clear();
    } finally {
      isLoading.value = false;
    }
  }

bool isImage(File file) {
    final String extension =
    file.path.split('.').last.toLowerCase();

    const List<String> imageExtensions = [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'heic',
      'heif',
      'tif',
      'tiff',
    ];

    return imageExtensions.contains(extension);
  }

  bool isVideo(File file) {
    final String extension =
    file.path.split('.').last.toLowerCase();

    const List<String> videoExtensions = [
      'mp4',
      'mov',
      'm4v',
      'avi',
      'mkv',
      'webm',
      '3gp',
      '3gpp',
    ];

    return videoExtensions.contains(extension);
  }

Future<void> deletePrivateFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }

      privateFiles.removeWhere(
            (File item) => item.path == file.path,
      );

      privateFiles.refresh();

      AppToast.show('File deleted successfully');
    } catch (e) {
      debugPrint(
        'DELETE PRIVATE FILE ERROR: $e',
      );

      AppToast.show('Unable to delete file');
    }
  }

void loadLockMode() {
    final dynamic savedMode =
    GetStorageData.readString(lockModeKey);

    mode.value = savedMode?.toString() ?? '';

    debugPrint(
      'PRIVATE LOCK MODE: ${mode.value}',
    );
  }

  bool get isPin => mode.value == 'pin';

  bool get isPattern => mode.value == 'pattern';

  bool get hasSavedPin {
    final dynamic savedPin = GetStorageData.readString(pinKey);
    return savedPin != null && savedPin.toString().trim().length == pinLength;
  }

  bool get hasLock => isPin || isPattern;

void addPin(String value) {
    if (enteredPin.value.length >= pinLength) {
      return;
    }

    enteredPin.value += value;
  }

  void removePin() {
    if (enteredPin.value.isEmpty) {
      return;
    }

    enteredPin.value =
        enteredPin.value.substring(
          0,
          enteredPin.value.length - 1,
        );
  }

  void clearPin() {
    enteredPin.value = '';
  }

bool verifyPinValue(String value) {
    final dynamic savedPinValue =
    GetStorageData.readString(pinKey);

    final String savedPin =
        savedPinValue?.toString() ?? '';

    if (savedPin.isEmpty) {
      return false;
    }

    return value == savedPin;
  }

Future<bool> savePinValue(String newPin) async {
    if (newPin.length != pinLength) {
      return false;
    }

    try {
      await GetStorageData.saveString(
        pinKey,
        newPin,
      );

      await GetStorageData.saveString(
        lockModeKey,
        'pin',
      );

      mode.value = 'pin';

      debugPrint(
        'PRIVATE PIN UPDATED',
      );

      return true;
    } catch (e) {
      debugPrint(
        'SAVE NEW PIN ERROR: $e',
      );

      return false;
    }
  }

void startPattern(Offset position) {
    enteredPattern.clear();

    fingerPosition.value = position;

    final int? index =
    getPointFromPosition(position);

    if (index != null) {
      enteredPattern.add(index);
    }
  }

  void updatePattern(Offset position) {
    fingerPosition.value = position;

    final int? index =
    getPointFromPosition(position);

    if (index == null) {
      return;
    }

    if (!enteredPattern.contains(index)) {
      enteredPattern.add(index);
    }
  }

  void finishPatternInput() {
    fingerPosition.value = null;
  }

  void clearPattern() {
    enteredPattern.clear();

    fingerPosition.value = null;
  }

int? getPointFromPosition(
      Offset globalPosition,
      ) {
    const double hitRadius = 35;

    for (int i = 0; i < patternKeys.length; i++) {
      final BuildContext? context =
          patternKeys[i].currentContext;

      if (context == null) {
        continue;
      }

      final RenderObject? renderObject =
      context.findRenderObject();

      if (renderObject is! RenderBox) {
        continue;
      }

      final RenderBox box = renderObject;

      if (!box.hasSize) {
        continue;
      }

      final Offset center =
      box.localToGlobal(
        box.size.center(
          Offset.zero,
        ),
      );

      final double distance =
          (globalPosition - center).distance;

      if (distance <= hitRadius) {
        return i;
      }
    }

    return null;
  }

List<int> getSavedPattern() {
    final dynamic savedObject =
    GetStorageData.readObject(patternKey);

    return _convertPatternToIntList(
      savedObject,
    );
  }

bool verifyPatternValue(
      List<int> value,
      ) {
    final List<int> savedPattern =
    getSavedPattern();

    if (savedPattern.isEmpty) {
      return false;
    }

    return _listEquals(
      value,
      savedPattern,
    );
  }

Future<bool> savePatternValue(
      List<int> newPattern,
      ) async {
    if (newPattern.length <
        minimumPatternLength) {
      return false;
    }

    try {
      await GetStorageData.saveObject(
        patternKey,
        List<int>.from(newPattern),
      );

      await GetStorageData.saveString(
        lockModeKey,
        'pattern',
      );

      mode.value = 'pattern';

      debugPrint(
        'PRIVATE PATTERN UPDATED: '
            '${newPattern.join('-')}',
      );

      return true;
    } catch (e) {
      debugPrint(
        'SAVE NEW PATTERN ERROR: $e',
      );

      return false;
    }
  }

Future<void> saveSecurityQuestion({
    required String question,
    required String answer,
  }) async {
    await GetStorageData.saveString(
      securityQuestionKey,
      question,
    );

    await GetStorageData.saveString(
      securityAnswerKey,
      answer.trim(),
    );

    debugPrint(
      'SECURITY QUESTION SAVED: $question',
    );
  }

  String? get savedSecurityQuestion {
    final dynamic value =
    GetStorageData.readString(
      securityQuestionKey,
    );

    if (value == null ||
        value.toString().trim().isEmpty) {
      return null;
    }

    return value.toString();
  }

  String get savedSecurityAnswer {
    final dynamic value =
    GetStorageData.readString(
      securityAnswerKey,
    );

    return value?.toString() ?? '';
  }

  bool verifySecurityAnswer({
    required String question,
    required String answer,
  }) {
    final dynamic savedQuestion =
    GetStorageData.readString(
      securityQuestionKey,
    );

    final dynamic savedAnswer =
    GetStorageData.readString(
      securityAnswerKey,
    );

    if (savedQuestion == null ||
        savedAnswer == null) {
      return false;
    }

    return savedQuestion
        .toString()
        .trim() ==
        question.trim() &&
        savedAnswer
            .toString()
            .trim() ==
            answer.trim();
  }

Future<void> resetConfiguredLock() async {
    await GetStorageData.removeData(
      pinKey,
    );

    await GetStorageData.removeData(
      patternKey,
    );

    await GetStorageData.removeData(
      lockModeKey,
    );

clearPin();

    clearPattern();

    mode.value = '';

    debugPrint(
      'PRIVATE LOCK RESET SUCCESSFULLY',
    );

    debugPrint(
      'SECURITY QUESTION PRESERVED',
    );
  }

void reset() {
    enteredPin.value = '';

    enteredPattern.clear();

    fingerPosition.value = null;
  }

  void reloadLockMode() {
    reset();

    loadLockMode();
  }

List<int> _convertPatternToIntList(
      dynamic value,
      ) {
    if (value is! List) {
      return <int>[];
    }

    return value
        .map<int?>(
          (element) {
        if (element is int) {
          return element;
        }

        return int.tryParse(
          element.toString(),
        );
      },
    )
        .whereType<int>()
        .toList();
  }

  bool _listEquals(
      List<int> first,
      List<int> second,
      ) {
    if (first.length != second.length) {
      return false;
    }

    for (int i = 0;
    i < first.length;
    i++) {
      if (first[i] != second[i]) {
        return false;
      }
    }

    return true;
  }
}