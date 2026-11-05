import 'dart:io';

import 'package:gallery_photos/View/Screen/CleanerScreen/Model/CleanerModel.dart';
import 'package:photo_manager/photo_manager.dart';

class CleanerService {

  Future<List<AssetEntity>> getAllAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth) {
      return [];
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );

    final List<AssetEntity> assets = [];

    for (final album in albums) {
      final count = await album.assetCountAsync;

      if (count <= 0) continue;

      final result = await album.getAssetListPaged(
        page: 0,
        size: count,
      );

      assets.addAll(result);
    }

    final Map<String, AssetEntity> unique = {};

    for (final asset in assets) {
      unique[asset.id] = asset;
    }

    return unique.values.toList();
  }

Future<List<CleanerItemData>> findLargeMedia(
      List<AssetEntity> assets,
      ) async {
    final List<CleanerItemData> result = [];

    for (final asset in assets) {
      final file = await asset.file;

      if (file == null) continue;

      final size = await file.length();

      if (size >= 20 * 1024 * 1024) {
        result.add(
          CleanerItemData(
            asset: asset,
            type: 'large',
            size: size,
          ),
        );
      }
    }

    return result;
  }

Future<List<CleanerItemData>> findScreenshots(
      List<AssetEntity> assets,
      ) async {
    final List<CleanerItemData> result = [];

    for (final asset in assets) {
      final title = asset.title?.toLowerCase() ?? '';

      if (title.contains('screenshot') ||
          title.contains('screen_shot') ||
          title.contains('screen-shot')) {
        final file = await asset.file;

        if (file == null) continue;

        result.add(
          CleanerItemData(
            asset: asset,
            type: 'screenshot',
            size: await file.length(),
          ),
        );
      }
    }

    return result;
  }
}