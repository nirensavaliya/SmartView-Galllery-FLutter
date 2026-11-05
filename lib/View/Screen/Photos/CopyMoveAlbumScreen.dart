import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotoViewController.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

enum CopyMoveAction { copy, move }

class CopyMoveAlbumScreen extends StatefulWidget {
  final AssetEntity asset;
  final CopyMoveAction action;

  const CopyMoveAlbumScreen({
    super.key,
    required this.asset,
    required this.action,
  });

  @override
  State<CopyMoveAlbumScreen> createState() => _CopyMoveAlbumScreenState();
}

class _CopyMoveAlbumScreenState extends State<CopyMoveAlbumScreen> {
  final Rxn<AssetPathEntity> selectedAlbum = Rxn<AssetPathEntity>();

  late AlbumsController albumsController;

  final RxBool isProcessing = false.obs;

  String get title {
    return widget.action == CopyMoveAction.copy ? "Copy To" : "Move To";
  }

  @override
  void initState() {
    super.initState();

    if (Get.isRegistered<AlbumsController>()) {
      albumsController = Get.find<AlbumsController>();
    } else {
      albumsController = Get.put(AlbumsController());
    }

    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    try {
      if (albumsController.albums.isEmpty) {
        await albumsController.loadAlbums();
      }
    } catch (e) {
      debugPrint("Load Albums Error => $e");
    }
  }

  void _selectAlbum(AssetPathEntity album) {
    if (album.isAll) {
      return;
    }

    selectedAlbum.value = album;
  }

  void _onOk() {
    final destination = selectedAlbum.value;

    if (destination == null || isProcessing.value) {
      return;
    }

    Get.back(result: destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(const Color(0xfff5f6f7)),

      appBar: AppBar(
        backgroundColor: AppColors.bg(const Color(0xfff5f6f7)),
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: Obx(
          () => IconButton(
            onPressed: isProcessing.value ? null : () => Get.back(),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: AppColors.fg(Colors.black),
            ),
          ),
        ),

        title: Text(
          title,
          style: TextStyle(
            color: AppColors.fg(Colors.black),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: Obx(() {
        final List<AssetPathEntity> albums = albumsController.albums
            .where((album) => !album.isAll)
            .toList();

        if (albums.isEmpty) {
          return const Center(child: SplashLoader());
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),

          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 7,
            mainAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),

          itemCount: albums.length,

          itemBuilder: (context, index) {
            final album = albums[index];

            return Obx(() {
              final bool selected = selectedAlbum.value?.id == album.id;

              return GestureDetector(
                onTap: isProcessing.value ? null : () => _selectAlbum(album),
                child: _AlbumGridItem(album: album, selected: selected),
              );
            });
          },
        );
      }),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Obx(() {
            final bool canContinue =
                selectedAlbum.value != null && !isProcessing.value;

            return SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: canContinue ? _onOk : null,

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff292727),

                  disabledBackgroundColor: AppColors.surface(const Color(0xffd5d5d5)),

                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                child: isProcessing.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "OK",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _AlbumGridItem extends StatelessWidget {
  final AssetPathEntity album;
  final bool selected;

  const _AlbumGridItem({required this.album, required this.selected});

  Future<Uint8List?> _loadThumbnail() async {
    try {
      final List<AssetEntity> assets = await album.getAssetListRange(
        start: 0,
        end: 1,
      );

      if (assets.isEmpty) {
        return null;
      }

      return await assets.first.thumbnailDataWithSize(
        const ThumbnailSize(400, 400),
      );
    } catch (e) {
      debugPrint("Album thumbnail error ${album.name} => $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: FutureBuilder<Uint8List?>(
                  future: _loadThumbnail(),

                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        color: AppColors.surface(Colors.grey.shade200),
                      );
                    }

                    final bytes = snapshot.data;

                    if (bytes != null) {
                      return Image.memory(
                        bytes,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      );
                    }

                    return Container(
                      color: AppColors.surface(Colors.grey.shade200),
                      child: Center(
                        child: Icon(Icons.folder, size: 35, color: AppColors.fg(Colors.grey)),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 3),

            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),

            FutureBuilder<int>(
              future: album.assetCountAsync,
              builder: (context, snapshot) {
                return Text(
                  "${snapshot.data ?? 0}",
                  style: TextStyle(fontSize: 10, color: AppColors.fg(Colors.grey.shade600)),
                );
              },
            ),
          ],
        ),

        Positioned(
          right: 5,
          top: 5,
          child: Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? Colors.black : AppColors.surface(Colors.white.withOpacity(0.85)),
              border: Border.all(
                color: selected ? AppColors.border(Colors.black) : AppColors.border(Colors.grey.shade400),
                width: 1.3,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : null,
          ),
        ),
      ],
    );
  }
}
