import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinView.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';

class AlbumsScreen extends StatelessWidget {
  AlbumsScreen({super.key});

  final AlbumsController controller = Get.put(
    AlbumsController(),
    permanent: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Albums",
          style: TextStyle(fontSize: 20, fontFamily: FontFamily.robotoBold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              controller.openCamera();
            },
            icon: const Icon(Icons.camera_alt_outlined),
          ),

          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),

            icon: const Icon(Icons.more_vert, size: 24),

            onSelected: (value) {
              if (value == "create") {
                showCreateAlbumDialog(context);
              } else if (value == "filter") {
                showFilterDialog(context);
              } else if (value == "sort") {
                showSortDialog(context);
              } else if (value == "view") {
                controller.isAlbumListView.value =
                    !controller.isAlbumListView.value;
              } else if (value == "columns") {
                showColumnsDialog(context);
              } else if (value == "recycle") {
                Get.to(() => RecycleBinScreen());
                // controller.refreshMedia();
              } else if (value == "setting") {
                // Settings
              }
            },

            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: "create",
                child: Text(
                  "Create new album",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontFamily: FontFamily.robotoRegular,
                  ),
                ),
              ),
              PopupMenuItem<String>(
                value: "filter",
                child: Text(
                  "Filter Media",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontFamily: FontFamily.robotoRegular,
                  ),
                ),
              ),

              PopupMenuItem<String>(
                value: "sort",
                child: Text(
                  "Sort By",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontFamily: FontFamily.robotoRegular,
                  ),
                ),
              ),

              PopupMenuItem<String>(
                value: "view",
                child: Obx(
                  () => Text(
                    controller.isAlbumListView.value
                        ? "View as Grid"
                        : "View as List",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontFamily: FontFamily.robotoRegular,
                    ),
                  ),
                ),
              ),

              PopupMenuItem<String>(
                value: "columns",
                child: Text(
                  "Columns",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontFamily: FontFamily.robotoRegular,
                  ),
                ),
              ),

              PopupMenuItem<String>(
                value: "recycle",
                child: Text(
                  "Recycle Bin",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontFamily: FontFamily.robotoRegular,
                  ),
                ),
              ),

              PopupMenuItem<String>(
                value: "setting",
                child: Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontFamily: FontFamily.robotoRegular,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.isAlbumSelectionMode.value) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          child: Container(
            height: 70,
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _albumActionButton(
                  icon: Icons.push_pin_outlined,
                  title: "Pin",
                  onTap: () {
                    Get.snackbar(
                      "Pin",
                      "Pin functionality will be connected here.",
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),

                _albumActionButton(
                  icon: Icons.delete_outline,
                  title: "Delete",
                  onTap: () async {
                    await controller.deleteSelectedAlbums();
                  },
                ),

                _albumActionButton(
                  icon: Icons.lock_outline,
                  title: "Lock",
                  onTap: () {
                    Get.snackbar(
                      "Lock",
                      "Lock functionality will be connected here.",
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),

                _albumActionButton(
                  icon: Icons.more_vert,
                  title: "More",
                  onTap: () {
                    Get.bottomSheet(
                      Container(
                        color: Colors.white,
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: const Text("Album details"),
                                onTap: () {
                                  Get.back();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const SizedBox();
        }
        final priorityAlbums = controller.priorityAlbums
            .where(
              (album) => controller.albumFilterVisibility[album.id] ?? true,
            )
            .toList();

        final otherAlbums = controller.otherAlbums
            .where(
              (album) => controller.albumFilterVisibility[album.id] ?? true,
            )
            .toList();

        final customAlbums = controller.customAlbums;
        final hasAlbums =
            priorityAlbums.isNotEmpty ||
            otherAlbums.isNotEmpty ||
            customAlbums.isNotEmpty;

        if (!hasAlbums) {
          return const _NoMediaFound();
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) {
            controller.onAlbumScaleStart();
          },
          onScaleUpdate: (details) {
            controller.onAlbumScaleUpdate(details.scale);
          },
          child: controller.isAlbumListView.value
              ? _buildSectionedAlbumListView(
                  context,
                  priorityAlbums,
                  otherAlbums,
                  customAlbums,
                )
              : _buildSectionedAlbumGridView(
                  context,
                  priorityAlbums,
                  otherAlbums,
                  customAlbums,
                ),
        );
      }),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontFamily: FontFamily.robotoBold,
          color: const Color(0xff222222),
        ),
      ),
    );
  }

  Widget _albumGridItem(BuildContext context, AssetPathEntity album) {
    final cover = controller.albumCovers[album.id];
    return GestureDetector(
      onLongPress: () => controller.startAlbumSelection(album.id),
      onTap: () {
        if (controller.isAlbumSelectionMode.value) {
          controller.toggleAlbumSelection(album.id);
        } else {
          Get.to(() => AlbumPhotosScreen(album: album));
        }
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: cover != null
                      ? AlbumCover(asset: cover)
                      : const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              FutureBuilder<int>(
                future: album.assetCountAsync,
                builder: (context, snapshot) => Text(
                  '${snapshot.data ?? 0} items',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          Obx(() {
            if (!controller.isAlbumSelected(album.id))
              return const SizedBox.shrink();
            return Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 17),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _customAlbumGridItem(
    BuildContext context,
    String albumName,
    dynamic albumData,
  ) {
    final assetIds = List<String>.from(albumData["assetIds"] ?? []);
    AssetEntity? coverAsset;
    for (final asset in controller.createAlbumMedia) {
      if (assetIds.contains(asset.id)) {
        coverAsset = asset;
        break;
      }
    }
    return GestureDetector(
      onLongPress: () => controller.startAlbumSelection("custom_$albumName"),
      onTap: () {
        if (controller.isAlbumSelectionMode.value) {
          controller.toggleAlbumSelection("custom_$albumName");
        } else {
          Get.to(
            () => CustomAlbumPhotosScreen(
              albumName: albumName,
              assetIds: assetIds,
              controller: controller,
            ),
          );
        }
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: coverAsset != null
                      ? AlbumCover(asset: coverAsset)
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Icons.photo_album_outlined,
                              size: 55,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${assetIds.length} items',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          Obx(() {
            if (!controller.isAlbumSelected("custom_$albumName"))
              return const SizedBox.shrink();
            return Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 17),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlbumGridSection(
    BuildContext context,
    List<AssetPathEntity> albums,
  ) {
    if (albums.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _albumGridItem(context, albums[index]),
          childCount: albums.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: controller.albumCrossAxisCount.value,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
      ),
    );
  }

  Widget _buildCustomAlbumGridSection(
    BuildContext context,
    RxMap<String, dynamic> customAlbums,
  ) {
    if (customAlbums.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final name = customAlbums.keys.elementAt(index);
          return _customAlbumGridItem(context, name, customAlbums[name]);
        }, childCount: customAlbums.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: controller.albumCrossAxisCount.value,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
      ),
    );
  }

  Widget _buildSectionedAlbumGridView(
    BuildContext context,
    List<AssetPathEntity> priorityAlbums,
    List<AssetPathEntity> otherAlbums,
    RxMap<String, dynamic> customAlbums,
  ) {
    final hasMore = otherAlbums.isNotEmpty || customAlbums.isNotEmpty;
    return CustomScrollView(
      slivers: [
        _buildAlbumGridSection(context, priorityAlbums),
        if (hasMore) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Divider(height: 1),
            ),
          ),
          SliverToBoxAdapter(child: _sectionTitle("More Albums")),
          _buildAlbumGridSection(context, otherAlbums),
          _buildCustomAlbumGridSection(context, customAlbums),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _albumListItem(BuildContext context, AssetPathEntity album) {
    final cover = controller.albumCovers[album.id];
    return GestureDetector(
      onLongPress: () => controller.startAlbumSelection(album.id),
      onTap: () {
        if (controller.isAlbumSelectionMode.value) {
          controller.toggleAlbumSelection(album.id);
        } else {
          Get.to(() => AlbumPhotosScreen(album: album));
        }
      },
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 58,
                child: cover != null
                    ? AlbumCover(asset: cover)
                    : Container(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, snapshot) => Text(
                      '${snapshot.data ?? 0} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Obx(
              () => controller.isAlbumSelected(album.id)
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 17,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customAlbumListItem(
    BuildContext context,
    String albumName,
    dynamic albumData,
  ) {
    final assetIds = List<String>.from(albumData["assetIds"] ?? []);
    AssetEntity? coverAsset;
    for (final asset in controller.createAlbumMedia) {
      if (assetIds.contains(asset.id)) {
        coverAsset = asset;
        break;
      }
    }
    return GestureDetector(
      onLongPress: () => controller.startAlbumSelection("custom_$albumName"),
      onTap: () {
        if (controller.isAlbumSelectionMode.value) {
          controller.toggleAlbumSelection("custom_$albumName");
        } else {
          Get.to(
            () => CustomAlbumPhotosScreen(
              albumName: albumName,
              assetIds: assetIds,
              controller: controller,
            ),
          );
        }
      },
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 58,
                child: coverAsset != null
                    ? AlbumCover(asset: coverAsset)
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.photo_album_outlined,
                          size: 30,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${assetIds.length} items',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Obx(
              () => controller.isAlbumSelected("custom_$albumName")
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 17,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumListSection(
    BuildContext context,
    List<AssetPathEntity> albums,
  ) {
    if (albums.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _albumListItem(context, albums[index]),
          childCount: albums.length,
        ),
      ),
    );
  }

  Widget _buildCustomAlbumListSection(
    BuildContext context,
    RxMap<String, dynamic> customAlbums,
  ) {
    if (customAlbums.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final name = customAlbums.keys.elementAt(index);
          return _customAlbumListItem(context, name, customAlbums[name]);
        }, childCount: customAlbums.length),
      ),
    );
  }

  Widget _buildSectionedAlbumListView(
    BuildContext context,
    List<AssetPathEntity> priorityAlbums,
    List<AssetPathEntity> otherAlbums,
    RxMap<String, dynamic> customAlbums,
  ) {
    final hasMore = otherAlbums.isNotEmpty || customAlbums.isNotEmpty;
    return CustomScrollView(
      slivers: [
        _buildAlbumListSection(context, priorityAlbums),
        if (hasMore) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Divider(height: 1),
            ),
          ),
          SliverToBoxAdapter(child: _sectionTitle("More Albums")),
          _buildAlbumListSection(context, otherAlbums),
          _buildCustomAlbumListSection(context, customAlbums),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _albumActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25, color: Colors.black87),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showCreateAlbumDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Create new album",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: FontFamily.robotoBold,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "Album name",
                    filled: true,
                    fillColor: const Color(0xffE5E5E5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xffEEEEEE),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              return;
                            }

                            Navigator.pop(dialogContext, name);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xff292929),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text("Create"),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // nameController.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    await controller.loadCreateAlbumMedia();

    Get.to(
      () => CreateAlbumMediaScreen(
        albumName: result.trim(),
        controller: controller,
      ),
    );
  }

  Widget _filterRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 35,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                onChanged(!value);
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: FontFamily.robotoRegular,
                    color: const Color(0xff333333),
                  ),
                ),
              ),
            ),
          ),

          GestureDetector(
            onTap: () {
              onChanged(!value);
            },
            child: Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 19,
              color: value ? const Color(0xff444444) : const Color(0xffAAAAAA),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showFilterDialog(BuildContext context) async {
    final RxBool images = controller.filterImages.value.obs;
    final RxBool videos = controller.filterVideos.value.obs;
    final RxBool gifs = controller.filterGifs.value.obs;
    final RxBool rawImages = controller.filterRawImages.value.obs;
    final RxBool svgs = controller.filterSvgs.value.obs;
    final RxBool portraits = controller.filterPortraits.value.obs;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Filter media",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: FontFamily.robotoBold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Obx(
                  () => _filterRow(
                    title: "Images",
                    value: images.value,
                    onChanged: (value) {
                      images.value = value;
                    },
                  ),
                ),

                Obx(
                  () => _filterRow(
                    title: "Videos",
                    value: videos.value,
                    onChanged: (value) {
                      videos.value = value;
                    },
                  ),
                ),

                Obx(
                  () => _filterRow(
                    title: "GIFs",
                    value: gifs.value,
                    onChanged: (value) {
                      gifs.value = value;
                    },
                  ),
                ),

                Obx(
                  () => _filterRow(
                    title: "Raw images",
                    value: rawImages.value,
                    onChanged: (value) {
                      rawImages.value = value;
                    },
                  ),
                ),

                Obx(
                  () => _filterRow(
                    title: "SVGs",
                    value: svgs.value,
                    onChanged: (value) {
                      svgs.value = value;
                    },
                  ),
                ),

                Obx(
                  () => _filterRow(
                    title: "Portraits",
                    value: portraits.value,
                    onChanged: (value) {
                      portraits.value = value;
                    },
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xffEEEEEE),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () async {
                            controller.filterImages.value = images.value;

                            controller.filterVideos.value = videos.value;

                            controller.filterGifs.value = gifs.value;

                            controller.filterRawImages.value = rawImages.value;

                            controller.filterSvgs.value = svgs.value;

                            controller.filterPortraits.value = portraits.value;

                            Navigator.pop(dialogContext);

                            await controller.applyAlbumFilter();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            "OK",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showSortDialog(BuildContext context) async {
    final RxString selectedSort = controller.albumSortBy.value.obs;

    final RxBool selectedOrder = controller.albumSortAscending.value.obs;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Sort by",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: FontFamily.robotoBold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                _sortRow(title: "Album Name", selectedSort: selectedSort),

                _sortRow(title: "File Path", selectedSort: selectedSort),

                _sortRow(title: "File Size", selectedSort: selectedSort),

                _sortRow(title: "Last modified", selectedSort: selectedSort),

                _sortRow(title: "Date taken", selectedSort: selectedSort),

                const Divider(height: 18),

                _orderRow(
                  title: "Ascending",
                  value: true,
                  selectedOrder: selectedOrder,
                ),

                _orderRow(
                  title: "Descending",
                  value: false,
                  selectedOrder: selectedOrder,
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xffEEEEEE),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () async {
                            await controller.applyAlbumSort(
                              sortType: selectedSort.value,
                              ascending: selectedOrder.value,
                            );

                            Navigator.pop(dialogContext);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xff292929),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            "OK",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortRow({required String title, required RxString selectedSort}) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedSort.value = title;
                },
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: FontFamily.robotoRegular,
                    color: const Color(0xff333333),
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                selectedSort.value = title;
              },
              child: Icon(
                selectedSort.value == title
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedSort.value == title
                    ? const Color(0xff444444)
                    : const Color(0xffAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderRow({
    required String title,
    required bool value,
    required RxBool selectedOrder,
  }) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedOrder.value = value;
                },
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: FontFamily.robotoRegular,
                    color: const Color(0xff333333),
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                selectedOrder.value = value;
              },
              child: Icon(
                selectedOrder.value == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedOrder.value == value
                    ? const Color(0xff444444)
                    : const Color(0xffAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumListView(
    BuildContext context,
    List<AssetPathEntity> normalAlbums,
    RxMap<String, dynamic> customAlbums,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      itemCount: normalAlbums.length + customAlbums.length,

      itemBuilder: (context, index) {
        if (index < normalAlbums.length) {
          final album = normalAlbums[index];
          final cover = controller.albumCovers[album.id];

          return GestureDetector(
            onLongPress: () {
              controller.startAlbumSelection(album.id);
            },

            onTap: () {
              if (controller.isAlbumSelectionMode.value) {
                controller.toggleAlbumSelection(album.id);
              } else {
                Get.to(() => AlbumPhotosScreen(album: album));
              }
            },

            child: Container(
              height: 72,
              margin: const EdgeInsets.symmetric(vertical: 4),

              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 58,
                      height: 58,

                      child: cover != null
                          ? AlbumCover(asset: cover)
                          : Container(color: Colors.grey.shade300),
                    ),
                  ),

                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 3),

                        FutureBuilder<int>(
                          future: album.assetCountAsync,

                          builder: (context, snapshot) {
                            return Text(
                              '${snapshot.data ?? 0} items',

                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // SELECTION
                  Obx(() {
                    if (!controller.isAlbumSelected(album.id)) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: 24,
                      height: 24,

                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 17,
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }

        final customIndex = index - normalAlbums.length;

        final albumName = customAlbums.keys.elementAt(customIndex);

        final albumData = customAlbums[albumName];

        final List<String> assetIds = List<String>.from(
          albumData["assetIds"] ?? [],
        );

        AssetEntity? coverAsset;

        for (final asset in controller.createAlbumMedia) {
          if (assetIds.contains(asset.id)) {
            coverAsset = asset;
            break;
          }
        }

        return GestureDetector(
          onLongPress: () {
            controller.startAlbumSelection("custom_$albumName");
          },

          onTap: () {
            if (controller.isAlbumSelectionMode.value) {
              controller.toggleAlbumSelection("custom_$albumName");
            } else {
              Get.to(
                () => CustomAlbumPhotosScreen(
                  albumName: albumName,
                  assetIds: assetIds,
                  controller: controller,
                ),
              );
            }
          },

          child: Container(
            height: 72,

            margin: const EdgeInsets.symmetric(vertical: 4),

            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),

                  child: SizedBox(
                    width: 58,
                    height: 58,

                    child: coverAsset != null
                        ? AlbumCover(asset: coverAsset)
                        : Container(
                            color: Colors.grey.shade300,

                            child: const Icon(
                              Icons.photo_album_outlined,
                              size: 30,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        albumName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '${assetIds.length} items',

                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                Obx(() {
                  if (!controller.isAlbumSelected("custom_$albumName")) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    width: 24,
                    height: 24,

                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.check,
                      color: Colors.black,
                      size: 17,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showColumnsDialog(BuildContext context) async {
    final RxInt selectedColumns = controller.albumCrossAxisCount.value.obs;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Columns",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: FontFamily.robotoBold,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                _albumColumnRow(
                  title: "2 Grid",
                  value: 2,
                  selectedColumns: selectedColumns,
                ),

                _albumColumnRow(
                  title: "3 Grid",
                  value: 3,
                  selectedColumns: selectedColumns,
                ),

                _albumColumnRow(
                  title: "4 Grid",
                  value: 4,
                  selectedColumns: selectedColumns,
                ),

                _albumColumnRow(
                  title: "5 Grid",
                  value: 5,
                  selectedColumns: selectedColumns,
                ),

                _albumColumnRow(
                  title: "6 Grid",
                  value: 6,
                  selectedColumns: selectedColumns,
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () {
                      controller.albumCrossAxisCount.value =
                          selectedColumns.value;

                      GetStorageData.saveString(
                        GetStorageData.photosGridColumns,
                        selectedColumns.value.toString(),
                      );

                      Navigator.pop(dialogContext);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xff292929),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text("OK", style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _albumColumnRow({
    required String title,
    required int value,
    required RxInt selectedColumns,
  }) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedColumns.value = value;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: FontFamily.robotoRegular,
                      color: const Color(0xff333333),
                    ),
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                selectedColumns.value = value;
              },
              child: Icon(
                selectedColumns.value == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedColumns.value == value
                    ? const Color(0xff444444)
                    : const Color(0xffAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateAlbumMediaScreen extends StatelessWidget {
  final String albumName;
  final AlbumsController controller;

  const CreateAlbumMediaScreen({
    super.key,
    required this.albumName,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF1F3F5),

      appBar: AppBar(
        backgroundColor: const Color(0xffF1F3F5),
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back_ios),
        ),

        title: Text(
          albumName,
          style: TextStyle(fontSize: 20, fontFamily: FontFamily.robotoBold),
        ),
      ),

      body: Obx(() {
        if (controller.isCreateAlbumLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.createAlbumMedia.isEmpty) {
          return const _NoMediaFound();
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 90),

          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),

          itemCount: controller.createAlbumMedia.length,

          itemBuilder: (context, index) {
            final asset = controller.createAlbumMedia[index];

            return GestureDetector(
              onTap: () {
                controller.toggleCreateAlbumSelection(asset);
              },

              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List?>(
                    future: asset.thumbnailDataWithSize(
                      const ThumbnailSize(300, 300),
                    ),

                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return Container(color: Colors.grey.shade300);
                      }

                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    },
                  ),

                  // VIDEO ICON
                  if (asset.type == AssetType.video)
                    const Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),

                  // SELECTION
                  Obx(() {
                    final selected = controller.isCreateAlbumSelected(asset);

                    return Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: selected ? Colors.black : Colors.white70,
                          shape: BoxShape.circle,
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 17,
                              )
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      }),

      bottomNavigationBar: Obx(() {
        final count = controller.selectedAlbumMediaIds.length;

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: Colors.white,
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: count == 0 || controller.isCreateAlbumLoading.value
                    ? null
                    : () async {
                        print(
                          "IMPORT CLICKED => ${controller.selectedAlbumMediaIds.length}",
                        );

                        await controller.createAlbumAndImport(
                          albumName: albumName,
                        );

                        print("IMPORT METHOD COMPLETED");
                      },

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff292929),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),

                child: Text(
                  count == 0 ? "Import" : "Import ($count)",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class AlbumCover extends StatelessWidget {
  final AssetEntity asset;

  const AlbumCover({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(500, 500)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: double.infinity,
            height: double.infinity,
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox(
            width: double.infinity,
            height: double.infinity,
          );
        }

        return Image.memory(
          snapshot.data!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class AlbumPhotosScreen extends StatelessWidget {
  final AssetPathEntity album;

  AlbumPhotosScreen({super.key, required this.album});

  late final AlbumPhotosController controller = Get.put(
    AlbumPhotosController(album: album),
    tag: album.id,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF1F3F5),

      appBar: AppBar(
        backgroundColor: const Color(0xffF1F3F5),
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: Text(
          album.name,
          style: TextStyle(fontSize: 20, fontFamily: FontFamily.robotoBold),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.media.isEmpty) {
          return const SizedBox();
        }
        if (controller.media.isEmpty) {
          return const _NoMediaFound();
        }

        final grouped = controller.groupedMedia;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) {
            controller.onGridScaleStart();
          },
          onScaleUpdate: (details) {
            controller.onGridScaleUpdate(details.scale);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 30),

            itemCount: _getTotalItemCount(
              grouped,
              controller.crossAxisCount.value,
            ),

            itemBuilder: (context, index) {
              return _buildItem(
                context,
                grouped,
                index,
                controller.crossAxisCount.value,
              );
            },
          ),
        );
      }),
    );
  }

  int _getTotalItemCount(
    Map<DateTime, List<AssetEntity>> grouped,
    int columns,
  ) {
    int count = 0;
    for (final list in grouped.values) {
      count++;
      count += (list.length + columns - 1) ~/ columns;
    }

    return count;
  }

  Widget _buildItem(
    BuildContext context,
    Map<DateTime, List<AssetEntity>> grouped,
    int index,
    int columns,
  ) {
    int currentIndex = 0;

    for (final entry in grouped.entries) {
      final DateTime date = entry.key;
      final List<AssetEntity> list = entry.value;
      if (index == currentIndex) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            formatGalleryDate(date),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        );
      }
      currentIndex++;
      final int rowCount = (list.length + columns - 1) ~/ columns;
      for (int row = 0; row < rowCount; row++) {
        if (index == currentIndex) {
          final int start = row * columns;

          final int end = (start + columns > list.length)
              ? list.length
              : start + columns;

          final List<AssetEntity> rowMedia = list.sublist(start, end);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final asset in rowMedia)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: GestureDetector(
                        onTap: () {
                          Get.to(
                                () => PhotoViewScreen(
                              asset: asset,
                              albumMedia: controller.media,
                            ),
                          );
                        },
                        child: AlbumMediaItem(asset: asset),
                      ),
                    ),
                  ),
                for (int i = rowMedia.length; i < columns; i++)
                  const Expanded(child: SizedBox()),
              ],
            ),
          );
        }

        currentIndex++;
      }
    }
    return const SizedBox();
  }
}

class AlbumMediaItem extends StatelessWidget {
  final AssetEntity asset;

  const AlbumMediaItem({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(300, 300)),

          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return Container(color: Colors.grey.shade300);
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),

                if (asset.type == AssetType.video)
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String formatGalleryDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return "$day.$month.${date.year}";
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
              fontFamily: FontFamily.robotoBold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "All your photos and videos will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: FontFamily.robotoRegular,
              color: Color(0xff999999),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomAlbumPhotosScreen extends StatelessWidget {
  final String albumName;
  final List<String> assetIds;
  final AlbumsController controller;

  const CustomAlbumPhotosScreen({
    super.key,
    required this.albumName,
    required this.assetIds,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF1F3F5),

      appBar: AppBar(
        backgroundColor: const Color(0xffF1F3F5),
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back_ios),
        ),

        title: Text(
          albumName,
          style: TextStyle(fontSize: 20, fontFamily: FontFamily.robotoBold),
        ),
      ),

      body: FutureBuilder<List<AssetEntity>>(
        future: controller.getCustomAlbumMedia(assetIds),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<AssetEntity> media = snapshot.data ?? [];

          if (media.isEmpty) {
            return const _NoMediaFound();
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 30),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),

            itemCount: media.length,

            itemBuilder: (context, index) {
              final asset = media[index];

              return GestureDetector(
                onTap: () {
                  Get.to(
                    () => PhotoViewScreen(
                      asset: asset,
                      albumMedia: media,
                      customAlbumName: albumName,
                    ),
                  );
                },
                child: AlbumMediaItem(asset: asset),
              );
            },
          );
        },
      ),
    );
  }
}
