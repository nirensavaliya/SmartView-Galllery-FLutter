import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:get/get.dart';

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
            // Positioned(
            //   top: 0,
            //   left: 0,
            //   right: 0,
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 8,
            //       vertical: 10,
            //     ),
            //     decoration: BoxDecoration(
            //       gradient: LinearGradient(
            //         begin: Alignment.topCenter,
            //         end: Alignment.bottomCenter,
            //         colors: [
            //           Colors.black.withOpacity(0.65),
            //           Colors.transparent,
            //         ],
            //       ),
            //     ),
            //     child:
            //   ),
            // ),
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
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xff222222),
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
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            "Delete permanently?",
            style: TextStyle(fontSize: 18, fontFamily: FontFamily.robotoBold),
          ),
          content: Text(
            "This item will be permanently deleted and cannot be restored.",
            style: TextStyle(
              fontSize: 14,
              fontFamily: FontFamily.robotoRegular,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _deleteAndOpenNext();
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
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
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            "Restore file?",
            style: TextStyle(
              fontSize: 18,
              fontFamily: FontFamily.robotoBold,
              color: const Color(0xff222222),
            ),
          ),
          content: Text(
            "Are you sure you want to restore this file?",
            style: TextStyle(
              fontSize: 14,
              fontFamily: FontFamily.robotoRegular,
              color: const Color(0xff555555),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: FontFamily.robotoMedium,
                  color: const Color(0xff555555),
                ),
              ),
            ),

            TextButton(
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
              child: Text(
                "OK",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: FontFamily.robotoMedium,
                  color: const Color(0xff333333),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAndOpenNext() async {
    final controller = recycleBinController;

    // Current item ka index
    final currentIndex = controller.recycleItems.indexWhere(
          (e) => e.id == item.id,
    );

    if (currentIndex == -1) {
      Get.back();
      return;
    }

    // Current ke BAAD wali image pehle save karo
    RecycleBinItem? nextItem;

    if (currentIndex + 1 < controller.recycleItems.length) {
      nextItem = controller.recycleItems[currentIndex + 1];
    }

    // Current image delete karo
    final success = await controller.permanentlyDelete(item);

    if (!success) {
      return;
    }

    // Next image available hai
    if (nextItem != null) {
      // Current viewer ko directly next viewer se replace karo
      Get.off(
            () => RecycleBinViewerScreen(
          item: nextItem!,
        ),
        preventDuplicates: false,
      );
    } else {
      // Last image thi -> Recycle Bin screen
      Get.back();
    }
  }
}
