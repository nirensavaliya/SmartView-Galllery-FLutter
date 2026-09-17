import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinViewerScreen.dart';
import 'package:get/get.dart';

class RecycleBinScreen extends StatelessWidget {
  RecycleBinScreen({super.key});
  RecycleBinController controller = Get.put(RecycleBinController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF1F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xffF1F3F5),
        leading: Obx(() {
          if (controller.isSelectionMode) {
            return const SizedBox.shrink();
          }
          return IconButton(
            onPressed: () {
              Get.back();
            },
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xff222222)),
          );
        }),
        title: Obx(() {
          if (controller.isSelectionMode) {
            return Text(
              "${controller.selectedItems.length} Selected",
              style: TextStyle(
                fontSize: 20,
                fontFamily: FontFamily.robotoMedium,
                color: const Color(0xff222222),
              ),
            );
          }

          return Text(
            "Recycle Bin",
            style: TextStyle(
              fontSize: 20,
              fontFamily: FontFamily.robotoMedium,
              color: const Color(0xff222222),
            ),
          );
        }),

        actions: [
          Obx(() {
            if (controller.isSelectionMode) {
              return IconButton(
                onPressed: () {
                  controller.clearSelection();
                },
                icon: const Icon(Icons.close, color: Color(0xff222222)),
              );
            }
            if (controller.recycleItems.isEmpty) {
              return const SizedBox.shrink();
            }
            return Row(
              children: [
                IconButton(
                  onPressed: () {
                    _showDeleteAllDialog(context);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xff222222),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _showRestoreAllDialog(context);
                  },
                  icon: const Icon(Icons.refresh, color: Color(0xff222222)),
                ),
                const SizedBox(width: 4),
              ],
            );
          }),
        ],
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.isSelectionMode) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await controller.restoreSelectedItems();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.restore, color: Color(0xff333333)),
                        const SizedBox(height: 3),
                        Text(
                          "Restore",
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: FontFamily.robotoMedium,
                            color: const Color(0xff333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: InkWell(
                    onTap: () {
                      _showSelectedDeleteDialog(context);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_outline, color: Colors.red),
                        const SizedBox(height: 3),
                        Text(
                          "Delete",
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: FontFamily.robotoMedium,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.recycleItems.isEmpty) {
          return _emptyView();
        }
        return Column(
          children: [
            _infoBar(),
            Expanded(child: _recycleGrid()),
          ],
        );
      }),
    );
  }

  Widget _infoBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xff555555)),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              "Items in recycle bin clear after 30 days.",
              style: TextStyle(
                fontSize: 13,
                fontFamily: FontFamily.robotoRegular,
                color: const Color(0xff555555),
              ),
            ),
          ),
          const SizedBox(width: 10),

          Obx(
            () => Transform.scale(
              scale: 0.6,
              child: Switch(
                value: controller.autoClearAfter30Days.value,
                onChanged: controller.toggleAutoClear,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/images/recycle-bin-svgrepo-com.png",
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 14),

          Text(
            "Recycle Bin is empty",
            style: TextStyle(
              fontSize: 16,
              fontFamily: FontFamily.robotoMedium,
              color: const Color(0xff333333),
            ),
          ),

          const SizedBox(height: 5),
          Text(
            "Deleted photos and videos will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: FontFamily.robotoRegular,
              color: const Color(0xff888888),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recycleGrid() {
    final grouped = controller.groupedItems;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final month = grouped.keys.elementAt(index);
        final items = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6, bottom: 8),
              child: Text(
                month,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: FontFamily.robotoMedium,
                  color: const Color(0xff333333),
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return _mediaItem(context, items[index]);
              },
            ),

            const SizedBox(height: 14),
          ],
        );
      },
    );
  }

  Widget _mediaItem(BuildContext context, RecycleBinItem item) {
    return Obx(() {
      final selected = controller.isSelected(item);
      final selectionMode = controller.isSelectionMode;
      return GestureDetector(
        onTap: () {
          if (selectionMode) {
            controller.toggleSelection(item);
          } else {
            Get.to(() => RecycleBinViewerScreen(item: item));
          }
        },

        onLongPress: () {
          controller.startSelection(item);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(item.recyclePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xffDDDDDD),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: Color(0xff888888),
                  ),
                );
              },
            ),

            if (item.isVideo)
              const Positioned(
                right: 7,
                bottom: 7,
                child: Icon(
                  Icons.play_circle_fill,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            if (selectionMode)
              Positioned(
                left: 6,
                top: 6,
                child: GestureDetector(
                  onTap: () {
                    controller.toggleSelection(item);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xff2196F3) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xff2196F3)
                            : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            if (selected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showDeleteAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),

          title: Text(
            "Empty Recycle Bin?",
            style: TextStyle(
              fontSize: 18,
              fontFamily: FontFamily.robotoBold,
              color: const Color(0xff222222),
            ),
          ),

          content: Text(
            "Are you sure you want to permanently delete all files from the Recycle Bin?\n\n"
            "Once deleted, these files cannot be restored.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
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
                await controller.permanentlyDeleteAll();
              },
              child: Text(
                "Delete All",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: FontFamily.robotoMedium,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSelectedDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),

          title: Text(
            "Delete selected files?",
            style: TextStyle(
              fontSize: 18,
              fontFamily: FontFamily.robotoBold,
              color: const Color(0xff222222),
            ),
          ),

          content: Text(
            "Are you sure you want to permanently delete the selected files?\n\n"
            "Once deleted, these files cannot be restored.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
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
                await controller.permanentlyDeleteSelectedItems();
              },
              child: Text(
                "Delete",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: FontFamily.robotoMedium,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            "Restore all files?",
            style: TextStyle(
              fontSize: 18,
              fontFamily: FontFamily.robotoBold,
              color: const Color(0xff222222),
            ),
          ),
          content: Text(
            "Are you sure you want to restore all files?",
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
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await controller.restoreAllItems();

                if (Get.isRegistered<PhotosController>()) {
                  final photosController = Get.find<PhotosController>();
                  await photosController.refreshMedia();
                }
                Get.back();
              },
              child: Text(
                "OK",
                style: TextStyle(
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
}
