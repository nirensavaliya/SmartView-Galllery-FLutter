import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/WallpaperController.dart';
import 'package:get/get.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

class WallpaperScreen extends StatelessWidget {
  final File imageFile;

  const WallpaperScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      WallpaperController(imageFile: imageFile),
      tag: imageFile.path,
    );

    return Scaffold(
      backgroundColor: const Color(0xff050a18),

      body: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // APP BAR
            // =====================================================
            Container(
              height: 52,
              color: const Color(0xff151515),

              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Get.back();
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Gallery",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // CHECK
                  // =================================================
                  IconButton(
                    onPressed: () => _showWallpaperDialog(context, controller),
                    icon: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),

                  // =================================================
                  // MORE POPUP
                  // =================================================
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,

                    color: Colors.white,

                    elevation: 4,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),

                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 24,
                    ),

                    onSelected: (value) {
                      if (value == "aspect_ratio") {
                        controller.allowChangingAspectRatio();
                      }
                    },

                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: "aspect_ratio",

                        child: Obx(
                          () => Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "Allow changing the aspect ratio",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),

                              if (controller.allowAspectRatio.value)
                                const Icon(
                                  Icons.check,
                                  color: Colors.black87,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // =====================================================
            // IMAGE / CROP
            // =====================================================
            Expanded(
              child: Obx(() {
                if (controller.isLoadingImage.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final image = controller.image.value;

                if (image == null) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 60,
                    ),
                  );
                }

                return _buildCropArea(context, controller, image);
              }),
            ),

            // =====================================================
            // BOTTOM BAR
            // =====================================================
            Container(
              height: 60,
              color: const Color(0xff171b29),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [
                  Obx(
                    () => GestureDetector(
                      onTap: controller.changeAspectRatio,

                      child: Opacity(
                        opacity: controller.allowAspectRatio.value ? 1 : 0.45,

                        child: const Icon(
                          Icons.open_with,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: controller.rotateImage,
                    child: const Icon(
                      Icons.rotate_right,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // CROP AREA UI
  // ===========================================================

  Widget _buildCropArea(
    BuildContext context,
    WallpaperController controller,
    ui.Image image,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    final screenHeight = MediaQuery.of(context).size.height;

    final availableWidth = screenWidth - 30;

    final availableHeight = screenHeight - 190;

    final imageRatio = image.width / image.height;

    double displayWidth;
    double displayHeight;

    if (imageRatio > availableWidth / availableHeight) {
      displayWidth = availableWidth;

      displayHeight = displayWidth / imageRatio;
    } else {
      displayHeight = availableHeight;

      displayWidth = displayHeight * imageRatio;
    }

    controller.initializeCrop(displayWidth, displayHeight);

    return Center(
      child: SizedBox(
        width: displayWidth,
        height: displayHeight,

        child: Stack(
          children: [
            // =====================================================
            // IMAGE
            // =====================================================
            Positioned.fill(
              child: Transform.rotate(
                angle: controller.rotation.value * math.pi / 180,

                child: Image.file(
                  controller.imageFile,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),

            // =====================================================
            // CROP SQUARE
            // =====================================================
            Positioned(
              left: controller.cropX.value,

              top: controller.cropY.value,

              width: controller.cropSize.value,

              height: controller.cropSize.value,

              child: GestureDetector(
                // =================================================
                // MOVE
                // =================================================
                onPanUpdate: (details) {
                  controller.moveCrop(
                    details.delta.dx,
                    details.delta.dy,
                    displayWidth,
                    displayHeight,
                  );
                },

                child: Stack(
                  children: [
                    // =============================================
                    // WHITE BORDER
                    // =============================================
                    Positioned.fill(
                      child: CustomPaint(painter: _CropPainter()),
                    ),

                    // =============================================
                    // TOP LEFT
                    // =============================================
                    _resizeHandle(
                      controller,
                      "topLeft",
                      displayWidth,
                      displayHeight,
                      left: -10,
                      top: -10,
                    ),

                    // =============================================
                    // TOP RIGHT
                    // =============================================
                    _resizeHandle(
                      controller,
                      "topRight",
                      displayWidth,
                      displayHeight,
                      right: -10,
                      top: -10,
                    ),

                    // =============================================
                    // BOTTOM LEFT
                    // =============================================
                    _resizeHandle(
                      controller,
                      "bottomLeft",
                      displayWidth,
                      displayHeight,
                      left: -10,
                      bottom: -10,
                    ),

                    // =============================================
                    // BOTTOM RIGHT
                    // =============================================
                    _resizeHandle(
                      controller,
                      "bottomRight",
                      displayWidth,
                      displayHeight,
                      right: -10,
                      bottom: -10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // RESIZE HANDLE
  // ===========================================================

  Widget _resizeHandle(
    WallpaperController controller,
    String corner,
    double displayWidth,
    double displayHeight, {
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,

      width: 28,
      height: 28,

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onPanUpdate: (details) {
          controller.resizeCrop(
            corner,
            details.delta.dx,
            details.delta.dy,
            displayWidth,
            displayHeight,
          );
        },

        child: const SizedBox(),
      ),
    );
  }

  // ===========================================================
  // WALLPAPER DIALOG
  // ===========================================================

  Future<void> _showWallpaperDialog(
    BuildContext context,
    WallpaperController controller,
  ) async {
    await showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,

          title: const Text(
            "Set wallpaper",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),

          content: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                // ===============================================
                // HOME
                // ===============================================
                RadioListTile<int>(
                  value: WallpaperManagerFlutter.homeScreen,

                  groupValue: controller.selectedLocation.value,

                  title: const Text("Home screen"),

                  onChanged: (value) {
                    if (value != null) {
                      controller.selectWallpaperLocation(value);
                    }
                  },
                ),

                // ===============================================
                // LOCK
                // ===============================================
                RadioListTile<int>(
                  value: WallpaperManagerFlutter.lockScreen,

                  groupValue: controller.selectedLocation.value,

                  title: const Text("Lock screen"),

                  onChanged: (value) {
                    if (value != null) {
                      controller.selectWallpaperLocation(value);
                    }
                  },
                ),

                // ===============================================
                // BOTH
                // ===============================================
                RadioListTile<int>(
                  value: WallpaperManagerFlutter.bothScreens,

                  groupValue: controller.selectedLocation.value,

                  title: const Text("Both"),

                  onChanged: (value) {
                    if (value != null) {
                      controller.selectWallpaperLocation(value);
                    }
                  },
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Get.back();
              },
              child: const Text("CANCEL"),
            ),

            ElevatedButton(
              onPressed: () {
                Get.back();

                controller.applyWallpaper();
              },
              child: const Text("APPLY"),
            ),
          ],
        );
      },
    );
  }
}

// =================================================================
// CROP PAINTER
// =================================================================

class _CropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ===========================================================
    // THIN OUTER BORDER
    // ===========================================================

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      borderPaint,
    );

    // ===========================================================
    // CORNERS
    // ===========================================================

    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const cornerLength = 16.0;

    // TOP LEFT
    canvas.drawLine(
      const Offset(0, 0),
      const Offset(cornerLength, 0),
      cornerPaint,
    );

    canvas.drawLine(
      const Offset(0, 0),
      const Offset(0, cornerLength),
      cornerPaint,
    );

    // TOP RIGHT
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      cornerPaint,
    );

    // BOTTOM LEFT
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      cornerPaint,
    );

    // BOTTOM RIGHT
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return false;
  }
}
