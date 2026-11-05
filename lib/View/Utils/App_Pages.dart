import 'package:flutter/animation.dart';
import 'package:gallery_photos/View/Screen/Albums/AlbumsScreen.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/BottomBar/Controller/DashboardController.dart';
import 'package:gallery_photos/View/Screen/BottomBar/DashBoard.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/CleanerCategoryScreen.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/CleanerScreen.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/Controller/CleanerController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/PrivatePhotoController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/lock_setup_controller.dart';
import 'package:gallery_photos/View/Screen/Lock/Lockscreen.dart';
import 'package:gallery_photos/View/Screen/Lock/PrivateScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotosScreen.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinView.dart';
import 'package:gallery_photos/View/Utils/App_Routes.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.dashboard,
      page: () => Dashboard(),
      binding: BindingsBuilder(() {
        Get.lazyPut<DashBoardController>(() => DashBoardController());
      }),
    ),
    GetPage(
      name: AppRoutes.albumsScreen,
      page: () => AlbumsScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AlbumsController>(() => AlbumsController());
      }),
    ),
    GetPage(
      name: AppRoutes.photosScreen,
      page: () => PhotosScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<PhotosController>(() => PhotosController());
      }),
    ),
    GetPage(
      name: AppRoutes.photViewScreen,
      page: () => PhotoViewScreen(
        asset: Get.arguments as AssetEntity,
      ),
    ),
    GetPage(
      name: AppRoutes.recycleBinView,
      page: () => RecycleBinScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<RecycleBinController>(() => RecycleBinController());
      }),
    ),
    GetPage(
      name: AppRoutes.cleanerScreen,
      page: () => const CleanerScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CleanerController>(
          () => CleanerController(),
          fenix: true,
        );
      }),
    ),
    GetPage(
      name: AppRoutes.cleanerCategoryScreen,
      page: () => const CleanerCategoryScreen(),
    ),
    GetPage(
      name: AppRoutes.LockScreen,
      page: () => LockSetupScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      binding: BindingsBuilder(() {
        Get.lazyPut<LockSetupController>(() => LockSetupController());
      }),
    ),
    GetPage(
      name: AppRoutes.privateScreen,
      page: () => PrivateScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<PrivateLockController>(() => PrivateLockController());
      }),
    ),
  ];
}
