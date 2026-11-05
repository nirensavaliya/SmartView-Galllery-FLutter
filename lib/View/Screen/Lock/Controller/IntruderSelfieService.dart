import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class IntruderSelfieService {
  IntruderSelfieService._();

  static bool _busy = false;

  static Future<void> ensureCameraPermission() async {
    try {
      final PermissionStatus status = await Permission.camera.status;
      if (status.isDenied) {
        await Permission.camera.request();
      }
    } catch (e) {
      debugPrint('INTRUDER SELFIE PERMISSION ERROR: $e');
    }
  }

  static Future<Directory> getFolder() async {
    final Directory baseDir = await getApplicationDocumentsDirectory();
    final Directory folder = Directory('${baseDir.path}/intruder_selfies');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    return folder;
  }

  static Future<List<File>> listPhotos() async {
    try {
      final Directory folder = await getFolder();
      final List<File> files = [];

      await for (final FileSystemEntity entity in folder.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          files.add(entity);
        }
      }

      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (e) {
      debugPrint('INTRUDER SELFIE LIST ERROR: $e');
      return <File>[];
    }
  }

  static Future<void> capture() async {
    if (_busy) return;
    _busy = true;

    CameraController? cameraController;

    try {
      if (!await Permission.camera.isGranted) {
        debugPrint('INTRUDER SELFIE: camera permission not granted');
        return;
      }

      final List<CameraDescription> cameras = await availableCameras();

      CameraDescription? front;
      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          front = camera;
          break;
        }
      }

      if (front == null) {
        debugPrint('INTRUDER SELFIE: no front camera found');
        return;
      }

      cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController.initialize();

      try {
        await cameraController.setFlashMode(FlashMode.off);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 400));

      final XFile shot = await cameraController.takePicture();

      final Directory folder = await getFolder();

      final String savedPath =
          '${folder.path}/intruder_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await File(shot.path).copy(savedPath);

      try {
        await File(shot.path).delete();
      } catch (_) {}

      debugPrint('INTRUDER SELFIE SAVED: $savedPath');
    } catch (e) {
      debugPrint('INTRUDER SELFIE ERROR: $e');
    } finally {
      try {
        await cameraController?.dispose();
      } catch (_) {}
      _busy = false;
    }
  }
}
