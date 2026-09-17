import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../Photos/Controller/PhotosController.dart';

class SplashController extends GetxController {
  late final PhotosController photosController;

  final RxBool isLoadingPhotos = true.obs;

  @override
  void onInit() {
    super.onInit();

    // PhotosController ek hi baar create hoga
    photosController = Get.put(
      PhotosController(),
      permanent: true,
    );
  }

  Future<void> loadPhotos() async {
    try {
      isLoadingPhotos.value = true;

      // Splash screen ke time saare photos/videos load honge
      await photosController.loadInitialMedia();

      isLoadingPhotos.value = false;
    } catch (e) {
      debugPrint("Splash Photo Loading Error: $e");

      isLoadingPhotos.value = false;
    }
  }
}