import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/MemoryShareController.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class MemoryShareScreen extends StatelessWidget {
  final String title;
  final List<AssetEntity> assets;
  final bool isChangeCover;
  final bool isCreateMemory;
  final String? createMemoryTitle;
  const MemoryShareScreen({
    super.key,
    required this.title,
    required this.assets,
    this.isChangeCover = false,
    this.isCreateMemory = false,
    this.createMemoryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final String tag =
        'memory_share_${title}_${assets.isNotEmpty ? assets.first.id : ''}';

    final MemoryShareController controller = Get.put(
      MemoryShareController(assets: assets),
      tag: tag,
    );

    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: InnerChrome.ink,
            size: 20,
          ),
          onPressed: () {
            Get.back();
          },
        ),
        title: Text(
          isCreateMemory
              ? (createMemoryTitle ?? title)
              : isChangeCover
              ? 'Change Cover'
              : 'Share',
          style: TextStyle(
            color: InnerChrome.ink,
            fontSize: 18,
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (isCreateMemory)
            Obx(() {
              final int count = controller.selectedIndexes.length;

              return IconButton(
                onPressed: count == 0
                    ? null
                    : () async {
                        await controller.createMemory(
                          createMemoryTitle ?? title,
                        );
                        Get.back(result: true);
                      },
                icon: Icon(
                  Icons.check,
                  color: count == 0
                      ? InnerChrome.muted
                      : InnerChrome.accent,
                  size: 28,
                ),
              );
            }),

          if (!isCreateMemory && !isChangeCover)
            Obx(() {
              final bool allSelected =
                  controller.selectedIndexes.length == assets.length &&
                  assets.isNotEmpty;

              return IconButton(
                onPressed: () {
                  if (allSelected) {
                    controller.clearSelection();
                  } else {
                    controller.selectAll();
                  }
                },
                icon: Icon(
                  allSelected
                      ? Icons.deselect_outlined
                      : Icons.select_all_outlined,
                  color: InnerChrome.pick,
                  size: 25,
                ),
              );
            }),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: assets.isEmpty
                  ? const _NoMediaFound()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1,
                          ),
                      itemCount: assets.length,
                      itemBuilder: (context, index) {
                        return _SharePhotoItem(
                          asset: assets[index],
                          index: index,
                          controller: controller,
                          isChangeCover: isChangeCover,
                        );
                      },
                    ),
            ),

            if (!isChangeCover && !isCreateMemory)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Obx(() {
                  final int count = controller.selectedIndexes.length;

                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _MemoryShareButton(
                      enabled: count > 0 && !controller.isSharing.value,
                      busy: controller.isSharing.value,
                      label: 'Share${count > 0 ? ' ($count)' : ''}',
                      onTap: controller.shareSelected,
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
class _NoMediaFound extends StatelessWidget {
  const _NoMediaFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            "assets/images/Empty.webp",
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 8),

          Text(
            "No Album available!",
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              color: InnerChrome.ink,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "All your photos and videos will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Plus Jakarta Sans',
              color: InnerChrome.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharePhotoItem extends StatelessWidget {
  final AssetEntity asset;
  final int index;
  final MemoryShareController controller;
  final bool isChangeCover;

  const _SharePhotoItem({
    required this.asset,
    required this.index,
    required this.controller,
    required this.isChangeCover,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool selected = controller.isSelected(index);

      return GestureDetector(
        onTap: () async {
          if (isChangeCover) {
            final Map<String, dynamic> savedCovers = Map<String, dynamic>.from(
              GetStorageData.readObject(GetStorageData.memoryCovers) ?? {},
            );

            final String memoryKey = controller.assets.isNotEmpty
                ? controller.assets.first.id
                : asset.id;

            savedCovers[memoryKey] = asset.id;

            await GetStorageData.saveObject(
              GetStorageData.memoryCovers,
              savedCovers,
            );

            Get.back(result: true);
          } else {
            controller.toggleSelection(index);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ShareThumbnail(asset: asset),

            if (selected) Container(color: Colors.black26),

            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? InnerChrome.pick
                      : Colors.black26,
                  border: Border.all(
                    color: selected
                        ? InnerChrome.pick
                        : Colors.white54,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: InnerChrome.pickInk,
                        size: 15,
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ShareThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _ShareThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(500, 500)),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return ColoredBox(color: InnerChrome.alt);
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}

class _MemoryShareButton extends StatelessWidget {
  const _MemoryShareButton({
    required this.enabled,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !busy;
    const radius = BorderRadius.all(Radius.circular(16));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: canTap
            ? [
                ...InnerChrome.actionShadow,
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: canTap ? onTap : null,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: canTap ? null : InnerChrome.disabled,
              gradient: canTap
                  ? InnerChrome.actionGradient
                  : null,
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
