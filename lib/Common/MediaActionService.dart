import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

class MediaActionService {


  static Future<void> share(
      AssetEntity asset,
      ) async {
    final file = await asset.file;

    if (file == null || !file.existsSync()) {
      throw Exception("File not found");
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path),
        ],
      ),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  static Future<void> delete(
      AssetEntity asset,
      ) async {
    await PhotoManager.editor.deleteWithIds([
      asset.id,
    ]);
  }


  static Future<bool> copyTo(
      AssetEntity asset,
      ) async {
    final source = await asset.file;

    if (source == null || !source.existsSync()) {
      throw Exception("File not found");
    }

    final directory =
    await FilePicker.getDirectoryPath(
      dialogTitle: "Copy to",
    );

    if (directory == null) {
      return false;
    }

    final fileName =
        asset.title ??
            source.path.split(Platform.pathSeparator).last;

    final destination = File(
      "$directory${Platform.pathSeparator}$fileName",
    );

    await source.copy(destination.path);

    return true;
  }

  // =========================================================
  // MOVE
  // =========================================================

  static Future<bool> moveTo(
      AssetEntity asset,
      ) async {
    final source = await asset.file;

    if (source == null || !source.existsSync()) {
      throw Exception("File not found");
    }

    final directory =
    await FilePicker.getDirectoryPath(
      dialogTitle: "Move to",
    );

    if (directory == null) {
      return false;
    }

    final fileName =
        asset.title ??
            source.path.split(Platform.pathSeparator).last;

    final destination = File(
      "$directory${Platform.pathSeparator}$fileName",
    );

    await source.rename(destination.path);

    return true;
  }

  // =========================================================
  // RENAME
  // =========================================================

  static Future<void> rename(
      AssetEntity asset,
      String newName,
      ) async {
    final source = await asset.file;

    if (source == null || !source.existsSync()) {
      throw Exception("File not found");
    }

    String name = newName.trim();

    if (name.isEmpty) {
      throw Exception("Name cannot be empty");
    }

    final extension = _extension(source.path);

    if (extension.isNotEmpty &&
        !name.toLowerCase().endsWith(
          extension.toLowerCase(),
        )) {
      name += extension;
    }

    final destination = File(
      "${source.parent.path}"
          "${Platform.pathSeparator}"
          "$name",
    );

    if (destination.path != source.path &&
        destination.existsSync()) {
      throw Exception("A file with this name already exists");
    }

    await source.rename(destination.path);
  }

  // =========================================================
  // HIDE
  // =========================================================

  static Future<void> hide(
      AssetEntity asset,
      ) async {
    final source = await asset.file;

    if (source == null || !source.existsSync()) {
      throw Exception("File not found");
    }

    final hiddenDirectory =
    await _hiddenDirectory();

    final fileName =
        asset.title ??
            source.path.split(Platform.pathSeparator).last;

    final destination = File(
      "${hiddenDirectory.path}"
          "${Platform.pathSeparator}"
          "${DateTime.now().millisecondsSinceEpoch}_$fileName",
    );

    // Pehle private storage me copy.
    await source.copy(destination.path);

    // Copy successful hone ke baad Gallery se remove.
    await PhotoManager.editor.deleteWithIds([
      asset.id,
    ]);
  }

  // =========================================================
  // GET HIDDEN FILES
  // =========================================================

  static Future<List<File>> getHiddenFiles() async {
    final directory =
    await _hiddenDirectory();

    if (!directory.existsSync()) {
      return [];
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .toList();

    files.sort(
          (a, b) => b.lastModifiedSync().compareTo(
        a.lastModifiedSync(),
      ),
    );

    return files;
  }

  // =========================================================
  // UNHIDE
  // =========================================================

  static Future<AssetEntity> unhide(
      File hiddenFile,
      ) async {
    if (!hiddenFile.existsSync()) {
      throw Exception("Hidden file not found");
    }

    final extension =
    _extension(hiddenFile.path).toLowerCase();

    final bytes =
    await hiddenFile.readAsBytes();

    AssetEntity? asset;

    if ([
      ".jpg",
      ".jpeg",
      ".png",
      ".webp",
      ".heic",
      ".heif",
    ].contains(extension)) {
      asset = await PhotoManager.editor.saveImage(
        bytes,
        filename: _fileName(hiddenFile.path),
        title: _fileName(hiddenFile.path),
      );
    } else if ([
      ".mp4",
      ".mov",
      ".mkv",
      ".avi",
      ".webm",
    ].contains(extension)) {
      asset = await PhotoManager.editor.saveVideo(
        hiddenFile,
        title: _fileName(hiddenFile.path),
      );
    } else {
      throw Exception(
        "Unsupported hidden media type",
      );
    }

    await hiddenFile.delete();

    return asset;
  }

  // =========================================================
  // SAVE EDITED IMAGE
  // =========================================================

  static Future<AssetEntity> saveEditedImage(
      Uint8List bytes, {
        required String name,
      }) async {
    String fileName = name.trim();

    if (fileName.isEmpty) {
      fileName = "Edited_Image.jpg";
    }

    if (!fileName.toLowerCase().endsWith(".jpg") &&
        !fileName.toLowerCase().endsWith(".jpeg") &&
        !fileName.toLowerCase().endsWith(".png")) {
      fileName = "$fileName.jpg";
    }

    return await PhotoManager.editor.saveImage(
      bytes,
      filename: fileName,
      title: fileName,
    );
  }

  // =========================================================
  // PRIVATE DIRECTORY
  // =========================================================

  static Future<Directory> _hiddenDirectory() async {
    final appDirectory =
    await getApplicationDocumentsDirectory();

    final directory = Directory(
      "${appDirectory.path}"
          "${Platform.pathSeparator}"
          "hidden_media",
    );

    if (!directory.existsSync()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static String _extension(String path) {
    final index = path.lastIndexOf('.');

    if (index == -1) {
      return '';
    }

    return path.substring(index);
  }

  static String _fileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}