import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/videoController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class VideoViewScreen extends StatelessWidget {
  final AssetEntity asset;
  const VideoViewScreen({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final String controllerTag = 'video_${asset.id}';
    final VideoViewController controller = Get.put(
      VideoViewController(asset),
      tag: controllerTag,
    );
    final GlobalKey speedKey = GlobalKey();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final VideoPlayerController? video = controller.videoController.value;
        return GestureDetector(
          onTap: controller.toggleControls,
          child: Stack(
            children: [
              Positioned.fill(
                child: video == null || !controller.isInitialized.value
                    ? const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
                    : controller.isFullScreen.value
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: video.value.size.width,
                            height: video.value.size.height,
                            child: VideoPlayer(video),
                          ),
                        ),
                      )
                    : Center(
                        child: AspectRatio(
                          aspectRatio: video.value.aspectRatio,
                          child: VideoPlayer(video),
                        ),
                      ),
              ),

              if (controller.showControls.value &&
                  !controller.isLocked.value &&
                  video != null &&
                  video.value.isInitialized)
                Positioned.fill(
                  child: Column(
                    children: [
                      Container(
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
                                onPressed: () {
                                  Get.back();
                                },
                                icon: const Icon(
                                  Icons.arrow_back_ios,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  asset.title ?? "Video",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: speedKey,
                                onPressed: () {
                                  controller.showSpeedMenu(context, speedKey);
                                },
                                icon: const Icon(
                                  Icons.speed,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // -10 SEC
                          IconButton(
                            onPressed: () {
                              controller.seekRelative(-10);
                            },
                            icon: const Icon(
                              Icons.replay_10,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),

                          const SizedBox(width: 30),

                          // PLAY / PAUSE
                          GestureDetector(
                            onTap: controller.togglePlayPause,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                controller.isPlaying.value
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 42,
                              ),
                            ),
                          ),

                          const SizedBox(width: 30),

                          // +10 SEC
                          IconButton(
                            onPressed: () {
                              controller.seekRelative(10);
                            },
                            icon: const Icon(
                              Icons.forward_10,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      Container(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 8,
                          top: 20,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    controller.formatDuration(
                                      video.value.position,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),

                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 14,
                                            ),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                        overlayColor: Colors.white24,
                                      ),
                                      child: Slider(
                                        min: 0,

                                        max:
                                            video
                                                    .value
                                                    .duration
                                                    .inMilliseconds >
                                                0
                                            ? video
                                                  .value
                                                  .duration
                                                  .inMilliseconds
                                                  .toDouble()
                                            : 1,

                                        value: controller
                                            .currentPosition
                                            .value
                                            .inMilliseconds
                                            .clamp(
                                              0,
                                              video
                                                  .value
                                                  .duration
                                                  .inMilliseconds,
                                            )
                                            .toDouble(),

                                        onChanged: (value) {
                                          controller.seekToMilliseconds(value);
                                        },
                                      ),
                                    ),
                                  ),

                                  Text(
                                    controller.formatDuration(
                                      video.value.duration,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // LOCK
                                  IconButton(
                                    onPressed: controller.lockVideo,
                                    icon: const Icon(
                                      Icons.lock_outline,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),

                                  // FULLSCREEN
                                  IconButton(
                                    onPressed: controller.toggleFullScreen,
                                    icon: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),

                                  // PHOTO VIEW
                                  IconButton(
                                    onPressed:
                                        controller.openPhotoViewWithMiniVideo,
                                    icon: const Icon(
                                      Icons.picture_in_picture_alt,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),

                                  // PLAY / PAUSE
                                  IconButton(
                                    onPressed: controller.togglePlayPause,
                                    icon: Icon(
                                      controller.isPlaying.value
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // =====================================================
              // LOCKED UI
              // =====================================================
              if (controller.isLocked.value)
                Positioned(
                  left: 20,
                  top: 50,
                  child: SafeArea(
                    child: IconButton(
                      onPressed: controller.unlockVideo,
                      icon: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
