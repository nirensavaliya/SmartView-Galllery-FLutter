import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';

class FileOperationService {
  static bool get deleteEmptyFolders {
    return GetStorageData.readBoolean(
      GetStorageData.deleteEmptyFolders,
      defaultValue: true,
    );
  }

  static bool get keepLastModified {
    return GetStorageData.readBoolean(
      GetStorageData.keepLastModified,
      defaultValue: true,
    );
  }

static Future<File?> copyFile({
    required File sourceFile,
    required String destinationPath,
  }) async {
    try {
      final DateTime oldLastModified =
      await sourceFile.lastModified();

      final File destinationFile =
      await sourceFile.copy(destinationPath);

      if (keepLastModified) {
        await destinationFile.setLastModified(
          oldLastModified,
        );
      }

      debugPrint(
        "FILE COPIED => ${destinationFile.path}",
      );

      return destinationFile;
    } catch (e) {
      debugPrint(
        "Copy File Error => $e",
      );

      return null;
    }
  }
  static Future<File?> moveFile({
    required File sourceFile,
    required String destinationPath,
  }) async {
    try {
      final DateTime oldLastModified =
      await sourceFile.lastModified();

      final File destinationFile =
      await sourceFile.rename(destinationPath);

      if (keepLastModified) {
        await destinationFile.setLastModified(
          oldLastModified,
        );
      }

      debugPrint(
        "FILE MOVED => ${destinationFile.path}",
      );

      return destinationFile;
    } catch (e) {
      debugPrint(
        "Move File Error => $e",
      );

      return null;
    }
  }

static Future<File?> renameFile({
    required File sourceFile,
    required String newPath,
  }) async {
    try {
      final DateTime oldLastModified =
      await sourceFile.lastModified();

      final File renamedFile =
      await sourceFile.rename(newPath);

      if (keepLastModified) {
        await renamedFile.setLastModified(
          oldLastModified,
        );
      }

      debugPrint(
        "FILE RENAMED => ${renamedFile.path}",
      );

      return renamedFile;
    } catch (e) {
      debugPrint(
        "Rename File Error => $e",
      );

      return null;
    }
  }

static Future<void> deleteEmptyParentFolder(
      Directory directory,
      ) async {
    if (!deleteEmptyFolders) {
      return;
    }

    try {
      if (!await directory.exists()) {
        return;
      }

      final entities = await directory
          .list(
        followLinks: false,
      )
          .toList();

      if (entities.isEmpty) {
        await directory.delete();

        debugPrint(
          "EMPTY FOLDER DELETED => ${directory.path}",
        );
      }
    } catch (e) {
      debugPrint(
        "Delete Empty Folder Error => $e",
      );
    }
  }
}