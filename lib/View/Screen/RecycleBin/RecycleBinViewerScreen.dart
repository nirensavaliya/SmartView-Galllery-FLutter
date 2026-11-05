import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';

class RecycleBinViewerScreen extends StatelessWidget {
  final RecycleBinItem item;

  RecycleBinViewerScreen({super.key, required this.item});

  final Color bgColor = const Color(0xff111111);
  final RecycleBinController recycleBinController =
  Get.find<RecycleBinController>();
  @override
  Widget build(BuildContext context) {
    final date = item.deletedDate;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xff111111),
        automaticallyImplyLeading: false,
        title: Row(
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

            const SizedBox(width: 10),

            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: FontFamily.robotoMedium,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTime(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: FontFamily.robotoRegular,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Image.file(
                  File(item.recyclePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      size: 60,
                      color: Colors.white54,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 15,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showRestoreDialog(context);
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text("Restore"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface(Colors.white),
                          foregroundColor: AppColors.fg(const Color(0xff222222)),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showDeleteDialog(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Delete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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

  String _formatDate(DateTime date) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? "PM" : "AM";

    return "$hour:$minute $period";
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ChromeDialog(
          title: 'Delete permanently?',
          message:
              'This item will be permanently deleted and cannot be restored.',
          actions: [
            ChromeButton.cancel(
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ChromeButton.danger(
              label: 'Delete',
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteAndOpenNext();
              },
            ),
          ],
        );
      },
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ChromeDialog(
          title: 'Restore file?',
          message: 'Are you sure you want to restore this file?',
          actions: [
            ChromeButton.cancel(
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ChromeButton.ok(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await recycleBinController.restoreItem(item);
                if (success) {
                  if (Get.isRegistered<PhotosController>()) {
                    final photosController = Get.find<PhotosController>();
                    await photosController.refreshMedia();
                  }
                  Get.back();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAndOpenNext() async {
    final controller = recycleBinController;

    final currentIndex = controller.recycleItems.indexWhere(
          (e) => e.id == item.id,
    );

    if (currentIndex == -1) {
      Get.back();
      return;
    }

    RecycleBinItem? nextItem;

    if (currentIndex + 1 < controller.recycleItems.length) {
      nextItem = controller.recycleItems[currentIndex + 1];
    }

    final success = await controller.permanentlyDelete(item);

    if (!success) {
      return;
    }

    if (nextItem != null) {
      Get.off(
            () => RecycleBinViewerScreen(
          item: nextItem!,
        ),
        preventDuplicates: false,
      );
    } else {
      Get.back();
    }
  }
}
