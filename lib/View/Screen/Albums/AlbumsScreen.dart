import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinView.dart';
import 'package:gallery_photos/View/Setting/SettingScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class AlbumsScreen extends StatefulWidget {
  AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final AlbumsController controller = Get.isRegistered<AlbumsController>()
      ? Get.find<AlbumsController>()
      : Get.put(AlbumsController(), permanent: true);
  Timer? _scrollButtonTimer;

  final RxBool _showScrollButton = false.obs;
  final RxString _floatingDate = ''.obs;

  bool isScrolling = false;
  final Map<String, GlobalKey> albumKeys = {};

  final GlobalKey albumScrollAreaKey = GlobalKey();

  GlobalKey _getAlbumKey(String albumId) {
    return albumKeys.putIfAbsent(albumId, () => GlobalKey());
  }

  void _handleAlbumDragSelection(Offset globalPosition) {
    if (!controller.isAlbumDragSelecting.value) {
      return;
    }

    for (final entry in albumKeys.entries) {
      final BuildContext? itemContext = entry.value.currentContext;

      if (itemContext == null) {
        continue;
      }

      final RenderBox? itemBox = itemContext.findRenderObject() as RenderBox?;

      if (itemBox == null || !itemBox.hasSize) {
        continue;
      }

      final Offset itemPosition = itemBox.localToGlobal(Offset.zero);

      final Rect itemRect = itemPosition & itemBox.size;

      if (itemRect.contains(globalPosition)) {
        controller.selectAlbumDuringDrag(entry.key);
        return;
      }
    }
  }

  void _handleAlbumAutoScroll(Offset globalPosition) {
    final RenderBox? box =
        albumScrollAreaKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null || !box.hasSize) {
      return;
    }

    final Offset localPosition = box.globalToLocal(globalPosition);

    controller.updateAlbumAutoScroll(
      localY: localPosition.dy,
      viewportHeight: box.size.height,
    );
  }
  void _showScrollControls() {
    if (!mounted) return;

    _showScrollButton.value = true;

    _scrollButtonTimer?.cancel();

    _scrollButtonTimer = Timer(
      const Duration(milliseconds: 1200),
          () {
        if (!mounted) return;
        _showScrollButton.value = false;
      },
    );
  }

  void _scrollUp() {
    _showScrollControls();

    if (!controller.albumScrollController.hasClients) return;

    final current = controller.albumScrollController.offset;

    final target = (current - 300).clamp(
      0.0,
      controller.albumScrollController.position.maxScrollExtent,
    );

    controller.albumScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _scrollDown() {
    _showScrollControls();

    if (!controller.albumScrollController.hasClients) return;

    final current = controller.albumScrollController.offset;

    final target = (current + 300).clamp(
      0.0,
      controller.albumScrollController.position.maxScrollExtent,
    );

    controller.albumScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }
  @override
  Widget build(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    final Color page = light ? const Color(0xFFF6F7F9) : Colors.black;
    final Color ink = light ? const Color(0xFF111827) : Colors.white;
    return Scaffold(
      backgroundColor: page,
      appBar: AppBar(
        backgroundColor: page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Text(
          "Albums",
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: controller.openCamera,
            child: const _AlbumRoundIcon(icon: Icons.photo_camera_outlined),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            color: light ? Colors.white : const Color(0xFF131C2E),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const _AlbumRoundIcon(icon: Icons.more_vert_rounded),
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
              } else if (value == "setting") {
                Get.to(() => SettingsScreen());
              }
            },

            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: "create",
                child: Text(
                  "Create new album",
                  style: TextStyle(
                    fontSize: 15,
                    color: ink,
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
                    color: ink,
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
                    color: ink,
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
                      color: ink,
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
                    color: ink,
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
                    color: ink,
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
                    color: ink,
                    fontFamily: FontFamily.robotoRegular,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await controller.refreshAlbums();
            },
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: SplashLoader());
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
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Obx(() {
                  if (_floatingDate.value.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff333333),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _floatingDate.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // right side up/down
          Positioned(
            right: 0,
            top: 8,
            child: Obx(
                  () => AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showScrollButton.value ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showScrollButton.value,
                  child: Container(
                    width: 42,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xff333333),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 6,
                          offset: const Offset(-2, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 30,
                          width: 42,
                          child: InkWell(
                            onTap: _scrollUp,
                            child: const Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 30,
                          width: 42,
                          child: InkWell(
                            onTap: _scrollDown,
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      )
    );
  }

  Widget _heroAlbumCard(BuildContext context, AssetPathEntity album) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    final cover = controller.albumCovers[album.id];
    return GestureDetector(
      onLongPressStart: (_) {
        controller.startAlbumDragSelection(album.id);
      },
      onLongPressMoveUpdate: (details) {
        _handleAlbumDragSelection(details.globalPosition);
        _handleAlbumAutoScroll(details.globalPosition);
      },
      onLongPressEnd: (_) {
        controller.endAlbumDragSelection();
        controller.stopAlbumAutoScroll();
      },
      onTap: () {
        if (controller.isAlbumSelectionMode.value) {
          controller.toggleAlbumSelection(album.id);
          return;
        }
        Get.to(() => AlbumPhotosScreen(album: album));
      },
      child: Container(
        key: _getAlbumKey(album.id),
        decoration: BoxDecoration(
          color: light ? Colors.white : const Color(0xFF131C2E),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: light ? const Color(0xFFE6EAEF) : const Color(0xFF1F2B44),
          ),
          boxShadow: light
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover != null
                        ? AlbumCover(asset: cover)
                        : ColoredBox(
                            color: light
                                ? const Color(0xFFE8EDF2)
                                : const Color(0xFF1B2440),
                          ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x8A000000),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFF34D399),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Auto Synced',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: light
                                ? const Color(0xFF111827)
                                : const Color(0xFFF2F5FB),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${controller.albumCounts[album.id] ?? 0} items',
                          style: TextStyle(
                            fontSize: 13,
                            color: light
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF8C97B2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: light
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFF232E57),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: light
                          ? const Color(0xFF4058C8)
                          : const Color(0xFF7C8CFF),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontFamily: FontFamily.robotoBold,
          color: AppColors.fg(const Color(0xff222222)),
        ),
      ),
    );
  }

  Widget _albumGridItem(BuildContext context, AssetPathEntity album) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    final cover = controller.albumCovers[album.id];

    return GestureDetector(
      onLongPressStart: (_) {
        controller.startAlbumDragSelection(album.id);
      },

      onLongPressMoveUpdate: (details) {
        _handleAlbumDragSelection(details.globalPosition);
        _handleAlbumAutoScroll(details.globalPosition);
      },

      onLongPressEnd: (_) {
        controller.endAlbumDragSelection();
        controller.stopAlbumAutoScroll();
      },

      onTap: () {
        if (controller.isAlbumSelectionMode.value) {
          controller.toggleAlbumSelection(album.id);
          return;
        }

        Get.to(() => AlbumPhotosScreen(album: album));
      },

      child: Stack(
        key: _getAlbumKey(album.id),
        children: [
          Container(
            decoration: BoxDecoration(
              color: light ? Colors.white : const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: light ? const Color(0xFFE6EAEF) : const Color(0xFF1F2B44),
              ),
              boxShadow: light
                  ? const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: cover != null
                          ? AlbumCover(asset: cover)
                          : ColoredBox(
                              color: light
                                  ? const Color(0xFFE8EDF2)
                                  : const Color(0xFF1B2440),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: light
                              ? const Color(0xFF111827)
                              : const Color(0xFFF2F5FB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${controller.albumCounts[album.id] ?? 0} items',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: light
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF8C97B2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Obx(() {
            if (!controller.isAlbumSelectionMode.value) {
              return const SizedBox.shrink();
            }
            final isSelected = controller.isAlbumSelected(album.id);
            return Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black
                      : AppColors.surface(Colors.white.withOpacity(0.85)),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border(Colors.white), width: 1.5),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 17)
                    : null,
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
    final bool light = Theme.of(context).brightness == Brightness.light;
    final assetIds = List<String>.from(albumData["assetIds"] ?? []);

    AssetEntity? coverAsset;

    for (final asset in controller.createAlbumMedia) {
      if (assetIds.contains(asset.id)) {
        coverAsset = asset;
        break;
      }
    }
    if (assetIds.isEmpty) {
      return const SizedBox.shrink();
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
          )?.then((_) async {
            await controller.refreshCustomAlbums();
          });
        }
      },

      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: light ? Colors.white : const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: light ? const Color(0xFFE6EAEF) : const Color(0xFF1F2B44),
              ),
              boxShadow: light
                  ? const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: coverAsset != null
                          ? AlbumCover(asset: coverAsset)
                          : ColoredBox(
                              color: light
                                  ? const Color(0xFFE8EDF2)
                                  : const Color(0xFF1B2440),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        albumName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: light
                              ? const Color(0xFF111827)
                              : const Color(0xFFF2F5FB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${assetIds.length} items',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: light
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF8C97B2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Obx(() {
            if (!controller.isAlbumSelected("custom_$albumName")) {
              return const SizedBox.shrink();
            }

            return Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surface(Colors.black38),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border(Colors.white)),
                ),
                child: Icon(Icons.check, color: AppColors.fg(Colors.black), size: 17),
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
    if (albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _albumGridItem(context, albums[index]),
          childCount: albums.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: controller.albumCrossAxisCount.value,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.88,
        ),
      ),
    );
  }

  Widget _buildCustomAlbumGridSection(
    BuildContext context,
    RxMap<String, dynamic> customAlbums,
  ) {
    if (customAlbums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final name = customAlbums.keys.elementAt(index);
          return _customAlbumGridItem(context, name, customAlbums[name]);
        }, childCount: customAlbums.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: controller.albumCrossAxisCount.value,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.88,
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
    final bool light = Theme.of(context).brightness == Brightness.light;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification) {
          isScrolling = true;
          _showScrollControls();
        }

        if (notification is ScrollEndNotification) {
          isScrolling = false;

          _scrollButtonTimer?.cancel();

          _scrollButtonTimer = Timer(
            const Duration(milliseconds: 1000),
                () {
              if (!mounted) return;

              _showScrollButton.value = false;
            },
          );
        }

        return false;
      },

      child: CustomScrollView(
        key: albumScrollAreaKey,
        controller: controller.albumScrollController,
        slivers: [
          if (priorityAlbums.any(
            (album) => album.name.toLowerCase().contains('recent'),
          ))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _heroAlbumCard(
                  context,
                  priorityAlbums.firstWhere(
                    (album) => album.name.toLowerCase().contains('recent'),
                  ),
                ),
              ),
            ),
          _buildAlbumGridSection(
            context,
            priorityAlbums
                .where(
                  (album) => !album.name.toLowerCase().contains('recent'),
                )
                .toList(),
          ),
          if (hasMore) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  'MORE ALBUMS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: light
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF8C97B2),
                  ),
                ),
              ),
            ),
            _buildAlbumGridSection(
              context,
              otherAlbums,
            ),
            _buildCustomAlbumGridSection(
              context,
              customAlbums,
            ),
          ],
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
            ),
          ),
        ],
      ),
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
          Get.to(() => AlbumPhotosScreen(album: album))?.then((_) async {
            await controller.refreshAlbumCover(album);
          });
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
                    : Container(color: AppColors.surface(Colors.grey.shade300)),
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
                  Text(
                    '${controller.albumCounts[album.id] ?? 0} items',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.fg(Colors.grey.shade600),
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
                      decoration: BoxDecoration(
                        color: AppColors.surface(Colors.black38),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppColors.fg(Colors.black),
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
          )?.then((_) async {
            await controller.refreshCustomAlbums();
          });
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
                        color: AppColors.surface(Colors.grey.shade300),
                        child: Icon(
                          Icons.photo_album_outlined,
                          size: 30,
                          color: AppColors.fg(Colors.grey),
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
                    style: TextStyle(fontSize: 12, color: AppColors.fg(Colors.grey.shade600)),
                  ),
                ],
              ),
            ),
            Obx(
              () => controller.isAlbumSelected("custom_$albumName")
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.surface(Colors.black38),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppColors.fg(Colors.black),
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
    if (albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
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
    if (customAlbums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
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

  Future<void> showCreateAlbumDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final Color dialogColor = InnerChrome.dialogBg;

    final Color textColor = InnerChrome.dialogInk;

    final Color fieldColor = InnerChrome.dialogField;

    final Color cancelColor = InnerChrome.dialogSecondaryBg;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: dialogColor,
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
                      color: textColor,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: nameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: "Album name",
                    hintStyle: TextStyle(
                      color: InnerChrome.dialogHint,
                    ),
                    filled: true,
                    fillColor: fieldColor,
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
                            backgroundColor: cancelColor,
                            foregroundColor: textColor,
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
                            backgroundColor: InnerChrome.dialogPrimaryBg,
                            foregroundColor: InnerChrome.dialogPrimaryFg,
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
              color: value ? AppColors.fg(const Color(0xff444444)) : AppColors.fg(const Color(0xffAAAAAA)),
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
    final Color dialogColor = InnerChrome.dialogBg;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: dialogColor,
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
                            backgroundColor: InnerChrome.dialogSecondaryBg,
                            foregroundColor: InnerChrome.dialogSecondaryFg,
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
                            backgroundColor: InnerChrome.dialogPrimaryBg,
                            foregroundColor: InnerChrome.dialogPrimaryFg,
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
    final Color dialogColor = InnerChrome.dialogBg;

    final Color textColor = InnerChrome.dialogInk;

    final Color cancelColor = InnerChrome.dialogSecondaryBg;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: dialogColor,
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
                      color: Theme.of(context).textTheme.bodyLarge?.color,
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
                            backgroundColor: cancelColor,
                            foregroundColor: textColor,
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
                            backgroundColor: InnerChrome.dialogPrimaryBg,
                            foregroundColor: InnerChrome.dialogPrimaryFg,
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
                    ? (Get.isDarkMode ? Colors.white : const Color(0xff444444))
                    : (Get.isDarkMode ? Colors.white54 : const Color(0xffAAAAAA)),
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
                    color: Get.isDarkMode ? Colors.white : const Color(0xff333333),
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
                    ? (Get.isDarkMode ? Colors.white : const Color(0xff444444))
                    : (Get.isDarkMode ? Colors.white54 : const Color(0xffAAAAAA)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showColumnsDialog(BuildContext context) async {
    final RxInt selectedColumns = controller.albumCrossAxisCount.value.obs;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: InnerChrome.dialogBg,
          surfaceTintColor: Colors.transparent,
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
                      color: InnerChrome.dialogInk,
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
                        GetStorageData.albumsGridColumns,
                        selectedColumns.value.toString(),
                      );

                      Navigator.pop(dialogContext);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: InnerChrome.dialogPrimaryBg,
                      foregroundColor: InnerChrome.dialogPrimaryFg,
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
                    ? AppColors.fg(const Color(0xff444444))
                    : AppColors.fg(const Color(0xffAAAAAA)),
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
      backgroundColor: AppColors.bg(const Color(0xffF1F3F5)),
      appBar: AppBar(
        backgroundColor: AppColors.bg(const Color(0xffF1F3F5)),
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
          return const Center(child: SplashLoader());
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
                        return Container(color: AppColors.surface(Colors.grey.shade300));
                      }

                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    },
                  ),
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
            color: AppColors.surface(Colors.white),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: count == 0 || controller.isCreateAlbumLoading.value
                    ? null
                    : () async {
                        log(
                          "IMPORT CLICKED => ${controller.selectedAlbumMediaIds.length}",
                        );

                        await controller.createAlbumAndImport(
                          albumName: albumName,
                        );

                        log("IMPORT METHOD COMPLETED");
                      },

                style: ElevatedButton.styleFrom(
                  backgroundColor: InnerChrome.dialogPrimaryBg,
                  foregroundColor: InnerChrome.dialogPrimaryFg,
                  disabledBackgroundColor: AppColors.surface(Colors.grey.shade400),
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

class MediaShimmer extends StatefulWidget {
  const MediaShimmer({super.key});

  @override
  State<MediaShimmer> createState() => _MediaShimmerState();
}

class _MediaShimmerState extends State<MediaShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = (_controller.value * 2) - 1;

        return ShaderMask(
          shaderCallback: (Rect rect) {
            return LinearGradient(
              begin: Alignment(position - 1, 0),
              end: Alignment(position + 1, 0),
              colors: const [
                Color(0xffE1E4E8),
                Color(0xffF7F8F9),
                Color(0xffE1E4E8),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Container(color: AppColors.surface(const Color(0xffE1E4E8))),
        );
      },
    );
  }
}

class _AlbumRoundIcon extends StatelessWidget {
  final IconData icon;

  const _AlbumRoundIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: light ? Colors.white : const Color(0xFF131C2E),
        shape: BoxShape.circle,
        border: Border.all(
          color: light ? const Color(0xFFE6EAEF) : const Color(0xFF1F2B44),
        ),
        boxShadow: light
            ? const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 20,
        color: light ? const Color(0xFF111827) : const Color(0xFFF2F5FB),
      ),
    );
  }
}

class AlbumCover extends StatelessWidget {
  final AssetEntity? asset;

  const AlbumCover({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset == null) {
      return const MediaShimmer();
    }

    return FutureBuilder<Uint8List?>(
      future: asset!.thumbnailDataWithSize(const ThumbnailSize(500, 500)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data == null) {
          return const MediaShimmer();
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class AlbumPhotosScreen extends StatefulWidget {
  final AssetPathEntity album;

  const AlbumPhotosScreen({super.key, required this.album});

  @override
  State<AlbumPhotosScreen> createState() => _AlbumPhotosScreenState();
}

class _AlbumPhotosScreenState extends State<AlbumPhotosScreen> {
  final GlobalKey gridAreaKey = GlobalKey();
  final Map<String, GlobalKey> assetKeys = {};
  late final AssetPathEntity album;

  late final AlbumPhotosController controller;
  final Map<String, GlobalKey> dateKeys = {};

  final RxBool _showScrollButton = false.obs;
  final RxBool _showFloatingDate = false.obs;
  final RxString _floatingDate = ''.obs;

  Timer? _scrollButtonTimer;
  bool _isScrolling = false;
  final RxDouble _scrollThumbTop = 250.0.obs;
  void _handleAutoScroll(Offset globalPosition) {
    final RenderBox? box =
        gridAreaKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null) {
      return;
    }

    final Offset localPosition = box.globalToLocal(globalPosition);

    controller.updateAutoScroll(
      localY: localPosition.dy,
      viewportHeight: box.size.height,
    );
  }

  void _updateScrollThumbPosition() {
    if (!controller.albumScrollController.hasClients) {
      return;
    }

    final maxScroll =
        controller.albumScrollController.position.maxScrollExtent;

    final currentScroll =
        controller.albumScrollController.offset;

    const double minTop = 70;

    final double maxTop =
        MediaQuery.of(context).size.height - 180;

    if (maxScroll <= 0) {
      _scrollThumbTop.value = minTop;
      return;
    }

    final progress =
    (currentScroll / maxScroll).clamp(0.0, 1.0);

    _scrollThumbTop.value =
        minTop + ((maxTop - minTop) * progress);
  }
  void _handleDragSelection(Offset globalPosition) {
    if (!controller.isDragSelecting.value) {
      return;
    }

    for (final asset in controller.media) {
      final GlobalKey? key = assetKeys[asset.id];

      if (key == null) {
        continue;
      }

      final BuildContext? itemContext = key.currentContext;

      if (itemContext == null) {
        continue;
      }

      final RenderBox? itemBox = itemContext.findRenderObject() as RenderBox?;

      if (itemBox == null || !itemBox.hasSize) {
        continue;
      }

      final Offset itemPosition = itemBox.localToGlobal(Offset.zero);

      final Rect itemRect = itemPosition & itemBox.size;

      if (itemRect.contains(globalPosition)) {
        controller.selectDuringDrag(asset);
        return;
      }
    }
  }

  GlobalKey _getAssetKey(String assetId) {
    return assetKeys.putIfAbsent(assetId, () => GlobalKey());
  }
  GlobalKey _getDateKey(DateTime date) {
    final key = date.toIso8601String();

    return dateKeys.putIfAbsent(
      key,
          () => GlobalKey(),
    );
  }

  void _showScrollControls() {
    if (!mounted) return;

    _showScrollButton.value = true;
    _showFloatingDate.value = true;

    _updateScrollThumbPosition();

    _scrollButtonTimer?.cancel();

    _scrollButtonTimer = Timer(
      const Duration(milliseconds: 1200),
          () {
        if (!mounted) return;

        _showScrollButton.value = false;
        _showFloatingDate.value = false;
      },
    );
  }
  void _updateFloatingDate() {
    if (!mounted) return;

    if (!controller.albumScrollController.hasClients) {
      return;
    }

    final grouped = controller.groupedMedia;

    if (grouped.isEmpty) return;

    final double topLimit =
        MediaQuery.of(context).padding.top +
            kToolbarHeight +
            8;

    DateTime? currentDate;
    double closestTop = -double.infinity;

    for (final date in grouped.keys) {
      final key = dateKeys[date.toIso8601String()];
      if (key == null) continue;

      final keyContext = key.currentContext;
      if (keyContext == null) continue;

      final renderObject = keyContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final position = renderObject.localToGlobal(Offset.zero);
      final double top = position.dy;
      if (top <= topLimit && top > closestTop) {
        closestTop = top;
        currentDate = date;
      }
    }

    currentDate ??= grouped.keys.first;

    _floatingDate.value = formatGalleryDate(currentDate);

    _showFloatingDate.value =
        controller.albumScrollController.offset > 20;
  }

  void _scrollUp() {
    _showScrollControls();

    final scrollController =
        controller.albumScrollController;

    if (!scrollController.hasClients) return;

    final current = scrollController.offset;
    final target = (current - 300).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );

    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _scrollDown() {
    _showScrollControls();

    final scrollController =
        controller.albumScrollController;

    if (!scrollController.hasClients) return;
    final current = scrollController.offset;
    final target = (current + 300).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );

    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();

    album = widget.album;
    controller = Get.put(
      AlbumPhotosController(album: album),
      tag: album.id,
    );
    controller.albumScrollController.addListener(
      _updateFloatingDate,
    );
  }

  @override
  void dispose() {
    _scrollButtonTimer?.cancel();
    controller.albumScrollController.removeListener(
      _updateFloatingDate,
    );
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff121212)
          : const Color(0xffF1F3F5),

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),

        child: Obx(() {
          final bool isDark = Theme.of(context).brightness == Brightness.dark;

          final bool selectionMode = controller.selectedIds.isNotEmpty;

          if (selectionMode) {
            return AppBar(
              backgroundColor: isDark
                  ? const Color(0xff181818)
                  : const Color(0xffF1F3F5),

              elevation: 0,

              leading: IconButton(
                onPressed: () {
                  controller.clearSelection();
                },

                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.white : Colors.black,
                  size: 25,
                ),
              ),

              title: Text(
                '${controller.selectedIds.length} selected',

                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,

                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return AppBar(
            backgroundColor: isDark
                ? const Color(0xff181818)
                : const Color(0xffF1F3F5),

            elevation: 0,

            leading: IconButton(
              onPressed: () {
                Get.back();
              },

              icon: Icon(
                Icons.arrow_back_ios,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            title: Text(
              widget.album.name,

              style: TextStyle(
                fontSize: 20,
                fontFamily: FontFamily.robotoBold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          );
        }),
      ),
      bottomNavigationBar: Obx(() {
        if (controller.selectedIds.isEmpty) {
          return const SizedBox.shrink();
        }

        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          top: false,
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff181818) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _albumPhotoActionButton(
                  context,
                  Icons.share_outlined,
                  "Share",
                  () async {
                    await controller.shareSelected();
                  },
                ),

                _albumPhotoActionButton(
                  context,
                  Icons.delete_outline,
                  "Delete",
                  () async {
                    await controller.deleteSelected();
                  },
                ),

                _albumPhotoActionButton(
                  context,
                  Icons.lock_outline,
                  "Lock",
                  () async {
                    await controller.lockSelected();
                  },
                ),

                _AlbumActionButton(
                  icon: Icons.more_vert,
                  title: 'More',
                  onTap: (buttonContext) {
                    _showMoreMenu(buttonContext, controller);
                  },
                ),
              ],
            ),
          ),
        );
      }),
      body: Stack(
        children: [
          Obx(() {
            if (controller.isLoading.value &&
                controller.media.isEmpty) {
              return const SizedBox();
            }

            if (controller.media.isEmpty) {
              return const _NoMediaFound();
            }

            final grouped = controller.groupedMedia;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTap: () {
                _showScrollControls();
              },

              onScaleStart: (_) {
                _showScrollControls();
                controller.onGridScaleStart();
              },

              onScaleUpdate: (details) {
                _showScrollControls();
                controller.onGridScaleUpdate(details.scale);
              },

              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _isScrolling = true;

                    _showScrollControls();
                    _updateScrollThumbPosition();
                  }

                  if (notification is ScrollUpdateNotification) {
                    _isScrolling = true;

                    _showScrollButton.value = true;
                    _showFloatingDate.value = true;

                    _scrollButtonTimer?.cancel();

                    _updateScrollThumbPosition();

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _updateFloatingDate();
                      }
                    });
                  }

                  if (notification is ScrollEndNotification) {
                    _isScrolling = false;

                    _scrollButtonTimer?.cancel();

                    _scrollButtonTimer = Timer(
                      const Duration(milliseconds: 1000),
                          () {
                        if (!mounted) return;

                        _showScrollButton.value = false;
                        _showFloatingDate.value = false;
                      },
                    );

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _updateFloatingDate();
                      }
                    });
                  }

                  return false;
                },

                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 30,
                  ),

                  key: gridAreaKey,

                  controller:
                  controller.albumScrollController,

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
              ),
            );
          }),

          Obx(() {
            if (!_showFloatingDate.value ||
                _floatingDate.value.isEmpty) {
              return const SizedBox.shrink();
            }

            return Positioned(
              top: 8,
              left: 0,
              right: 0,

              child: IgnorePointer(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),

                    child: Container(
                      key: ValueKey(_floatingDate.value),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff333333),
                        borderRadius:
                        BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color:
                            Colors.black.withOpacity(0.25),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),

                      child: Text(
                        _floatingDate.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          Obx(
            () => AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              curve: Curves.linear,
              right: 0,
              top: _scrollThumbTop.value,

                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showScrollButton.value ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showScrollButton.value,

                    child: Container(
                      width: 38,
                      height: 58,

                      decoration: const BoxDecoration(
                        color: Color(0xff333333),

                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                        ),
                      ),

                      child: Column(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _scrollUp,

                              child: const Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),

                          Expanded(
                            child: InkWell(
                              onTap: _scrollDown,

                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,

            child: Obx(
                  () => AnimatedOpacity(
                duration:
                const Duration(milliseconds: 180),

                opacity:
                _showScrollButton.value ? 1.0 : 0.0,

                child: IgnorePointer(
                  ignoring:
                  !_showScrollButton.value,

                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _showScrollControls();

                        if (!controller
                            .albumScrollController
                            .hasClients) {
                          return;
                        }

                        controller
                            .albumScrollController
                            .animateTo(
                          0,

                          duration:
                          const Duration(milliseconds: 500),

                          curve: Curves.easeOut,
                        );
                      },

                      child: Container(
                        width: 46,
                        height: 46,

                        decoration: BoxDecoration(
                          color: const Color(0xff333333),
                          shape: BoxShape.circle,

                          boxShadow: [
                            BoxShadow(
                              color:
                              Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset:
                              const Offset(0, 2),
                            ),
                          ],
                        ),

                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _albumPhotoActionButton(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 70,
            height: 65,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreMenu(BuildContext context, AlbumPhotosController controller) {
    final RenderBox button = context.findRenderObject() as RenderBox;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy - 330,
      overlay.size.width - buttonPosition.dx - buttonSize.width,
      overlay.size.height - buttonPosition.dy,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff252525)
          : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Text(
            'Copy To',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: 'move',
          child: Text(
            'Move To',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: 'rename',
          child: Text(
            'Rename',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: 'edit',
          child: Text(
            'Edit',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: 'wallpaper',
          child: Text(
            'Set as wallpaper',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: 'resize',
          child: Text(
            'Resize',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: 'favorite',
          child: Text(
            'Add to Favorite',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: 'info',
          child: Text(
            'Info',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ).then((value) async {
      if (value == null) {
        return;
      }

      switch (value) {
        case 'copy':
          await controller.copySelected();
          break;

        case 'move':
          await controller.moveSelected();
          break;

        case 'rename':
          await controller.renameSelected();
          break;

        case 'edit':
          await controller.editSelected();
          break;

        case 'wallpaper':
          await controller.setAsSelected();
          break;

        case 'resize':
          await controller.resizeSelected();
          break;

        case 'favorite':
          await controller.favoriteSelected();
          break;

        case 'info':
          await controller.infoSelected();
          break;
      }
    });
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
        final dateKey = _getDateKey(date);

        return Container(
          key: dateKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              formatGalleryDate(date),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                      padding: const EdgeInsets.all(1),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          key: _getAssetKey(asset.id),
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,

                            onTap: () {
                              if (controller.selectedIds.isNotEmpty) {
                                controller.toggleSelection(asset);
                                return;
                              }

                              Get.to(
                                () => PhotoViewScreen(
                                  asset: asset,
                                  albumMedia: controller.media,
                                ),
                              );
                            },
                            onLongPressStart: (details) {
                              controller.startDragSelection(asset);
                            },
                            onLongPressMoveUpdate: (details) {
                              _handleDragSelection(details.globalPosition);
                              _handleAutoScroll(details.globalPosition);
                            },

                            onLongPressEnd: (_) {
                              controller.endDragSelection();
                            },

                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                AlbumMediaItem(asset: asset),

                                Obx(() {
                                  final bool selectionMode =
                                      controller.selectedIds.isNotEmpty;

                                  if (!selectionMode) {
                                    return const SizedBox.shrink();
                                  }

                                  final bool isSelected = controller.isSelected(
                                    asset,
                                  );

                                  return Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 25,
                                      height: 25,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.black
                                            : AppColors.surface(Colors.white.withOpacity(0.85)),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.border(Colors.white),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
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
                          ),
                        ),
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

class _AlbumActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final void Function(BuildContext context) onTap;

  const _AlbumActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            onTap(buttonContext);
          },
          child: SizedBox(
            width: 70,
            height: 65,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AlbumMediaItem extends StatefulWidget {
  final AssetEntity asset;

  const AlbumMediaItem({super.key, required this.asset});

  @override
  State<AlbumMediaItem> createState() => _AlbumMediaItemState();
}

class _AlbumMediaItemState extends State<AlbumMediaItem> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  void _loadThumbnail() {
    _thumbnailFuture = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
    );
  }

  @override
  void didUpdateWidget(covariant AlbumMediaItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.asset.id != widget.asset.id) {
      _loadThumbnail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _thumbnailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const MediaShimmer();
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return const MediaShimmer();
              }

              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),

          if (widget.asset.type == AssetType.video)
            const Positioned(
              right: 6,
              bottom: 6,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 28,
              ),
            ),
        ],
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
              color: AppColors.fg(Colors.black),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "All your photos and videos will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: FontFamily.robotoRegular,
              color: AppColors.fg(Color(0xff999999)),
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
      backgroundColor: AppColors.bg(const Color(0xffF1F3F5)),

      appBar: AppBar(
        backgroundColor: AppColors.bg(const Color(0xffF1F3F5)),
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
            return const Center(child: SplashLoader());
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
                child: AlbumMediaItem(key: ValueKey(asset.id), asset: asset),
              );
            },
          );
        },
      ),
    );
  }
}
