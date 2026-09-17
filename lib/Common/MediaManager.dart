import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class MediaManger {
  // =========================================================
  // ALL MEDIA - PHOTO + VIDEO MIX
  // =========================================================

  static Future<List<AssetEntity>> getAllMedia({
    int page = 0,
    int size = 100,
  }) async {
    PhotoManager.setIgnorePermissionCheck(true);

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

    final recent = albums.first;

    final assets = await recent.getAssetListPaged(
      page: page,
      size: size,
    );

    // Same AssetEntity ID ko ek hi baar return karo.
    final uniqueIds = <String>{};
    final uniqueAssets = <AssetEntity>[];

    for (final asset in assets) {
      if (uniqueIds.add(asset.id)) {
        uniqueAssets.add(asset);
      }
    }

    return uniqueAssets;
  }

  // =========================================================
  // GET ALL ALBUMS
  // =========================================================

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

  // =========================================================
  // GET RECENT ALBUM
  // =========================================================

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

  // =========================================================
  // VIDEO ALBUM
  // =========================================================

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

  // =========================================================
  // PHOTO ALBUM
  // =========================================================

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

  // =========================================================
  // FIND ALBUM BY NAME
  // =========================================================

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

  // =========================================================
  // FIND ALBUM CONTAINS NAME
  // =========================================================

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
}