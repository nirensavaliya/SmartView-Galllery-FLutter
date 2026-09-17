import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Albums/AlbumsScreen.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/BottomBar/Controller/DashboardController.dart';
import 'package:gallery_photos/View/Screen/For%20You/ForYouScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotosScreen.dart';
import 'package:gallery_photos/View/Widget/CommonBottomBar.dart';
import 'package:get/get.dart';

class Dashboard extends StatelessWidget {
  Dashboard({super.key});
  List<Widget>  screens = [PhotosScreen(), AlbumsScreen(), ForYouScreen()];
   DashBoardController dashBoardController =Get.put(DashBoardController());
  AlbumsController albumsController = Get.find<AlbumsController>();
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        backgroundColor: Colors.white,
        body: screens[dashBoardController.selectedIndex.value],
        bottomNavigationBar: Obx(() {
          if (albumsController.isAlbumSelectionMode.value) {
            return const SizedBox.shrink();
          }
          return CustomBottomBar(
            currentIndex: dashBoardController.selectedIndex.value,
            onTap: dashBoardController.changeTab,
          );
        }),
      ),
    );
  }
}
