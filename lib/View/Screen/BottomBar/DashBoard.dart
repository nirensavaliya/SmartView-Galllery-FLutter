import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Albums/AlbumsScreen.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/BottomBar/Controller/DashboardController.dart';
import 'package:gallery_photos/View/Screen/For%20You/ForYouScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotosScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Widget/CommonBottomBar.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';

class Dashboard extends StatelessWidget {
  Dashboard({super.key});

  final List<Widget> screens = [
    const PhotosScreen(),
    AlbumsScreen(),
    ForYouScreen(),
  ];

  final DashBoardController dashBoardController = Get.put(
    DashBoardController(),
  );

  final AlbumsController albumsController = Get.isRegistered<AlbumsController>()
      ? Get.find<AlbumsController>()
      : Get.put(AlbumsController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    final PhotosController photosController = Get.find<PhotosController>();

    return Obx(
      () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: IndexedStack(
          index: dashBoardController.selectedIndex.value,
          children: screens,
        ),

        bottomNavigationBar: Obx(() {
          if (albumsController.isAlbumSelectionMode.value) {
            return _buildAlbumSelectionBottomBar(context, albumsController);
          }

          if (photosController.isSelectionMode.value) {
            return _buildPhotoSelectionBottomBar(context, photosController);
          }
          return CustomBottomBar(
            currentIndex: dashBoardController.selectedIndex.value,
            onTap: dashBoardController.changeTab,
          );
        }),
      ),
    );
  }

  Widget _buildPhotoSelectionBottomBar(
    BuildContext context,
    PhotosController controller,
  ) {
    return SafeArea(
      child: Container(
        height: 70,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _photoActionButton(
              context: context,
              icon: Icons.share_outlined,
              title: "Share",
              onTap: (buttonContext) async {
                await controller.shareSelected();
              },
            ),

            _photoActionButton(
              context: context,
              icon: Icons.favorite_border,
              title: "Favorite",
              onTap: (buttonContext) async {
                await controller.favoriteSelected();
              },
            ),

            _photoActionButton(
              context: context,
              icon: Icons.delete_outline,
              title: "Delete",
              onTap: (buttonContext) async {
                await controller.deleteSelectedPhotos();
              },
            ),

            _photoActionButton(
              context: context,
              icon: Icons.more_vert,
              title: "More",
              onTap: (buttonContext) {
                _showPhotoMoreMenu(
                  buttonContext,
                  controller,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoMoreMenu(
      BuildContext context,
      PhotosController controller,
      ) {
    final RenderBox button =
    context.findRenderObject() as RenderBox;

    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy - 330,
      overlay.size.width -
          buttonPosition.dx -
          buttonSize.width,
      overlay.size.height -
          buttonPosition.dy,
    );

    showMenu<String>(
      context: context,
      position: position,

      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff252525)
          : Colors.white,

      elevation: 8,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      items: [

        PopupMenuItem<String>(
          value: 'copy',
          child: Text(
            'Copy To',
            style: TextStyle(
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

PopupMenuItem<String>(
          value: 'move',
          child: Text(
            'Move To',
            style: TextStyle(
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

PopupMenuItem<String>(
          value: 'rename',
          child: Text(
            'Rename',
            style: TextStyle(
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

PopupMenuItem<String>(
          value: 'edit',
          child: Text(
            'Edit',
            style: TextStyle(
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

PopupMenuItem<String>(
          value: 'wallpaper',
          child: Text(
            'Set as wallpaper',
            style: TextStyle(
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

PopupMenuItem<String>(
          value: 'resize',
          child: Text(
            'Resize',
            style: TextStyle(
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

PopupMenuItem<String>(
          value: 'info',
          child: Text(
            'Info',
            style: TextStyle(
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ).then((value) async {
      if (value == null) {
        return;
      }

      if (value == 'copy') {
        await controller.copySelected();
        return;
      }

      if (value == 'move') {
        await controller.moveSelected();
        return;
      }

      if (value == 'rename') {
        await controller.renameSelected();
        return;
      }

      if (value == 'edit') {
        await controller.editSelected();
        return;
      }

      if (value == 'wallpaper') {
        await controller.setAsSelected();
        return;
      }
      if (value == 'resize') {
        await controller.resizeSelected();
        return;
      }
      if (value == 'info') {
        await controller.infoSelected();
        return;
      }
    });
  }
  Widget _buildAlbumSelectionBottomBar(
    BuildContext context,
    AlbumsController controller,
  ) {
    return SafeArea(
      child: Container(
        height: 70,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _albumActionButton(
              context: context,

              icon: Icons.share_outlined,
              title: "Share",
              onTap: () async {
                await controller.shareSelectedAlbums();
              },
            ),

            _albumActionButton(
              context: context,

              icon: Icons.favorite_border,
              title: "Favorite",
              onTap: () async {
                await controller.favoriteSelectedAlbums();
              },
            ),

            _albumActionButton(
              context: context,

              icon: Icons.delete_outline,
              title: "Delete",
              onTap: () async {
                await controller.deleteSelectedAlbumMedia();
              },
            ),

            _albumActionButton(
              context: context,

              icon: Icons.more_vert,
              title: "More",
              onTap: () {
                _showAlbumMoreMenu(context, controller);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbumMoreMenu(BuildContext context, AlbumsController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.copy_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  "Copy To",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await _albumCopyTo(controller);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.drive_file_move_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  "Move To",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await _albumMoveTo(controller);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.wallpaper_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  "Set as wallpaper",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _albumSetWallpaper(controller);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.drive_file_rename_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  "Rename",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await _albumRename(controller);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.auto_fix_high_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  "Edit",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await _albumEdit(controller);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.photo_size_select_large_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  "Resize",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await _albumResize(controller);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  "Info",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: FontFamily.robotoBold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await _albumInfo(controller);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  AssetPathEntity? _getSelectedAlbum(AlbumsController controller) {
    if (controller.selectedAlbumIds.isEmpty) {
      return null;
    }

    final String selectedId = controller.selectedAlbumIds.first;

    for (final album in controller.priorityAlbums) {
      if (album.id == selectedId) {
        return album;
      }
    }

    for (final album in controller.otherAlbums) {
      if (album.id == selectedId) {
        return album;
      }
    }

    return null;
  }

  Future<List<AssetEntity>> _getSelectedAlbumMedia(
    AlbumsController controller,
  ) async {
    final album = _getSelectedAlbum(controller);

    if (album == null) {
      return [];
    }

    final media = await album.getAssetListRange(start: 0, end: 10000);

    return media;
  }

  Future<void> _albumCopyTo(AlbumsController controller) async {
    final media = await _getSelectedAlbumMedia(controller);

    if (media.isEmpty) {
      AppToast.show("No media found in selected album");
      return;
    }

    AppToast.show("Selected album contains ${media.length} items");
  }

  Future<void> _albumMoveTo(AlbumsController controller) async {
    final media = await _getSelectedAlbumMedia(controller);

    if (media.isEmpty) {
      AppToast.show("No media found in selected album");
      return;
    }

    AppToast.show("Selected album contains ${media.length} items");
  }

  Future<void> _albumSetWallpaper(AlbumsController controller) async {
    final media = await _getSelectedAlbumMedia(controller);

    if (media.isEmpty) {
      AppToast.show("No photo found in selected album");
      return;
    }

    final photo = media.firstWhere(
      (asset) => asset.type == AssetType.image,
      orElse: () => media.first,
    );

    if (photo.type == AssetType.video) {
      AppToast.show("Selected album has no image");
      return;
    }

    Get.to(() => PhotoViewScreen(asset: photo, albumMedia: media));
  }

  Future<void> _albumRename(AlbumsController controller) async {
    final album = _getSelectedAlbum(controller);

    if (album == null) {
      AppToast.show("Please select one album");
      return;
    }

    AppToast.show("Album: ${album.name}");
  }

  Future<void> _albumEdit(AlbumsController controller) async {
    final media = await _getSelectedAlbumMedia(controller);

    if (media.isEmpty) {
      AppToast.show("No media found in selected album");
      return;
    }

    final photo = media.firstWhere(
      (asset) => asset.type == AssetType.image,
      orElse: () => media.first,
    );

    if (photo.type == AssetType.video) {
      AppToast.show("No image found in selected album");
      return;
    }

    Get.to(() => PhotoViewScreen(asset: photo, albumMedia: media));
  }

  Future<void> _albumResize(AlbumsController controller) async {
    final media = await _getSelectedAlbumMedia(controller);

    if (media.isEmpty) {
      AppToast.show("No media found in selected album");
      return;
    }

    final photo = media.firstWhere(
      (asset) => asset.type == AssetType.image,
      orElse: () => media.first,
    );

    if (photo.type == AssetType.video) {
      AppToast.show("No image found in selected album");
      return;
    }

    Get.to(() => PhotoViewScreen(asset: photo, albumMedia: media));
  }

  Future<void> _albumInfo(AlbumsController controller) async {
    final album = _getSelectedAlbum(controller);

    if (album == null) {
      AppToast.show("Please select one album");
      return;
    }

    final count = await album.assetCountAsync;

    Get.dialog(
      ChromeDialog(
        title: 'Album Info',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name : ${album.name}', style: ChromeText.body),
            const SizedBox(height: 8),
            Text('Items : $count', style: ChromeText.body),
          ],
        ),
        actions: [
          ChromeButton.ok(label: 'Close', onPressed: Get.back),
        ],
      ),
    );
  }

  Widget _albumActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 25,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required void Function(BuildContext buttonContext) onTap,
  }) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,

          onTap: () {
            onTap(buttonContext);
          },

          child: SizedBox(
            width: 70,
            height: 65,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: isDark
                      ? Colors.white
                      : Colors.black87,
                ),

                const SizedBox(height: 4),

                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
