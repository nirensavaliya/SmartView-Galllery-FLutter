
import 'package:gallery_photos/View/Screen/Albums/AlbumsScreen.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/BottomBar/Controller/DashboardController.dart';
import 'package:gallery_photos/View/Screen/BottomBar/DashBoard.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/CleanerScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotoViewController.dart';
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
      page: () => CleanerScreen(),
    ),
  ];
}