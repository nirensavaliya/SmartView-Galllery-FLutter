import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotoViewController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/VideoViewScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class PhotoViewScreen extends StatefulWidget {
  final AssetEntity asset;
  final VideoPlayerController? miniVideoController;
  final List<AssetEntity>? albumMedia;
  final String? customAlbumName;
  final String? miniVideoAssetId;
  const PhotoViewScreen({
    super.key,
    required this.asset,
    this.albumMedia,
    this.customAlbumName,
    this.miniVideoController,
    this.miniVideoAssetId,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late PageController _pageController;
  late PhotoViewController controller;
  @override
  void initState() {
    super.initState();
    controller = Get.put(
      PhotoViewController(
        widget.asset,
        albumMedia: widget.albumMedia,
        customAlbumName: widget.customAlbumName,
      ),
      tag: 'photo_${widget.asset.id}_${identityHashCode(this)}',
    );

    controller.initializePhotoView();
    if (widget.miniVideoController != null) {
      controller.setMiniVideoController(widget.miniVideoController!);
    }
    _pageController = PageController(
      initialPage: controller.currentIndex.value,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (controller.slideshowPageController.hasClients) {
        controller.slideshowPageController.jumpToPage(
          controller.currentIndex.value,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PhotosController? photosController =
    Get.isRegistered<PhotosController>()
        ? Get.find<PhotosController>()
        : null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder:(context){
          final List<AssetEntity> media =
              widget.albumMedia ??
                  photosController?.filteredMedia ??
                  <AssetEntity>[];

          if (media.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final currentAsset = controller.currentAsset;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  onTap: () {
                    if (controller.isSlideshow.value) {
                      controller.stopSlideshow();
                    }
                  },
                  child: PageView.builder(
                    controller: controller.slideshowPageController,
                    itemCount: media.length,
                    onPageChanged: (index) async {
                      controller.currentIndex.value = index;
                      if (!controller.isSlideshow.value) {
                        return;
                      }
                      // final List<AssetEntity> media =
                      //     widget.albumMedia ?? photosController.filteredMedia;
                      final List<AssetEntity> media =
                          widget.albumMedia ??
                              photosController?.filteredMedia ??
                              <AssetEntity>[];
                      if (index < 0 || index >= media.length) {
                        return;
                      }
                      final AssetEntity current = media[index];
                      if (current.type == AssetType.video) {
                        controller.stopSlideshow();

                        await Get.to(() => VideoViewScreen(asset: current));
                      }
                    },
                    itemBuilder: (context, index) {
                      final asset = media[index];
                      return _MediaPage(
                        asset: asset,
                        miniVideoController: widget.miniVideoController,
                        miniVideoAssetId: widget.miniVideoAssetId,
                        isSlideshow: controller.isSlideshow.value,
                      );
                    },
                  ),
                ),
              ),

              if (!controller.isSlideshow.value)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await controller.closeMiniVideo();
                              Get.back();
                            },
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                            ),
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.formatDate(
                                    currentAsset.createDateTime,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  controller.formatTime(
                                    currentAsset.createDateTime,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: controller.showDetails,
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!controller.isSlideshow.value)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 25, bottom: 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _actionButton(
                            Icons.share,
                            "Share",
                                (_) => controller.sharePhoto(),
                          ),

                          _actionButton(
                            Icons.lock_outline,
                            "Lock",
                                (_) => controller.lockPhoto(),
                          ),

                          _actionButton(
                            Icons.delete_outline,
                            "Delete",
                                (_) => controller.deletePhoto(),
                          ),

                          if (currentAsset.type != AssetType.video)
                            _actionButton(
                              Icons.auto_fix_high_outlined,
                              "Edit",
                                  (_) => controller.editPhoto(),
                            ),

                          _actionButton(
                            Icons.more_vert,
                            "More",
                                (context) => controller.showMore(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (controller.showMiniVideo.value &&
                  widget.miniVideoController != null &&
                  widget.miniVideoController!.value.isInitialized)
                Positioned(
                  left: controller.miniVideoX.value,
                  top: controller.miniVideoY.value,
                  child: _MiniVideoOverlay(
                    controller: controller,
                    miniVideoController: widget.miniVideoController,
                    onClose: controller.closeMiniVideo,
                    onExpand: controller.expandMiniVideo,
                    onPlayPause: controller.toggleMiniVideoPlayPause,
                  ),
                ),
            ],
          );
        }
      )
    );
  }

  Widget _actionButton(
    IconData icon,
    String title,
    void Function(BuildContext context) onTap,
  ) {
    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(buttonContext),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MediaPage extends StatefulWidget {
  final AssetEntity asset;
  final VideoPlayerController? miniVideoController;
  final String? miniVideoAssetId;
  final bool isSlideshow;

  const _MediaPage({
    required this.asset,
    this.miniVideoController,
    this.miniVideoAssetId,
    this.isSlideshow = false,
  });

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  late Future<File?> _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = widget.asset.file;
  }

  @override
  void didUpdateWidget(covariant _MediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _fileFuture = widget.asset.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asset.type == AssetType.video) {
      return _buildVideoThumbnail(context);
    }

    return _buildImage();
  }

  Widget _buildImage() {
    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 70,
            ),
          );
        }

        final file = snapshot.data;

        if (file == null) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 70,
            ),
          );
        }

        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,

              // Image ko unnecessarily re-decode/repaint hone se help milegi
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoThumbnail(BuildContext context) {
    if (widget.isSlideshow) {
      return FutureBuilder<Uint8List?>(
        future: widget.asset.thumbnailDataWithSize(
          const ThumbnailSize(1080, 1080),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Icon(Icons.video_library, color: Colors.white, size: 70),
            );
          }

          return Center(
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          );
        },
      );
    }

    // =========================================================
    // NORMAL VIDEO
    // =========================================================

    return GestureDetector(
      onTap: () {
        if (widget.miniVideoController != null &&
            widget.miniVideoAssetId == widget.asset.id) {
          Get.back();
          return;
        }

        Get.to(() => VideoViewScreen(asset: widget.asset));
      },
      child: FutureBuilder<Uint8List?>(
        future: widget.asset.thumbnailDataWithSize(
          const ThumbnailSize(1080, 1080),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 70,
              ),
            );
          }

          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  final PhotoViewController photoController;
  final VoidCallback onClose;
  final VoidCallback onExpand;
  final Future<void> Function() onPlayPause;
  const _MiniVideoPlayer({
    required this.controller,
    required this.photoController,
    required this.onClose,
    required this.onExpand,
    required this.onPlayPause,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final screenSize = MediaQuery.of(context).size;

        final newX = photoController.miniVideoX.value + details.delta.dx;

        final newY = photoController.miniVideoY.value + details.delta.dy;

        photoController.miniVideoX.value = newX.clamp(
          0.0,
          screenSize.width - 170,
        );

        photoController.miniVideoY.value = newY.clamp(
          0.0,
          screenSize.height - 105,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 170,
          height: 105,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 2),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // =====================================================
                // VIDEO
                // =====================================================
                RepaintBoundary(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),

                // =====================================================
                // OVERLAY
                // =====================================================
                Positioned.fill(child: Container(color: Colors.black26)),

                // =====================================================
                // CLOSE
                // =====================================================
                Positioned(
                  top: 3,
                  right: 3,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                // =====================================================
                // EXPAND
                // =====================================================
                Positioned(
                  top: 3,
                  left: 3,
                  child: GestureDetector(
                    onTap: onExpand,
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      debugPrint("========== MINI PLAY PAUSE TAP ==========");
                      await onPlayPause();
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Obx(() {
                        final isPlaying =
                            photoController.miniVideoIsPlaying.value;

                        return Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _MiniVideoOverlay extends StatelessWidget {
  final PhotoViewController controller;
  final VideoPlayerController? miniVideoController;
  final VoidCallback onClose;
  final VoidCallback onExpand;
  final Future<void> Function() onPlayPause;

  const _MiniVideoOverlay({
    required this.controller,
    required this.miniVideoController,
    required this.onClose,
    required this.onExpand,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.showMiniVideo.value ||
          miniVideoController == null ||
          !miniVideoController!.value.isInitialized) {
        return const SizedBox.shrink();
      }

      return Positioned(
        left: controller.miniVideoX.value,
        top: controller.miniVideoY.value,
        child: _MiniVideoPlayer(
          controller: miniVideoController!,
          photoController: controller,
          onClose: onClose,
          onExpand: onExpand,
          onPlayPause: onPlayPause,
        ),
      );
    });
  }
}
