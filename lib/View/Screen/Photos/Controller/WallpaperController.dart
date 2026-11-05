import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class WallpaperController extends GetxController {
  final File imageFile;

  WallpaperController({
    required this.imageFile,
  });

final Rxn<ui.Image> image = Rxn<ui.Image>();
  final RxBool isLoadingImage = true.obs;

final RxInt ratioIndex = 0.obs;

  final RxDouble aspectRatio = 1.0.obs;

  final RxBool allowAspectRatio = false.obs;

  final List<double> ratios = [
    1.0,
    4 / 5,
    3 / 4,
    9 / 16,
    4 / 3,
    16 / 9,
  ];

final RxInt rotation = 0.obs;

final RxDouble cropX = 0.0.obs;
  final RxDouble cropY = 0.0.obs;
  final RxDouble cropSize = 0.0.obs;

  bool cropInitialized = false;

final RxInt selectedLocation =
      WallpaperManagerFlutter.homeScreen.obs;

@override
  void onInit() {
    super.onInit();

    loadImage();
  }

Future<void> loadImage() async {
    try {
      isLoadingImage.value = true;

      final bytes = await imageFile.readAsBytes();

      final codec =
      await ui.instantiateImageCodec(bytes);

      final frame =
      await codec.getNextFrame();

      image.value = frame.image;
    } catch (e, stackTrace) {
      debugPrint(
        "Wallpaper image load error: $e",
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      isLoadingImage.value = false;
    }
  }

void initializeCrop(
      double displayWidth,
      double displayHeight,
      ) {
    if (cropInitialized) {
      return;
    }

    final size =
        math.min(
          displayWidth,
          displayHeight,
        ) *
            0.86;

    cropSize.value = size;

    cropX.value =
        (displayWidth - size) / 2;

    cropY.value =
        (displayHeight - size) / 2;

    cropInitialized = true;
  }

void moveCrop(
      double dx,
      double dy,
      double displayWidth,
      double displayHeight,
      ) {
    double newX =
        cropX.value + dx;

    double newY =
        cropY.value + dy;

    final maxX =
    math.max(
      0.0,
      displayWidth - cropSize.value,
    );

    final maxY =
    math.max(
      0.0,
      displayHeight - cropSize.value,
    );

    newX =
        newX.clamp(
          0.0,
          maxX,
        );

    newY =
        newY.clamp(
          0.0,
          maxY,
        );

    cropX.value = newX;
    cropY.value = newY;
  }

void resizeCrop(
      String corner,
      double dx,
      double dy,
      double displayWidth,
      double displayHeight,
      ) {
    double x = cropX.value;
    double y = cropY.value;
    double size = cropSize.value;

    const double minSize = 80.0;

if (corner == "topLeft") {
      final delta =
      math.min(dx, dy);

      final newSize =
          size - delta;

      if (newSize >= minSize &&
          x + delta >= 0 &&
          y + delta >= 0) {
        x += delta;
        y += delta;
        size = newSize;
      }
    }

else if (corner == "topRight") {
      final delta =
      math.max(dx, -dy);

      final newSize =
          size + delta;

      if (newSize >= minSize &&
          x + newSize <= displayWidth &&
          y - delta >= 0) {
        y -= delta;
        size = newSize;
      }
    }

else if (corner == "bottomLeft") {
      final delta =
      math.max(-dx, dy);

      final newSize =
          size + delta;

      if (newSize >= minSize &&
          x - delta >= 0 &&
          y + newSize <= displayHeight) {
        x -= delta;
        size = newSize;
      }
    }

else if (corner == "bottomRight") {
      final delta =
      math.max(dx, dy);

      final newSize =
          size + delta;

      if (newSize >= minSize &&
          x + newSize <= displayWidth &&
          y + newSize <= displayHeight) {
        size = newSize;
      }
    }

    cropX.value = x;
    cropY.value = y;
    cropSize.value = size;
  }

void allowChangingAspectRatio() {
    allowAspectRatio.value = true;

    aspectRatio.value = 0;

    ratioIndex.value = 0;
  }

  void changeAspectRatio() {
    allowAspectRatio.value = true;
    ratioIndex.value++;
    if (ratioIndex.value >= ratios.length) {
      ratioIndex.value = 0;
    }
    aspectRatio.value = ratios[ratioIndex.value];
    updateCropForAspectRatio();
  }

  void updateCropForAspectRatio() {
    if (cropSize.value <= 0) {
      return;
    }

final oldSize = cropSize.value;

    if (aspectRatio.value == 0) {
      return;
    }

    final centerX = cropX.value + oldSize / 2;
    final centerY = cropY.value + oldSize / 2;

    cropX.value =
        math.max(0, centerX - oldSize / 2);

    cropY.value =
        math.max(0, centerY - oldSize / 2);
  }
  void rotateImage() {
    rotation.value += 90;

    if (rotation.value >= 360) {
      rotation.value = 0;
    }
  }

void selectWallpaperLocation(
      int location,
      ) {
    selectedLocation.value =
        location;
  }

  Future<File?> createWallpaperFile() async {
    try {
      final originalBytes =
      await imageFile.readAsBytes();

      final codec =
      await ui.instantiateImageCodec(
        originalBytes,
      );

      final frame =
      await codec.getNextFrame();

      ui.Image rotatedImage =
          frame.image;

rotatedImage =
      await rotateUiImage(
        rotatedImage,
        rotation.value,
      );

      final imageWidth =
      rotatedImage.width.toDouble();

      final imageHeight =
      rotatedImage.height.toDouble();

if (aspectRatio.value == 0) {
        return saveImageAsWallpaperFile(
          rotatedImage,
          0,
          0,
          imageWidth,
          imageHeight,
        );
      }

final currentImage =
          image.value;

      if (currentImage == null) {
        return null;
      }

final screenWidth =
          Get.width;

      final screenHeight =
          Get.height;

      final availableWidth =
          screenWidth - 30;

      final availableHeight =
          screenHeight - 190;

      final originalRatio =
          currentImage.width /
              currentImage.height;

      double displayWidth;
      double displayHeight;

      if (originalRatio >
          availableWidth /
              availableHeight) {
        displayWidth =
            availableWidth;

        displayHeight =
            displayWidth /
                originalRatio;
      } else {
        displayHeight =
            availableHeight;

        displayWidth =
            displayHeight *
                originalRatio;
      }

final scaleX =
          imageWidth /
              displayWidth;

      final scaleY =
          imageHeight /
              displayHeight;

double left =
          cropX.value * scaleX;

      double top =
          cropY.value * scaleY;

      double cropWidth =
          cropSize.value * scaleX;

      double cropHeight =
          cropSize.value * scaleY;

left =
          left.clamp(
            0.0,
            math.max(
              0.0,
              imageWidth - 1,
            ),
          );

      top =
          top.clamp(
            0.0,
            math.max(
              0.0,
              imageHeight - 1,
            ),
          );

      cropWidth =
          math.min(
            cropWidth,
            imageWidth - left,
          );

      cropHeight =
          math.min(
            cropHeight,
            imageHeight - top,
          );

      return saveImageAsWallpaperFile(
        rotatedImage,
        left,
        top,
        cropWidth,
        cropHeight,
      );
    } catch (e, stackTrace) {
      debugPrint(
        "Create Wallpaper File Error: $e",
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

Future<File?> saveImageAsWallpaperFile(
      ui.Image image,
      double left,
      double top,
      double cropWidth,
      double cropHeight,
      ) async {
    final recorder =
    ui.PictureRecorder();

    final canvas =
    Canvas(recorder);

    canvas.drawImageRect(
      image,

      Rect.fromLTWH(
        left,
        top,
        cropWidth,
        cropHeight,
      ),

      Rect.fromLTWH(
        0,
        0,
        cropWidth,
        cropHeight,
      ),

      Paint(),
    );

    final picture =
    recorder.endRecording();

    final outputImage =
    await picture.toImage(
      cropWidth.round(),
      cropHeight.round(),
    );

    final byteData =
    await outputImage.toByteData(
      format:
      ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      return null;
    }

    final Uint8List bytes =
    byteData.buffer
        .asUint8List();

    final directory =
    await getTemporaryDirectory();

    final path =
        '${directory.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.png';

    final file =
    File(path);

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    return file;
  }

Future<ui.Image> rotateUiImage(
      ui.Image image,
      int degrees,
      ) {
    final radians =
        degrees * math.pi / 180;

    final width =
    image.width.toDouble();

    final height =
    image.height.toDouble();

    final recorder =
    ui.PictureRecorder();

    final canvas =
    Canvas(recorder);

    final isSideways =
        degrees == 90 ||
            degrees == 270;

    if (isSideways) {
      canvas.translate(
        height / 2,
        width / 2,
      );
    } else {
      canvas.translate(
        width / 2,
        height / 2,
      );
    }

    canvas.rotate(radians);

    canvas.drawImage(
      image,
      Offset(
        -width / 2,
        -height / 2,
      ),
      Paint(),
    );

    final picture =
    recorder.endRecording();

    return picture.toImage(
      isSideways
          ? height.round()
          : width.round(),
      isSideways
          ? width.round()
          : height.round(),
    );
  }

Future<void> applyWallpaper() async {
    if (!Platform.isAndroid) {
      AppToast.show("Direct wallpaper setting is available on Android only.");

      return;
    }

    File? wallpaperFile;

    try {
      Get.dialog(
        const Center(
          child:
          CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
        barrierDismissible: false,
      );

      wallpaperFile =
      await createWallpaperFile();

      if (Get.isDialogOpen == true) {
        Get.back();
      }

      if (wallpaperFile == null ||
          !await wallpaperFile.exists()) {
        AppToast.show("Unable to prepare wallpaper image");

        return;
      }

      final manager =
      WallpaperManagerFlutter();

      final success =
      await manager.setWallpaper(
        wallpaperFile,
        selectedLocation.value,
      );

      if (success) {
        Fluttertoast.showToast(
          msg:
          "Wallpaper set successfully",
          toastLength:
          Toast.LENGTH_SHORT,
          gravity:
          ToastGravity.BOTTOM,
        );

        if (Get.isDialogOpen == true) {
          Get.back();
        }

        Get.back();
      } else {
        AppToast.show("Wallpaper could not be set");
      }
    } catch (e, stackTrace) {
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      debugPrint(
        "WALLPAPER ERROR: $e",
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      AppToast.show("Unable to set wallpaper");
    } finally {
      try {
        if (wallpaperFile != null &&
            await wallpaperFile.exists()) {
          await wallpaperFile.delete();
        }
      } catch (_) {}
    }
  }
}