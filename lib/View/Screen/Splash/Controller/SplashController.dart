import 'dart:async';

import 'package:gallery_photos/View/Screen/For%20You/controller/FaceGroupController.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:get/get.dart';

class SplashController extends GetxController {
  late final PhotosController photosController;

  final RxBool isLoadingPhotos = true.obs;

  bool _started = false;

  void startLoading() {
    if (_started) {
      return;
    }
    _started = true;
    isLoadingPhotos.value = true;

    photosController = Get.isRegistered<PhotosController>()
        ? Get.find<PhotosController>()
        : Get.put(PhotosController(), permanent: true);

    unawaited(
      photosController.loadInitialMediaFast().whenComplete(() {
        isLoadingPhotos.value = false;
        unawaited(_continuePreload());
      }),
    );
  }

  Future<void> _continuePreload() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (Get.isRegistered<PhotosController>()) {
      await Get.find<PhotosController>().loadRemainingMediaInBackground();
    }

    final ForYouController forYou = Get.isRegistered<ForYouController>()
        ? Get.find<ForYouController>()
        : Get.put(ForYouController(), permanent: true);
    forYou.startPreload();
    await forYou.waitForFirstLoad();

    final FaceGroupController face = Get.isRegistered<FaceGroupController>()
        ? Get.find<FaceGroupController>()
        : Get.put(FaceGroupController(), permanent: true);
    unawaited(face.startBackgroundScan());
  }
}
