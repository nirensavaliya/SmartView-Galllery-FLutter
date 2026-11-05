import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotoViewController.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/Common/MediaActionService.dart';

class PlacesController extends GetxController {
  final RxList<PlaceGroup> places = <PlaceGroup>[].obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  bool get isSelectionMode => selectedIds.isNotEmpty;
  final RxInt gridColumns = 2.obs;
  int _startGridColumns = 2;
  final RxBool isLoading = false.obs;
  ForYouController? _forYouController;
  Worker? _placesWorker;
  Worker? _loadingWorker;
  final RxBool isDragSelecting = false.obs;

  AssetEntity? _dragStartAsset;
  Offset? _dragStartPosition;

  void startDragSelection(AssetEntity asset, Offset position) {
    _dragStartAsset = asset;
    _dragStartPosition = position;
    isDragSelecting.value = true;
  }

  void selectDuringDrag(AssetEntity asset) {
    if (!isDragSelecting.value) {
      return;
    }
    if (selectedIds.contains(asset.id)) {
      return;
    }
    selectedIds.add(asset.id);
    selectedIds.refresh();
  }

  void updateDragSelection(Offset position) {
    if (!isDragSelecting.value) {
      return;
    }
    _dragStartPosition = position;
  }

  void endDragSelection() {
    isDragSelecting.value = false;
    _dragStartAsset = null;
    _dragStartPosition = null;
  }

  @override
  void onInit() {
    super.onInit();

    _bindForYouController();
  }

  void _bindForYouController() {
    try {
      if (!Get.isRegistered<ForYouController>()) {
        debugPrint('PLACES => ForYouController not registered');
        return;
      }

      _forYouController = Get.find<ForYouController>();

      final ForYouController controller = _forYouController!;

      places.assignAll(controller.places);

      isLoading.value = controller.isLoading.value;

      _placesWorker = ever<List<PlaceGroup>>(controller.places, (value) {
        places.assignAll(value);
      });

      _loadingWorker = ever<bool>(controller.isLoading, (loading) {
        isLoading.value = loading;

        if (!loading) {
          places.assignAll(controller.places);
        }
      });
    } catch (e, stack) {
      debugPrint('PLACES BIND ERROR => $e');

      debugPrint(stack.toString());

      isLoading.value = false;
    }
  }

  Future<void> refreshPlaces() async {
    try {
      if (_forYouController == null) {
        if (!Get.isRegistered<ForYouController>()) {
          return;
        }

        _forYouController = Get.find<ForYouController>();
      }

      final ForYouController controller = _forYouController!;

      places.assignAll(controller.places);
    } catch (e) {
      debugPrint('PLACES REFRESH ERROR => $e');
    }
  }

  void onGridScaleStart() {
    _startGridColumns = gridColumns.value;
  }

  void onGridScaleUpdate(double scale) {
    if (scale == 1.0) {
      return;
    }

    int newGridColumns = _startGridColumns;

    if (scale < 0.90) {
      newGridColumns = _startGridColumns + 1;
    }

    if (scale < 0.78) {
      newGridColumns = _startGridColumns + 2;
    }

    if (scale < 0.66) {
      newGridColumns = _startGridColumns + 3;
    }

    if (scale > 1.10) {
      newGridColumns = _startGridColumns - 1;
    }

    if (scale > 1.25) {
      newGridColumns = _startGridColumns - 2;
    }

    if (scale > 1.40) {
      newGridColumns = _startGridColumns - 3;
    }

    newGridColumns = newGridColumns.clamp(2, 4);

    if (newGridColumns == gridColumns.value) {
      return;
    }

    gridColumns.value = newGridColumns;

    debugPrint('PLACES GRID => ${gridColumns.value}');
  }

  void startSelection(AssetEntity asset) {
    selectedIds.clear();

    selectedIds.add(asset.id);

    selectedIds.refresh();
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

  void clearSelection() {
    selectedIds.clear();
    selectedIds.refresh();
  }

  List<AssetEntity> getSelectedAssets(List<AssetEntity> allAssets) {
    return allAssets.where((asset) => selectedIds.contains(asset.id)).toList();
  }

  AssetEntity? getFirstSelected(List<AssetEntity> allAssets) {
    for (final asset in allAssets) {
      if (selectedIds.contains(asset.id)) {
        return asset;
      }
    }

    return null;
  }

  void increaseGridColumns() {
    if (gridColumns.value < 4) {
      gridColumns.value++;
    }
  }

  void decreaseGridColumns() {
    if (gridColumns.value > 2) {
      gridColumns.value--;
    }
  }

  PhotoViewController? _getSelectedPhotoController() {
    if (selectedIds.isEmpty) {
      return null;
    }

    final String selectedId = selectedIds.first;

    AssetEntity? selectedAsset;

    for (final place in places) {
      for (final asset in place.assets) {
        if (asset.id == selectedId) {
          selectedAsset = asset;
          break;
        }
      }

      if (selectedAsset != null) {
        break;
      }
    }

    if (selectedAsset == null) {
      debugPrint("PLACES => Selected asset not found. ID: $selectedId");
      return null;
    }

    final List<AssetEntity> allPlaceAssets = places
        .expand((place) => place.assets)
        .toList();

    final PhotoViewController controller = PhotoViewController(
      selectedAsset,
      albumMedia: allPlaceAssets,
    );

    controller.initializePhotoView();

    return controller;
  }

  Future<void> shareSelected() async {
    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.sharePhoto();
  }

  Future<void> lockSelected() async {
    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.lockPhoto();
  }

  Future<void> copySelected() async {
    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.copyPhoto();
  }

  Future<void> moveSelected() async {
    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.movePhoto();
  }

  Future<void> renameSelected() async {
    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.renamePhoto();
  }

  Future<void> editSelected() async {
    final controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.editPhoto();
  }

  Future<void> setAsSelected() async {
    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.setAsWallpaper();
  }

  Future<void> resizeSelected() async {
    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.resizePhoto();
  }

  Future<void> infoSelected() async {
    final PhotoViewController? controller = _getSelectedPhotoController();

    if (controller == null) {
      return;
    }

    await controller.showDetails();
  }

  Future<void> deleteSelected(List<AssetEntity> allAssets) async {
    final selected = getSelectedAssets(allAssets);

    if (selected.isEmpty) {
      return;
    }

    try {
      final ids = selected.map((e) => e.id).toList();

      final deletedIds = await MediaActionService.deleteIds(ids);

      if (deletedIds.isNotEmpty) {
        for (final place in places) {
          place.assets.removeWhere((asset) => deletedIds.contains(asset.id));
        }

        places.refresh();
      }

      clearSelection();

      AppToast.show(
        "${deletedIds.length} item${deletedIds.length == 1 ? '' : 's'} deleted",
      );
    } catch (e) {
      debugPrint("Delete Selected Error => $e");

      AppToast.show("Unable to delete selected photos");
    }
  }

  Future<void> favoriteSelected(List<AssetEntity> allAssets) async {
    final selected = getSelectedAssets(allAssets);

    if (selected.isEmpty) {
      return;
    }

    int count = 0;

    try {
      for (final asset in selected) {
        final result = await PhotoManager.plugin.favoriteAsset(asset.id, true);

        if (result) {
          count++;
        }
      }

      clearSelection();

      AppToast.show("$count item${count == 1 ? '' : 's'} added to favorites");
    } catch (e) {
      debugPrint("Favorite Error => $e");
    }
  }

  void openSelectedPhoto(BuildContext context, List<AssetEntity> allAssets) {
    final asset = getFirstSelected(allAssets);

    if (asset == null) {
      return;
    }
  }

  @override
  void onClose() {
    _placesWorker?.dispose();
    _loadingWorker?.dispose();

    selectedIds.clear();
    isDragSelecting.value = false;
    _dragStartAsset = null;
    _dragStartPosition = null;
    super.onClose();
  }
}
