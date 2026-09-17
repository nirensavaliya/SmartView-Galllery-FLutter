import 'dart:convert';

import 'package:get_storage/get_storage.dart';
class GetStorageData{

  static String photosGridColumns = "photosGridColumns";
  static String recycleBin = "RecycleBin";
  static String customAlbums = "CustomAlbums";
  static String memoryNames = "MemoryNames";
  static String deletedMemories = "DeletedMemories";
  static String memoryCovers = "MemoryCovers";

  /// <<< To save object data --------- >>>
  static saveString(String key, value) async {
    final box = GetStorage();
    return box.write(key, value);
  }

  /// <<< To read object data --------- >>>
  static readString(String key) {
    final box = GetStorage();
    if (box.hasData(key)) {
      return box.read(key);
    } else {
      return null;
    }
  }

  /// <<< To save boolean data --------- >>>
  static Future<void> saveBoolean(String key, bool value) async {
    final box = GetStorage();
    return box.write(key, value);
  }

  /// <<< To read boolean data --------- >>>
  static bool readBoolean(String key) {
    final box = GetStorage();
    return box.read<bool>(key) ?? false;
  }

  /// <<< To remove data --------- >>>
  static removeData(String key) async {
    final box = GetStorage();
    return box.remove(key);
  }

  /// <<< To Store Key data --------- >>>
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
