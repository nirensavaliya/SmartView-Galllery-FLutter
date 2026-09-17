import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

class MemoryDetailController extends GetxController
    with GetTickerProviderStateMixin {
  final String title;
  final String date;
  final List<AssetEntity> assets;
  final int initialIndex;
  final MemoryGroup? currentMemory;

  MemoryDetailController({
    required this.title,
    required this.date,
    required this.assets,
    this.initialIndex = 0,
    this.currentMemory,

  });

  final RxInt currentIndex = 0.obs;

  final RxBool isPlaying = false.obs;

  final RxBool showIntro = true.obs;

  final RxBool slideshowFinished = false.obs;

  final RxBool isSlideshowRunning = false.obs;

  final RxBool controlsVisible = false.obs;
  final ScrollController thumbnailScrollController = ScrollController();

  late PageController pageController;

  Timer? slideshowTimer;

  late AnimationController introController;

  late Animation<double> introOpacity;

  late Animation<double> introScale;

  late Animation<double> introSlide;

  late AnimationController exitController;

  late Animation<double> exitOpacity;
  final RxBool showEndScreen = false.obs;
  final RxString selectedMusic = 'Audio 1'.obs;

  final RxString selectedMusicPath =
      'Music/audio1.mp3'.obs;

  final AudioPlayer musicPlayer = AudioPlayer();

  @override
  void onInit() {
    super.onInit();

    currentIndex.value = initialIndex.clamp(
      0,
      assets.isEmpty ? 0 : assets.length - 1,
    );

    pageController = PageController(initialPage: currentIndex.value);
    introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    introOpacity = Tween<double>(begin: 0.60, end: 1.0).animate(
      CurvedAnimation(parent: introController, curve: Curves.easeInOut),
    );

    introScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: introController, curve: Curves.easeInOut),
    );

    introSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: introController, curve: Curves.easeOutCubic),
    );

    introController.repeat(reverse: true);
    exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    exitOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: exitController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isClosed) return;

      // Default music start
      await playSelectedMusic(selectedMusicPath.value);

      if (isClosed) return;

      // Slideshow start
      startSlideshow();
    });
  }

  Future<Uint8List?> loadImage(AssetEntity asset) {
    final ForYouController controller = Get.find<ForYouController>();

    return controller.loadMemoryImage(asset);
  }

  Future<void> selectMusic({required String name, required String path}) async {
    selectedMusic.value = name;
    selectedMusicPath.value = path;

    await playSelectedMusic(path);
  }

  Future<void> playSelectedMusic(String path) async {
    try {
      await musicPlayer.stop();

      await musicPlayer.setReleaseMode(
        ReleaseMode.loop,
      );

      await musicPlayer.play(
        AssetSource(path),
      );

      debugPrint('🎵 Music playing: $path');
    } catch (e) {
      debugPrint('❌ Music play error: $e');
    }
  }

  Future<void> dismissIntro() async {
    if (!showIntro.value) {
      return;
    }
    showIntro.value = false;
    controlsVisible.value = true;

    introController.stop();

    // Name/date ko smoothly hide karo
    await exitController.forward();

    if (isClosed) {
      return;
    }
  }

  void startSlideshow() {
    if (isClosed || slideshowFinished.value) {
      return;
    }

    if (assets.length <= 1) {
      isPlaying.value = false;
      isSlideshowRunning.value = false;
      return;
    }

    if (isSlideshowRunning.value) {
      return;
    }

    isSlideshowRunning.value = true;

    isPlaying.value = true;

    scheduleNextPhoto();
  }

  void scheduleNextPhoto() {
    slideshowTimer?.cancel();

    if (isClosed ||
        !isSlideshowRunning.value ||
        slideshowFinished.value ||
        assets.length <= 1) {
      return;
    }

    slideshowTimer = Timer(const Duration(seconds: 2), showNextPhoto);
  }

  void showNextPhoto() {
    if (isClosed || !isSlideshowRunning.value || slideshowFinished.value) {
      return;
    }

    if (currentIndex.value >= assets.length - 1) {
      finishSlideshow();
      return;
    }
    final int nextIndex = currentIndex.value + 1;
    currentIndex.value = nextIndex;

    showIntro.value = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        moveThumbnailToSelected(nextIndex);
      }
    });

    // Next image ko already background me ready rakho.
    // if (nextIndex + 1 < assets.length) {
    //   loadImage(assets[nextIndex + 1]);
    // }

    if (nextIndex >= assets.length - 1) {
      finishSlideshow();
    } else {
      scheduleNextPhoto();
    }
  }

  void finishSlideshow() {
    slideshowTimer?.cancel();
    slideshowTimer = null;

    isSlideshowRunning.value = false;
    slideshowFinished.value = true;

    isPlaying.value = false;
    controlsVisible.value = false;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!isClosed) {
        showEndScreen.value = true;
      }
    });
  }

  void restartMemory() {
    slideshowTimer?.cancel();
    slideshowTimer = null;

    showEndScreen.value = false;
    slideshowFinished.value = false;

    currentIndex.value = 0;

    pageController.jumpToPage(0);

    // Restart ke baad controls wapas nahi chahiye
    // jab tak user screen par tap na kare.
    controlsVisible.value = false;

    isSlideshowRunning.value = false;
    isPlaying.value = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        startSlideshow();
      }
    });
  }

  void closeEndScreen() {
    showEndScreen.value = false;
  }

  void stopSlideshow() {
    slideshowTimer?.cancel();
    slideshowTimer = null;

    isSlideshowRunning.value = false;

    isPlaying.value = false;
  }

  void toggleSlideshow() {
    if (assets.length <= 1 || slideshowFinished.value) {
      return;
    }

    if (isPlaying.value) {
      stopSlideshow();
    } else {
      startSlideshow();
      controlsVisible.value = true;
      showIntro.value = false;
      showEndScreen.value = false;
    }
  }

  void onPageChanged(int index) {
    if (isClosed) {
      return;
    }

    currentIndex.value = index;

    // First photo ke baad name/date hide
    if (index > 0) {
      showIntro.value = false;
    }

    // Bottom thumbnails slideshow ke saath move honge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        moveThumbnailToSelected(index);
      }
    });

    if (index >= assets.length - 1) {
      finishSlideshow();
    }
  }

  void moveThumbnailToSelected(int index) {
    if (!thumbnailScrollController.hasClients) {
      return;
    }

    const double itemWidth = 44.0;

    final double viewportWidth =
        thumbnailScrollController.position.viewportDimension;

    double targetOffset =
        (index * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);

    final double maxOffset = thumbnailScrollController.position.maxScrollExtent;

    targetOffset = targetOffset.clamp(0.0, maxOffset);

    thumbnailScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  // ============================================================
  // THUMBNAIL CLICK
  // ============================================================
  void selectThumbnail(int index) {
    if (isClosed || index < 0 || index >= assets.length) {
      return;
    }
    showEndScreen.value = false;
    slideshowFinished.value = false;
    currentIndex.value = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        moveThumbnailToSelected(index);
      }
    });
  }
  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void onClose() {
    slideshowTimer?.cancel();

    introController.dispose();

    exitController.dispose();

    pageController.dispose();
    musicPlayer.dispose();
    thumbnailScrollController.dispose();
    super.onClose();
  }
}
