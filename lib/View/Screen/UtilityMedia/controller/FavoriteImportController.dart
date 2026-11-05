import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/View/Screen/UtilityMedia/controller/UtilityMediaController.dart';

class FavoriteImportController extends GetxController {
  final RxList<AssetEntity> media =
      <AssetEntity>[].obs;

  final RxSet<String> selectedIds =
      <String>{}.obs;

  final RxBool isLoading = true.obs;

  AssetPathEntity? _allPath;

  int _page = 0;

  static const int _pageSize = 100;

  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    loadMedia();
  }

  Future<void> loadMedia() async {
    if (isLoading.value) {
    } else {
      isLoading.value = true;
    }

    try {
      media.clear();
      selectedIds.clear();

      _page = 0;
      _hasMore = true;

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
        _allPath = null;
        return;
      }

      _allPath = albums.first;

      await loadNextPage();
    } catch (e) {
      debugPrint(
        'FAVORITE IMPORT LOAD ERROR: $e',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadNextPage() async {
    if (_allPath == null || !_hasMore) {
      return;
    }

    try {
      final assets =
      await _allPath!.getAssetListPaged(
        page: _page,
        size: _pageSize,
      );

      if (assets.isEmpty) {
        _hasMore = false;
        return;
      }

      final existingIds =
      media.map((e) => e.id).toSet();

      for (final asset in assets) {
        if (!existingIds.contains(asset.id)) {
          media.add(asset);
        }
      }

      _page++;

      if (assets.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint(
        'FAVORITE IMPORT PAGE ERROR: $e',
      );
    }
  }

  void loadMoreIfNeeded(int index) {
    if (index >= media.length - 15) {
      loadNextPage();
    }
  }

  void toggleSelection(AssetEntity asset) {
    if (selectedIds.contains(asset.id)) {
      selectedIds.remove(asset.id);
    } else {
      selectedIds.add(asset.id);
    }

    selectedIds.refresh();
  }

  bool isSelected(AssetEntity asset) {
    return selectedIds.contains(asset.id);
  }

  void selectAll() {
    selectedIds.clear();

    for (final asset in media) {
      selectedIds.add(asset.id);
    }

    selectedIds.refresh();
  }

  void clearSelection() {
    selectedIds.clear();
    selectedIds.refresh();
  }

  Future<void> addSelectedToFavorites() async {
    final selected = media
        .where(
          (asset) => selectedIds.contains(asset.id),
    )
        .toList();

    if (selected.isEmpty) {
      return;
    }

    try {
      int addedCount = 0;
      final List<AssetEntity> added = <AssetEntity>[];

      for (final asset in selected) {
        if (asset.isFavorite) {
          added.add(asset);
          addedCount++;
          continue;
        }

        try {
          final AssetEntity updated = Platform.isIOS || Platform.isMacOS
              ? await PhotoManager.editor.darwin.favoriteAsset(
                  entity: asset,
                  favorite: true,
                )
              : await PhotoManager.editor.android.favoriteAsset(
                  entity: asset,
                  favorite: true,
                );
          added.add(updated);
          addedCount++;
        } catch (e) {
          debugPrint('ADD FAVORITE ITEM ERROR: $e');
        }
      }

      if (addedCount == 0) {
        AppToast.show('Allow the phone prompt to add favorites');
        return;
      }

      await _showOnFavoritesScreen(added);
      clearSelection();

      AppToast.show(
        '$addedCount item${addedCount == 1 ? '' : 's'} added to favorites',
      );
      Get.back();
    } catch (e) {
      debugPrint(
        'ADD FAVORITE ERROR: $e',
      );

      AppToast.show("Favorite Error: ${e.toString()}");
    }
  }

  Future<void> _showOnFavoritesScreen(List<AssetEntity> added) async {
    const String tag = 'favorites';
    if (!Get.isRegistered<UtilityMediaController>(tag: tag)) {
      return;
    }

    final UtilityMediaController favorites =
        Get.find<UtilityMediaController>(tag: tag);
    await favorites.refreshMedia();

    final Set<String> existing = favorites.media.map((asset) => asset.id).toSet();
    final List<AssetEntity> missing = added
        .where((asset) => !existing.contains(asset.id))
        .toList();
    if (missing.isNotEmpty) {
      favorites.media.insertAll(0, missing);
    }
  }
}