import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/PlaceScreen/controller/PlacesController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxInt selectedIndex = 1.obs;

  @override
  void onInit() {
    super.onInit();
    _preloadPhotos();
    _preloadPlaces();
  }

  Future<void> _preloadPhotos() async {
    try {
      if (!Get.isRegistered<PhotosController>()) {
        debugPrint('Dashboard => PhotosController not found');
        return;
      }
      final PhotosController photosController = Get.find<PhotosController>();
      if (photosController.firstPageLoaded.value &&
          photosController.allMedia.isNotEmpty) {
        debugPrint('Dashboard => Photos already loaded');
        return;
      }
      await photosController.loadInitialMediaFast();

      debugPrint(
        'Dashboard Photos Preload Completed => '
        '${photosController.allMedia.length}',
      );
    } catch (e) {
      debugPrint('Dashboard Photos Preload Error => $e');
    }
  }

  Future<void> _preloadPlaces() async {
    try {
      if (!Get.isRegistered<ForYouController>()) {
        debugPrint('Dashboard => ForYouController not found');
        return;
      }

      final ForYouController forYouController = Get.find<ForYouController>();

      if (!Get.isRegistered<PlacesController>()) {
        Get.put(PlacesController(), permanent: true);
      }

      final PlacesController placesController = Get.find<PlacesController>();
      if (!forYouController.isLoading.value &&
          forYouController.places.isNotEmpty) {
        placesController.places.assignAll(forYouController.places);

        placesController.isLoading.value = false;

        debugPrint(
          'Dashboard => Places already available: '
          '${placesController.places.length}',
        );
        return;
      }
      debugPrint('Dashboard => Places loading in background...');
    } catch (e, stack) {
      debugPrint('Dashboard Places Preload Error => $e');

      debugPrint(stack.toString());
    }
  }

  void changeTab(int index) {
    selectedIndex.value = index;
    if (index == 2 && Get.isRegistered<ForYouController>()) {
      Get.find<ForYouController>().startPreload();
    }
  }
}
