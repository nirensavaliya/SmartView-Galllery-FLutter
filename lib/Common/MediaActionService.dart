import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

class MediaActionService {
  static const MethodChannel _channel = MethodChannel('native_camera');

  static bool waitingForPermission = false;

  static bool? _canManageMedia;

  static Future<bool> ensureMediaManagement() async {
    if (!Platform.isAndroid) {
      return true;
    }
    if (_canManageMedia == true) {
      waitingForPermission = false;
      return true;
    }

    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'requestMediaManagement',
      );
      if (granted == true) {
        _canManageMedia = true;
        waitingForPermission = false;
        return true;
      }

      waitingForPermission = true;
      AppToast.show('Allow media management, then delete again');
      return false;
    } catch (_) {
      waitingForPermission = false;
      return true;
    }
  }

  static Future<List<String>> deleteIds(List<String> ids) async {
    if (ids.isEmpty) {
      return <String>[];
    }
    if (!await ensureMediaManagement()) {
      return <String>[];
    }
    return PhotoManager.editor.deleteWithIds(ids);
  }

  static Future<void> share(AssetEntity asset,) async {
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

  static Future<void> delete(AssetEntity asset,) async {
    await deleteIds([
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
    await source.copy(destination.path);
    final List<String> removed = await deleteIds([
      asset.id,
    ]);
    if (!removed.contains(asset.id) && await destination.exists()) {
      await destination.delete();
    }
  }

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