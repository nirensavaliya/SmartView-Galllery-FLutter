import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/UtilityMedia/controller/FavoriteImportController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

class FavoriteImportScreen extends StatefulWidget {
  const FavoriteImportScreen({super.key});

  @override
  State<FavoriteImportScreen> createState() => _FavoriteImportScreenState();
}

class _FavoriteImportScreenState extends State<FavoriteImportScreen> {
  FavoriteImportController controller = Get.put(FavoriteImportController());

  @override
  void dispose() {
    Get.delete<FavoriteImportController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InnerChrome.page,

      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: Get.back,
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: InnerChrome.ink,
          ),
        ),

        title: Obx(
          () => Text(
            controller.selectedIds.isEmpty
                ? 'Add to Favorites'
                : '${controller.selectedIds.length} Selected',
            style: TextStyle(
              color: InnerChrome.ink,
              fontSize: 19,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        actions: [
          GestureDetector(
            onTap: controller.selectAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: InnerChrome.pick,
                      width: 1.5,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                Text(
                  'Select',
                  style: TextStyle(
                    color: InnerChrome.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),

      body: Obx(() {
        if (controller.isLoading.value && controller.media.isEmpty) {
          return const Center(child: SplashLoader());
        }

        if (controller.media.isEmpty) {
          return Center(
            child: Text(
              'No photos or videos found',
              style: TextStyle(color: InnerChrome.muted),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: controller.media.length,
          itemBuilder: (context, index) {
            final asset = controller.media[index];

            return Obx(() {
              final selected = controller.isSelected(asset);

              return GestureDetector(
                onTap: () {
                  controller.toggleSelection(asset);
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
                        FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(
                            const ThumbnailSize(500, 500),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.data == null) {
                              return ColoredBox(color: InnerChrome.alt);
                            }

                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            );
                          },
                        ),

                        if (asset.type == AssetType.video)
                          const Positioned(
                            left: 6,
                            bottom: 6,
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),

                        if (selected) Container(color: Colors.black26),

                        Positioned(
                          top: 8,
                          left: 8,
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
                                    color: InnerChrome.pickInk,
                                    size: 16,
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
                      ],
                    ),
                  ),
                ),
              );
            });
          },
        );
      }),

      bottomNavigationBar: Obx(() {
        if (controller.selectedIds.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedAssets = controller.media
            .where((asset) => controller.selectedIds.contains(asset.id))
            .toList();
        return SafeArea(
          top: false,
          child: Container(
            color: InnerChrome.page,
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Text(
                        '${selectedAssets.length} Selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Spacer(),

                      IconButton(
                        onPressed: controller.clearSelection,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                  color: Color(0xff383838),
                ),

                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    itemCount: selectedAssets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final asset = selectedAssets[index];

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: FutureBuilder<Uint8List?>(
                                future: asset.thumbnailDataWithSize(
                                  const ThumbnailSize(120, 120),
                                ),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Container(
                                      color: const Color(0xff333333),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),

                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () {
                                controller.toggleSelection(asset);
                              },
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _FavoriteDoneButton(
                      onTap: controller.addSelectedToFavorites,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _FavoriteDoneButton extends StatelessWidget {
  const _FavoriteDoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(26));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: InnerChrome.actionShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: const BoxDecoration(
              borderRadius: radius,
              gradient: InnerChrome.actionGradient,
            ),
            child: const Center(
              child: Text(
                'Done',
                style: TextStyle(
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
