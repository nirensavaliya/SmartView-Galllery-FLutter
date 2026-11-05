import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class MediaManger {
  static AssetPathEntity? _allPathCache;
  static DateTime? _allPathCachedAt;
  static const Duration _allPathTtl = Duration(seconds: 60);

  static Future<List<AssetEntity>> getAllMedia({
    int page = 0,
    int size = 100,
  }) async {
    PhotoManager.setIgnorePermissionCheck(true);

    AssetPathEntity? recent = _allPathCache;
    final DateTime? cachedAt = _allPathCachedAt;

    final bool canReuse = page > 0 &&
        recent != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _allPathTtl;

    if (!canReuse) {
      final filter = FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      );

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: true,
        filterOption: filter,
      );

      if (albums.isEmpty) {
        return [];
      }

      recent = albums.first;
      _allPathCache = recent;
      _allPathCachedAt = DateTime.now();
    }

    final assets = await recent.getAssetListPaged(
      page: page,
      size: size,
    );
    final uniqueIds = <String>{};
    final uniqueAssets = <AssetEntity>[];

    for (final asset in assets) {
      if (uniqueIds.add(asset.id)) {
        uniqueAssets.add(asset);
      }
    }

    return uniqueAssets;
  }

  static Future<List<AssetPathEntity>> getAlbums() async {
    PhotoManager.setIgnorePermissionCheck(true);

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      ),
    );

    for (final album in albums) {
      debugPrint(
        "ALBUM => name: ${album.name}, id: ${album.id}",
      );
    }

    return albums;
  }

  static Future<AssetPathEntity?> getRecentAlbum() async {
    PhotoManager.setIgnorePermissionCheck(true);

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      ),
    );

    if (albums.isEmpty) {
      return null;
    }

    return albums.first;
  }

static Future<AssetPathEntity?> getVideoAlbum() async {
    PhotoManager.setIgnorePermissionCheck(true);

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      ),
    );

    if (albums.isEmpty) {
      return null;
    }

    return albums.first;
  }

  static Future<AssetPathEntity?> getPhotoAlbum() async {
    PhotoManager.setIgnorePermissionCheck(true);

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      ),
    );

    if (albums.isEmpty) {
      return null;
    }

    return albums.first;
  }

static Future<AssetPathEntity?> findAlbum(String name) async {
    final albums = await getAlbums();

    try {
      return albums.firstWhere(
            (album) =>
        album.name.toLowerCase().trim() ==
            name.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<AssetPathEntity?> findAlbumContains(String name) async {
    final albums = await getAlbums();

    try {
      return albums.firstWhere(
            (album) =>
            album.name.toLowerCase().contains(name.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

static Future<MediaUtilityCounts> getScreenshotAndVideoCounts() async {
    PhotoManager.setIgnorePermissionCheck(true);

    int screenshots = 0;
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: false,
      onlyAll: false,
    );
    for (final AssetPathEntity album in albums) {
      if (album.name.toLowerCase().contains('screenshot')) {
        screenshots += await album.assetCountAsync;
      }
    }

    int videos = 0;
    final List<AssetPathEntity> videoAlbums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
      onlyAll: true,
    );
    if (videoAlbums.isNotEmpty) {
      videos = await videoAlbums.first.assetCountAsync;
    }

    return MediaUtilityCounts(
      videos: videos,
      screenshots: screenshots,
      favorites: 0,
      gifs: 0,
      livePhotos: 0,
    );
  }

static Future<MediaUtilityCounts> getUtilityCounts() async {
    PhotoManager.setIgnorePermissionCheck(true);

    final MediaUtilityCounts quick = await getScreenshotAndVideoCounts();
    final int videos = quick.videos;
    final int screenshots = quick.screenshots;
    int favorites = 0;
    int gifs = 0;
    int livePhotos = 0;

final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      ),
    );

    if (albums.isEmpty) {
      return quick;
    }

    final recent = albums.first;

    final totalCount = await recent.assetCountAsync;

    const pageSize = 500;

    for (int page = 0; page * pageSize < totalCount; page++) {
      final assets = await recent.getAssetListPaged(
        page: page,
        size: pageSize,
      );

      if (assets.isEmpty) {
        break;
      }

      for (final asset in assets) {
        if (asset.isFavorite) {
          favorites++;
        }

        final mimeType = asset.mimeType?.toLowerCase() ?? '';
        final title = asset.title?.toLowerCase() ?? '';

        if (mimeType == 'image/gif' || title.endsWith('.gif')) {
          gifs++;
        }
        if (asset.isLivePhoto) {
          livePhotos++;
        }
      }
    }

    return MediaUtilityCounts(
      videos: videos,
      screenshots: screenshots,
      favorites: favorites,
      gifs: gifs,
      livePhotos: livePhotos,
    );
  }

static Future<bool> toggleFavorite(AssetEntity asset) async {
    try {
      final bool newFavoriteStatus = !asset.isFavorite;

      final bool result = await PhotoManager.plugin.favoriteAsset(
        asset.id,
        newFavoriteStatus,
      );

      debugPrint(
        'Favorite changed => ${asset.id} : $result',
      );

      return result;
    } catch (e, stackTrace) {
      debugPrint('Favorite Error: $e');
      debugPrint('$stackTrace');
      return false;
    }
  }

}

class MediaUtilityCounts {
  final int videos;
  final int screenshots;
  final int favorites;
  final int gifs;
  final int livePhotos;

  const MediaUtilityCounts({
    required this.videos,
    required this.screenshots,
    required this.favorites,
    required this.gifs,
    required this.livePhotos,
  });

  int get gifsAndLivePhotos => gifs + livePhotos;
}