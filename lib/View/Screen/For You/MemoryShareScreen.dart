import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/MemoryShareController.dart';
import 'package:photo_manager/photo_manager.dart';

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
      MemoryShareController(
        assets: assets,
      ),
      tag: tag,
    );

    return Scaffold(
      backgroundColor: const Color(0xffF1F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xffF1F3F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
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
            color: Colors.black87,
            fontSize: 18,
            fontFamily: FontFamily.robotoBold,
          ),
        ),
        actions: [
          if (isCreateMemory)
            Obx(
                  () {
                final int count =
                    controller.selectedIndexes.length;

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
                        ? Colors.grey
                        : Colors.black,
                    size: 28,
                  ),
                );
              },
            ),

          if (!isCreateMemory && !isChangeCover)
            Obx(
                  () {
                final bool allSelected =
                    controller.selectedIndexes.length ==
                        assets.length &&
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
                    color: Colors.blue,
                    size: 25,
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: assets.isEmpty
                  ? const Center(
                child: Text(
                  'No photos found',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  20,
                ),
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
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                16,
              ),
              child: Obx(
                    () {
                  final int count =
                      controller.selectedIndexes.length;

                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: count == 0 ||
                          controller.isSharing.value
                          ? null
                          : controller.shareSelected,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor:
                        Colors.blue.withOpacity(0.45),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(11),
                        ),
                      ),
                      child: controller.isSharing.value
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        'Share${count > 0 ? ' ($count)' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
    return Obx(
          () {
        final bool selected =
        controller.isSelected(index);

        return GestureDetector(
          onTap: () async {
            if (isChangeCover) {
              final Map<String, dynamic> savedCovers =
              Map<String, dynamic>.from(
                GetStorageData.readObject(
                  GetStorageData.memoryCovers,
                ) ??
                    {},
              );

              // Memory ki unique key
              final String memoryKey =
              controller.assets.isNotEmpty
                  ? controller.assets.first.id
                  : asset.id;

              // Selected image ko cover save karo
              savedCovers[memoryKey] = asset.id;

              await GetStorageData.saveObject(
                GetStorageData.memoryCovers,
                savedCovers,
              );

              // Immediately previous memory screen par jao
              Get.back(result: true);
            } else {
              controller.toggleSelection(index);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ShareThumbnail(
                asset: asset,
              ),

              // Selected overlay
              if (selected)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.08),
                  ),
                ),

              // Selection circle
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Colors.black.withOpacity(0.55)
                        : Colors.black.withOpacity(0.30),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.3,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 15,
                  )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShareThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _ShareThumbnail({
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(
        const ThumbnailSize(500, 500),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == null) {
          return Container(
            color: Colors.grey.shade300,
          );
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