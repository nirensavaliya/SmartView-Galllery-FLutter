import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinViewerScreen.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';

class RecycleBinScreen extends StatelessWidget {
  RecycleBinScreen({super.key});
  RecycleBinController controller = Get.put(RecycleBinController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InnerChrome.page,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Obx(() {
          if (controller.isSelectionMode) {
            return Text(
              "${controller.selectedItems.length} Selected",
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                color: InnerChrome.ink,
              ),
            );
          }

          return Text(
            "Recycle Bin",
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: InnerChrome.ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          );
        }),
        leading: Obx(() {
          if (controller.isSelectionMode) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _RecycleCircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 18,
              onTap: Get.back,
            ),
          );
        }),
        leadingWidth: 64,
        actions: [
          Obx(() {
            if (controller.isSelectionMode) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _RecycleCircleButton(
                  icon: Icons.close_rounded,
                  onTap: controller.clearSelection,
                ),
              );
            }
            if (controller.recycleItems.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  _RecycleCircleButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: () => _showDeleteAllDialog(context),
                  ),
                  const SizedBox(width: 8),
                  _RecycleCircleButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => _showRestoreAllDialog(context),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.isSelectionMode) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: InnerChrome.sheet,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: InnerChrome.line),
                boxShadow: InnerChrome.lift,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _RecycleBarButton(
                      icon: Icons.delete_outline_rounded,
                      label: "Delete",
                      background: InnerChrome.dangerBg,
                      foreground: InnerChrome.danger,
                      onTap: () => _showSelectedDeleteDialog(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: _RecycleBarButton(
                      icon: Icons.restore_rounded,
                      label: "Restore",
                      background: InnerChrome.pick,
                      foreground: Colors.white,
                      filled: true,
                      onTap: controller.restoreSelectedItems,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: SplashLoader());
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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: InnerChrome.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: InnerChrome.line),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: InnerChrome.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Items in recycle bin clear after 30 days.",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                color: InnerChrome.muted,
              ),
            ),
          ),
          Obx(
            () => Switch(
              value: controller.autoClearAfter30Days.value,
              onChanged: controller.toggleAutoClear,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return InnerChrome.muted;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return InnerChrome.accent;
                }
                return InnerChrome.alt;
              }),
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
              fontWeight: FontWeight.w600,
              color: InnerChrome.ink,
            ),
          ),

          const SizedBox(height: 5),
          Text(
            "Deleted photos and videos will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: InnerChrome.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recycleGrid() {
    final grouped = controller.groupedItems;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final month = grouped.keys.elementAt(index);
        final items = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 0, top: 18, bottom: 10),
              child: Text(
                month,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Plus Jakarta Sans',
                  color: InnerChrome.ink,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
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
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: InnerChrome.pick, width: 2)
                : null,
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(item.recyclePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return ColoredBox(
                  color: InnerChrome.alt,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: InnerChrome.muted,
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
            if (selected) Container(color: Colors.black26),
            if (selectionMode)
              Positioned(
                left: 8,
                top: 8,
                child: GestureDetector(
                  onTap: () {
                    controller.toggleSelection(item);
                  },
                  child: selected
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: InnerChrome.pick,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: InnerChrome.pickInk,
                          ),
                        )
                      : Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black26,
                            border: Border.all(
                              color: Colors.white54,
                              width: 1.5,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
        ),
        ),
      );
    });
  }

  void _showDeleteAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ChromeDialog(
          title: 'Empty Recycle Bin?',
          message:
              'Are you sure you want to permanently delete all files from the Recycle Bin?\n\nOnce deleted, these files cannot be restored.',
          actions: [
            ChromeButton.cancel(
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ChromeButton.danger(
              label: 'Delete All',
              onPressed: () async {
                Navigator.pop(dialogContext);
                await controller.permanentlyDeleteAll();
              },
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
        return ChromeDialog(
          title: 'Delete selected files?',
          message:
              'Are you sure you want to permanently delete the selected files?\n\nOnce deleted, these files cannot be restored.',
          actions: [
            ChromeButton.cancel(
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ChromeButton.danger(
              label: 'Delete',
              onPressed: () async {
                Navigator.pop(dialogContext);
                await controller.permanentlyDeleteSelectedItems();
              },
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
        return ChromeDialog(
          title: 'Restore all files?',
          message: 'Are you sure you want to restore all files?',
          actions: [
            ChromeButton.cancel(
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ChromeButton.ok(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await controller.restoreAllItems();
                if (Get.isRegistered<PhotosController>()) {
                  final photosController = Get.find<PhotosController>();
                  await photosController.refreshMedia();
                }
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }
}

class _RecycleCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  const _RecycleCircleButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: InnerChrome.alt,
          shape: BoxShape.circle,
          border: Border.all(color: InnerChrome.line),
        ),
        child: Icon(icon, size: iconSize, color: InnerChrome.ink),
      ),
    );
  }
}

class _RecycleBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool filled;

  const _RecycleBarButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: filled ? null : background,
          gradient: filled ? InnerChrome.actionGradient : null,
          boxShadow: filled ? InnerChrome.actionShadow : null,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
