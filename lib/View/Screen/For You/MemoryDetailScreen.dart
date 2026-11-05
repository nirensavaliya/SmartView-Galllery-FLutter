import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/For%20You/MemoryShareScreen.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/MemoryDetailController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class MemoryDetailScreen extends StatelessWidget {
  final String title;
  final String date;
  final List<AssetEntity> assets;
  final int initialIndex;
  final List<MemoryGroup> memories;
  final MemoryGroup? currentMemory;

  const MemoryDetailScreen({
    super.key,
    required this.title,
    required this.date,
    required this.assets,
    required this.memories,
    this.currentMemory,
    this.initialIndex = 0,
  });
  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Scaffold(
        backgroundColor: InnerChrome.page,
        body: SafeArea(
          child: Center(
            child: Text(
              'No photos found',
              style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: InnerChrome.ink, fontSize: 16),
            ),
          ),
        ),
      );
    }
    final List<AssetEntity> orderedAssets = _getOrderedAssets();

    final controller = Get.put(
      MemoryDetailController(
        title: title,
        date: date,
        assets: orderedAssets,
        initialIndex: initialIndex,
        currentMemory: currentMemory,
      ),
      tag: '${title}_${date}_${assets.isNotEmpty ? assets.first.id : ''}',
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        controller.showControls();
      },
      child: Obx(
        () => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _MemoryPhotoPage(
                    asset: controller.assets[controller.currentIndex.value],
                    controller: controller,
                  ),
                ),

                Positioned.fill(
                  child: Container(color: AppColors.surface(Colors.black.withOpacity(0.50))),
                ),

                if (controller.showEndScreen.value)
                  Positioned.fill(
                    child: _MemoryEndScreen(
                      controller: controller,
                      memories: memories,
                      currentMemory: currentMemory,
                    ),
                  ),
                if (controller.controlsVisible.value)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, -20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.65),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Get.back();
                                },
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 20,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.title.isEmpty
                                          ? 'Exploring the Day'
                                          : controller.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    Text(
                                      controller.date,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              GestureDetector(
                                onTap: controller.toggleLike,
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    controller.isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: controller.isLiked
                                        ? Colors.red
                                        : Colors.white,
                                    size: 23,
                                  ),
                                ),
                              ),

                              GestureDetector(
                                onTap: () {
                                  Get.to(
                                    () => MemoryShareScreen(
                                      title: controller.title,
                                      assets: controller.assets,
                                    ),
                                  );
                                },
                                child: const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.share,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (controller.showIntro.value)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          controller.introController,
                          controller.exitController,
                        ]),
                        builder: (context, child) {
                          return Opacity(
                            opacity: controller.exitController.value > 0
                                ? controller.exitOpacity.value
                                : 1.0,

                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 105,
                                  left: 20,
                                  right: 20,
                                ),
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    controller.introSlide.value,
                                  ),
                                  child: Transform.scale(
                                    scale: controller.introScale.value,
                                    child: Opacity(
                                      opacity: controller.introOpacity.value,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            controller.title.isEmpty
                                                ? 'Exploring the Day'
                                                : controller.title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 30,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                              shadows: [
                                                Shadow(
                                                  blurRadius: 20,
                                                  color: Colors.black54,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 10),

                                          Text(
                                            controller.date,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: 0.5,
                                              fontFamily: 'Plus Jakarta Sans',
                                              shadows: [
                                                Shadow(
                                                  blurRadius: 15,
                                                  color: Colors.black54,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                if (controller.controlsVisible.value)
                  _buildBottomControls(controller, context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AssetEntity> _getOrderedAssets() {
    if (assets.isEmpty) {
      return assets;
    }

    final Map<String, dynamic> savedCovers = Map<String, dynamic>.from(
      GetStorageData.readObject(GetStorageData.memoryCovers) ?? {},
    );

    final String memoryKey = assets.first.id;

    final String? coverId = savedCovers[memoryKey]?.toString();

    if (coverId == null || coverId.isEmpty) {
      return assets;
    }

    final int coverIndex = assets.indexWhere((asset) => asset.id == coverId);

    if (coverIndex <= 0) {
      return assets;
    }

    final AssetEntity coverAsset = assets[coverIndex];

    return [coverAsset, ...assets.where((asset) => asset.id != coverId)];
  }

  Widget _buildBottomControls(
    MemoryDetailController controller,
    BuildContext context,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 25 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.90), Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    controller: controller.thumbnailScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.assets.length,
                    physics: const BouncingScrollPhysics(),

                    itemExtent: 44,

                    itemBuilder: (context, index) {
                      final bool selected =
                          index == controller.currentIndex.value;

                      return Center(
                        child: GestureDetector(
                          onTap: () {
                            controller.selectThumbnail(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),

                            width: selected ? 40 : 34,
                            height: selected ? 40 : 34,

                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.border(Colors.white)
                                    : AppColors.border(Colors.white.withOpacity(0.30)),
                                width: selected ? 2 : 1,
                              ),
                            ),

                            child: ClipOval(
                              child: _Thumbnail(
                                asset: controller.assets[index],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Obx(
                      () => _RoundButton(
                        icon: controller.isMusicMuted.value ?Icons.volume_off:Icons.volume_up_outlined,
                        onTap: controller.toggleMusicMute,
                      ),
                    ),

                    const SizedBox(width: 55),

                    _RoundButton(
                      size: 52,
                      icon: controller.isPlaying.value
                          ? Icons.pause
                          : Icons.play_arrow,
                      onTap: controller.toggleSlideshow,
                    ),

                    const SizedBox(width: 55),

                    _RoundButton(
                      icon: Icons.music_note_outlined,
                      onTap: () {
                        _showMusicDialog(context, controller);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMusicDialog(
    BuildContext context,
    MemoryDetailController controller,
  ) {
    final List<Map<String, String>> musicList = [
      {
        'name': 'Audio 1',
        'duration': '01:00',
        'size': '',
        'path': 'Music/audio3.mp3',
      },
      {
        'name': 'Audio 2',
        'duration': '01:00',
        'size': '',
        'path': 'Music/audio4.mp3',
      },{
        'name': 'Audio 2',
        'duration': '01:00',
        'size': '',
        'path': 'Music/audio5.mp3',
      },{
        'name': 'Audio 2',
        'duration': '01:00',
        'size': '',
        'path': 'Music/audio6.mp3',
      },
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogBackgroundColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Music',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                ...musicList.map((music) {
                  return Obx(() {
                    final bool selected =
                        controller.selectedMusicPath.value == music['path'];

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await controller.selectMusic(
                          name: music['name']!,
                          path: music['path']!,
                        );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.music_note,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    music['name']!,
                                    style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    music['duration']!,
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                border: selected
                                    ? null
                                    : Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Icon(
                                selected ? Icons.check : Icons.add,
                                size: 15,
                                color: selected
                                    ? Theme.of(context).colorScheme.surface
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemoryPhotoPage extends StatelessWidget {
  final AssetEntity asset;
  final MemoryDetailController controller;

  const _MemoryPhotoPage({
    super.key,
    required this.asset,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(asset.id),

      tween: Tween<double>(begin: 1.0, end: 1.35),

      duration: const Duration(seconds: 5),
      curve: Curves.easeOutCubic,

      builder: (context, scale, child) {
        return Transform.scale(
          alignment: Alignment.center,
          scale: scale,
          child: child,
        );
      },

      child: _FullScreenImage(asset: asset, controller: controller),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final AssetEntity asset;
  final MemoryDetailController? controller;
  final BoxFit fit;

  const _FullScreenImage({
    required this.asset,
    this.controller,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final Future<Uint8List?> imageFuture =
        controller?.loadImage(asset) ??
        asset.thumbnailDataWithSize(const ThumbnailSize(1800, 1800));

    return FutureBuilder<Uint8List?>(
      future: imageFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.expand();
        }

        if (snapshot.hasError) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 50,
            ),
          );
        }

        return Center(
          child: Image.memory(
            snapshot.data!,
            fit: fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _Thumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(180, 180)),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Container(color: AppColors.surface(Colors.grey.shade800));
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _RoundButton({required this.icon, required this.onTap, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface(Colors.black.withOpacity(0.72)),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border(Colors.white.withOpacity(0.12))),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}

class _MemoryEndScreen extends StatelessWidget {
  final MemoryDetailController controller;
  final List<MemoryGroup> memories;
  final MemoryGroup? currentMemory;

  const _MemoryEndScreen({
    required this.controller,
    required this.memories,
    this.currentMemory,
  });
  @override
  Widget build(BuildContext context) {
    final AssetEntity lastAsset =
        controller.assets[controller.currentIndex.value];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 10,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  Get.back();
                },
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(Icons.close, color: Colors.white, size: 23),
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final screenHeight = constraints.maxHeight;

                  final imageWidth = (screenWidth * 0.83).clamp(205.0, 390.0);
                  final imageHeight = (screenHeight * 0.50).clamp(265.0, 410.0);

                  const double listLeftPadding = 20.0;

                  return Column(
                    children: [
                      const SizedBox(height: 48),
                      Container(
                        width: imageWidth,
                        height: imageHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.antiAlias,
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: _FullScreenImage(
                                  asset: lastAsset,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 14,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  11,
                                  12,
                                  11,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface(Colors.black.withOpacity(0.70)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      controller.title.isEmpty
                                          ? 'Exploring the Day'
                                          : controller.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      controller.date,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontWeight: FontWeight.w400,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 11),
                      Container(
                        height: 43,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface(Colors.black.withOpacity(0.32)),
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(
                            color: AppColors.border(Colors.white.withOpacity(0.10)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: controller.restartMemory,
                              child: const SizedBox(
                                width: 42,
                                height: 41,
                                child: Center(
                                  child: Icon(
                                    Icons.restart_alt,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: controller.toggleLike,
                              child: SizedBox(
                                width: 42,
                                height: 41,
                                child: Center(
                                  child: Icon(
                                    controller.isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: controller.isLiked
                                        ? Colors.red
                                        : Colors.white,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Get.to(
                                  () => MemoryShareScreen(
                                    title: controller.title,
                                    assets: controller.assets,
                                  ),
                                );
                              },
                              child: const SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: listLeftPadding + 10,
                          ),
                          child: Text(
                            'Watch Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      SizedBox(
                        height: 155,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: memories.length,
                          itemBuilder: (context, index) {
                            final memory = memories[index];

                            if (memory.assets.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _WatchNextCard(
                                asset: memory.assets.first,
                                title: memory.title,
                                date:
                                    '${memory.date.month}/${memory.date.year}',
                                width: 135,
                                height: 145,
                                onTap: () {
                                  Get.to(
                                    () => MemoryDetailScreen(
                                      title: memory.title,
                                      date:
                                          '${memory.date.month}/${memory.date.year}',
                                      assets: memory.assets,
                                      initialIndex: 0,
                                      memories: memories,
                                      currentMemory: memory,
                                    ),
                                    preventDuplicates: false,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchNextCard extends StatelessWidget {
  final AssetEntity asset;
  final String title;
  final String date;
  final VoidCallback onTap;
  final double width;
  final double height;

  const _WatchNextCard({
    required this.asset,
    required this.title,
    required this.date,
    required this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumbnail(asset: asset),
              Positioned.fill(
                child: Container(color: AppColors.surface(Colors.black.withOpacity(0.50))),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 28, 6, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.92),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        date,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
