import 'dart:convert';

import 'package:get_storage/get_storage.dart';

class GetStorageData {
  static String photosGridColumns = "photosGridColumns";
  static String albumsGridColumns = "albumsGridColumns";
  static String recycleBin = "RecycleBin";
  static String customAlbums = "CustomAlbums";
  static String memoryNames = "MemoryNames";
  static String deletedMemories = "DeletedMemories";
  static String memoryCovers = "MemoryCovers";
  static String customMemories = "CustomMemories";
  static const String darkMode = "darkMode";
  static const String deleteEmptyFolders = "deleteEmptyFolders";
  static const String keepLastModified = "keepLastModified";
  static const String privateSecurityQuestion = "privateSecurityQuestion";
  static const String privateSecurityAnswer = "privateSecurityAnswer";
  static const String privateResetEnabled = "privateResetEnabled";
  static const String securityQuestionKey = 'private_security_question';
  static const String decoyPinKey = 'private_decoy_pin';
  static const String securityAnswerKey = 'private_security_answer';
  static const String privateLockModeKey = 'private_lock_mode';
  static const String privateLockPinKey = 'private_lock_pin';
  static const String privateLockPatternKey = 'private_lock_pattern';
  static saveString(String key, value) async {
    final box = GetStorage();
    return box.write(key, value);
  }

  static readString(String key) {
    final box = GetStorage();
    if (box.hasData(key)) {
      return box.read(key);
    } else {
      return null;
    }
  }

  static Future<void> saveBoolean(String key, bool value) async {
    final box = GetStorage();
    return box.write(key, value);
  }

  static bool readBoolean(String key, {bool defaultValue = false}) {
    final box = GetStorage();

    return box.read<bool>(key) ?? defaultValue;
  }

  static removeData(String key) async {
    final box = GetStorage();
    return box.remove(key);
  }

  static bool containKey(String key) {
    final box = GetStorage();
    return box.hasData(key);
  }

  static Future<void> saveObject(String key, value) async {
    final box = GetStorage();
    String allData = jsonEncode(value);
    await box.write(key, allData);
  }

  static readObject(String key) {
    final box = GetStorage();
    final result = box.read(key);

    if (result == null) {
      return null;
    }

    return jsonDecode(result);
  }
}
