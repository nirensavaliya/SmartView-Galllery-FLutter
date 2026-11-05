import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class VideoViewController extends GetxController {
  final AssetEntity asset;
  VideoViewController(this.asset);
  final Rx<VideoPlayerController?> videoController = Rx<VideoPlayerController?>(
    null,
  );
  final isInitialized = false.obs;
  final isPlaying = false.obs;
  final showControls = true.obs;
  final isLocked = false.obs;
  final isFullScreen = false.obs;
  final speed = 1.0.obs;
  Timer? hideTimer;
  final currentPosition = Duration.zero.obs;
  @override
  void onInit() {
    super.onInit();
    initializeVideo();
  }

  Future<void> initializeVideo() async {
    try {
      final File? file = await asset.file;

      if (file == null || !await file.exists()) {
        return;
      }
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();

      videoController.value = controller;
      isInitialized.value = true;
      isPlaying.value = true;
      controller.addListener(videoListener);
      startHideTimer();
    } catch (e) {
      debugPrint("VIDEO ERROR: $e");
    }
  }

  void videoListener() {
    final controller = videoController.value;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final value = controller.value;

    currentPosition.value = value.position;

    if (value.duration > Duration.zero && value.position >= value.duration) {
      if (value.isPlaying) {
        controller.pause();
      }
      isPlaying.value = false;
      showControls.value = true;
      hideTimer?.cancel();
      return;
    }

    isPlaying.value = value.isPlaying;
  }

  void startHideTimer() {
    hideTimer?.cancel();
    hideTimer = Timer(const Duration(seconds: 3), () {
      final controller = videoController.value;

      if (controller != null && controller.value.isPlaying && !isLocked.value) {
        showControls.value = false;
      }
    });
  }

  void toggleControls() {
    if (isLocked.value) {
      return;
    }
    showControls.value = !showControls.value;
    if (showControls.value) {
      startHideTimer();
    }
  }

  Future<void> togglePlayPause() async {
    final controller = videoController.value;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;

    if (position >= duration && duration > Duration.zero) {
      await controller.seekTo(Duration.zero);
      await controller.play();

      isPlaying.value = true;
      showControls.value = true;
      startHideTimer();

      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      isPlaying.value = false;
      showControls.value = true;
      hideTimer?.cancel();
    } else {
      await controller.play();

      isPlaying.value = true;
      showControls.value = true;
      startHideTimer();
    }
  }

  Future<void> showSpeedMenu(BuildContext context, GlobalKey speedKey) async {
    if (isLocked.value) {
      return;
    }
    final RenderBox? button =
        speedKey.currentContext?.findRenderObject() as RenderBox?;

    if (button == null) {
      return;
    }

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset position = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final Size buttonSize = button.size;

    final RelativeRect positionRect = RelativeRect.fromRect(
      Rect.fromLTWH(
        position.dx,
        position.dy,
        buttonSize.width,
        buttonSize.height,
      ),
      Offset.zero & overlay.size,
    );

    const List<double> speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    final double? selected = await showMenu<double>(
      context: context,
      position: positionRect,
      color: AppColors.surface(Colors.black87),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem<double>(
          enabled: false,
          child: Text(
            "Playback speed",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        for (final double value in speeds)
          PopupMenuItem<double>(
            value: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    value == 1.0 ? "Normal" : "${value}x",
                    style: TextStyle(
                      color: speed.value == value ? Colors.blue : Colors.white,
                      fontSize: 15,
                      fontWeight: speed.value == value
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),

                if (speed.value == value)
                  const Icon(Icons.check, color: Colors.blue, size: 20),
              ],
            ),
          ),
      ],
    );

    if (selected == null) {
      return;
    }

    speed.value = selected;

    await videoController.value?.setPlaybackSpeed(selected);
  }

Future<void> seekRelative(int seconds) async {
    final controller = videoController.value;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final Duration currentPosition = controller.value.position;
    final Duration duration = controller.value.duration;

    Duration newPosition =
        currentPosition + Duration(seconds: seconds);

    if (newPosition < Duration.zero) {
      newPosition = Duration.zero;
    }

    if (newPosition > duration) {
      newPosition = duration;
    }

    await controller.seekTo(newPosition);

    if (controller.value.isPlaying) {
      await controller.play();
    }
  }

  Future<void> seekToMilliseconds(double milliseconds) async {
    final controller = videoController.value;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;

    final int value = milliseconds
        .round()
        .clamp(0, duration.inMilliseconds);

    await controller.seekTo(
      Duration(milliseconds: value),
    );
  }

Future<void> seekToProgress(double progress) async {
    final controller = videoController.value;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    progress = progress.clamp(0.0, 1.0);

    final Duration duration = controller.value.duration;

    final Duration newPosition = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );

    await controller.seekTo(newPosition);
  }

void toggleFullScreen() {
    isFullScreen.value = !isFullScreen.value;

    if (isFullScreen.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

void lockVideo() {
    isLocked.value = true;

    showControls.value = false;

    hideTimer?.cancel();
  }

void unlockVideo() {
    isLocked.value = false;

    showControls.value = true;

    startHideTimer();
  }

void openPhotoViewWithMiniVideo() {
    final controller = videoController.value;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    Get.to(
      () => PhotoViewScreen(
        asset: asset,
        miniVideoController: controller,
        miniVideoAssetId: asset.id,
      ),
    );
  }

String formatDuration(Duration duration) {
    final int hours = duration.inHours;

    final int minutes = duration.inMinutes.remainder(60);

    final int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return "$hours:"
          "${minutes.toString().padLeft(2, '0')}:"
          "${seconds.toString().padLeft(2, '0')}";
    }

    return "$minutes:"
        "${seconds.toString().padLeft(2, '0')}";
  }

@override
  void onClose() {
    hideTimer?.cancel();

    final controller = videoController.value;

    if (controller != null) {
      controller.removeListener(videoListener);
      controller.dispose();
    }

    if (isFullScreen.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    super.onClose();
  }
}
