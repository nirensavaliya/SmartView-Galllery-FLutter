import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/VideoViewScreen.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinView.dart';
import 'package:gallery_photos/View/Setting/SettingScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import 'controller/UtilityMediaController.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class UtilityMediaScreen extends StatefulWidget {
  final UtilityMediaType mediaType;

  const UtilityMediaScreen({super.key, required this.mediaType});

  @override
  State<UtilityMediaScreen> createState() => _UtilityMediaScreenState();
}

class _UtilityMediaScreenState extends State<UtilityMediaScreen> {
  late final UtilityMediaController controller;
  final ScrollController _scrollController = ScrollController();

  Timer? _autoScrollTimer;
  Offset? _lastDragPosition;
  final Set<String> _dragVisitedIds = <String>{};

  static const double _edgeScrollZone = 90;
  static const double _autoScrollStep = 12;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      UtilityMediaController(widget.mediaType),
      tag: widget.mediaType.name,
    );
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    super.dispose();
  }

  void _startDragSelection(Offset globalPosition) {
    if (controller.media.isEmpty) return;

    _dragVisitedIds.clear();
    _lastDragPosition = globalPosition;

    _selectMediaAtPosition(globalPosition);
    _updateAutoScroll(globalPosition);
  }

  void _updateDragSelection(Offset globalPosition) {
    _lastDragPosition = globalPosition;
    _selectMediaAtPosition(globalPosition);
    _updateAutoScroll(globalPosition);
  }

  void _endDragSelection() {
    _lastDragPosition = null;
    _dragVisitedIds.clear();
    _stopAutoScroll();
  }

  void _selectMediaAtPosition(Offset globalPosition) {
    final RenderBox? box =
        _gridOrListKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null || !box.hasSize) return;

    final local = box.globalToLocal(globalPosition);

    final int? index = controller.isListView.value
        ? _indexForListPosition(local)
        : _indexForGridPosition(local);

    if (index == null || index < 0 || index >= controller.media.length) {
      return;
    }

    final asset = controller.media[index];

    if (_dragVisitedIds.add(asset.id) && !controller.isSelected(asset)) {
      controller.selectedIds.add(asset.id);
      controller.selectionMode.value = true;
      controller.selectedIds.refresh();
    }
  }

  int? _indexForGridPosition(Offset local) {
    final int columns = controller.gridColumns.value.clamp(2, 7).toInt();
    final width = _gridOrListKey.currentContext == null
        ? 0.0
        : (_gridOrListKey.currentContext!.findRenderObject() as RenderBox)
              .size
              .width;

    if (width <= 0) return null;

    const horizontalPadding = 4.0;
    const spacing = 3.0;
    const topPadding = 4.0;

    final contentWidth =
        width - (horizontalPadding * 2) - (spacing * (columns - 1));

    final cellWidth = contentWidth / columns;
    final cellHeight = cellWidth;

    final x = local.dx - horizontalPadding;
    final double scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final y = local.dy - topPadding + scrollOffset;

    if (x < 0 || x > contentWidth || y < 0) return null;

    final column = (x / (cellWidth + spacing)).floor();
    final row = (y / (cellHeight + spacing)).floor();

    if (column < 0 || column >= columns || row < 0) return null;

    final cellX = x - column * (cellWidth + spacing);
    final cellY = y - row * (cellHeight + spacing);

    if (cellX > cellWidth || cellY > cellHeight) return null;

    return row * columns + column;
  }

  int? _indexForListPosition(Offset local) {
    const topPadding = 8.0;
    const itemHeight = 84.0;

    final double scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final y = local.dy - topPadding + scrollOffset;

    if (y < 0) return null;

    final index = (y / itemHeight).floor();

    if (index < 0 || index >= controller.media.length) {
      return null;
    }

    return index;
  }

  void _updateAutoScroll(Offset globalPosition) {
    final RenderBox? box =
        _gridOrListKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null || !box.hasSize || !_scrollController.hasClients) {
      return;
    }

    _lastDragPosition = globalPosition;

    final Offset local = box.globalToLocal(globalPosition);

    final double height = box.size.height;

    final bool nearTop = local.dy <= _edgeScrollZone;
    final bool nearBottom = local.dy >= height - _edgeScrollZone;

    if (!nearTop && !nearBottom) {
      _stopAutoScroll();
      return;
    }

    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) {
      return;
    }

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final Offset? fingerPosition = _lastDragPosition;

      if (fingerPosition == null || !_scrollController.hasClients) {
        _stopAutoScroll();
        return;
      }

      final RenderBox? currentBox =
          _gridOrListKey.currentContext?.findRenderObject() as RenderBox?;

      if (currentBox == null || !currentBox.hasSize) {
        return;
      }

      final Offset currentLocal = currentBox.globalToLocal(fingerPosition);

      double delta = 0;

      if (currentLocal.dy <= _edgeScrollZone) {
        delta = -_autoScrollStep;
      }
      else if (currentLocal.dy >= currentBox.size.height - _edgeScrollZone) {
        delta = _autoScrollStep;
      }
      else {
        _stopAutoScroll();
        return;
      }

      final double oldOffset = _scrollController.offset;

      final double newOffset = (oldOffset + delta)
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();

      if (newOffset == oldOffset) {
        return;
      }

      _scrollController.jumpTo(newOffset);

      _selectMediaAtPosition(fingerPosition);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  final GlobalKey _gridOrListKey = GlobalKey();

  Widget _buildSelectableContent() {
    return Listener(
      behavior: HitTestBehavior.translucent,

      onPointerMove: (event) {
        if (_lastDragPosition != null) {
          _updateDragSelection(event.position);
        }
      },

      onPointerUp: (_) {
        if (_lastDragPosition != null) {
          _endDragSelection();
        }
      },

      onPointerCancel: (_) {
        _endDragSelection();
      },

      child: GestureDetector(
        behavior: HitTestBehavior.translucent,

        onLongPressStart: (details) {
          _startDragSelection(details.globalPosition);
        },

        onLongPressMoveUpdate: (details) {
          _updateDragSelection(details.globalPosition);
        },

        onLongPressEnd: (_) {
          _endDragSelection();
        },

        onLongPressCancel: _endDragSelection,

        child: controller.isListView.value
            ? KeyedSubtree(
                key: _gridOrListKey,
                child: _buildMediaListView(
                  controller,
                  scrollController: _scrollController,
                ),
              )
            : KeyedSubtree(
                key: _gridOrListKey,
                child: _buildMediaGridView(
                  controller,
                  scrollController: _scrollController,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;

    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() {
          final bool isSelectionMode = controller.selectedIds.isNotEmpty;

          if (isSelectionMode) {
            return AppBar(
              backgroundColor: InnerChrome.page,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: InnerChrome.alt,
                    shape: BoxShape.circle,
                    border: Border.all(color: InnerChrome.line),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                ),
              ),
              title: Text(
                '${controller.selectedIds.length} Selected',
                style: TextStyle(
                  color: InnerChrome.ink,
                  fontSize: 22,
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: controller.selectAll,
                  icon: Icon(
                    Icons.select_all_rounded,
                    color: InnerChrome.pick,
                  ),
                ),
              ],
            );
          }

          return AppBar(
            backgroundColor: InnerChrome.page,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: InnerChrome.alt,
                  shape: BoxShape.circle,
                  border: Border.all(color: InnerChrome.line),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: 20, color: InnerChrome.ink),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ),
            ),
            title: Text(
              controller.title,
              style: TextStyle(
                color: InnerChrome.ink,
                fontSize: 19,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                color: InnerChrome.sheet,
                icon: Icon(Icons.more_vert, color: InnerChrome.ink),
                onSelected: (value) {
                  switch (value) {
                    case 'sort':
                      controller.showSortDialog();
                      break;

                    case 'group':
                      controller.showGroupDialog();
                      break;

                    case 'view':
                      controller.toggleViewMode();
                      break;
                    case 'columns':
                      controller.showColumnsDialog();
                      break;
                    case 'recycle':
                      Get.to(() => RecycleBinScreen());
                      break;

                    case 'settings':
                      Get.to(() => SettingsScreen());
                      break;
                  }
                },
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'sort',
                      child: Row(
                        children: [
                          Icon(Icons.sort, size: 21, color: InnerChrome.ink),
                          const SizedBox(width: 12),
                          Text(
                            'Sort By',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans',color: InnerChrome.ink),
                          ),
                        ],
                      ),
                    ),

                    PopupMenuItem<String>(
                      value: 'group',
                      child: Row(
                        children: [
                          Icon(Icons.folder_copy_outlined, size: 21, color: InnerChrome.ink),
                          const SizedBox(width: 12),
                          Text(
                            'Group By',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans',color: InnerChrome.ink),
                          ),
                        ],
                      ),
                    ),

                    PopupMenuItem<String>(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(
                            controller.isListView.value
                                ? Icons.grid_view
                                : Icons.view_list,
                            size: 21,
                            color: InnerChrome.ink,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            controller.isListView.value
                                ? 'View as Grid'
                                : 'View as List',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans',color: InnerChrome.ink),
                          ),
                        ],
                      ),
                    ),

                    PopupMenuItem<String>(
                      value: 'columns',
                      child: Row(
                        children: [
                          Icon(Icons.grid_4x4, size: 21, color: InnerChrome.ink),
                          const SizedBox(width: 12),
                          Text(
                            'Columns',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans',color: InnerChrome.ink),
                          ),
                        ],
                      ),
                    ),

                    const PopupMenuDivider(),

                    PopupMenuItem<String>(
                      value: 'recycle',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 21, color: InnerChrome.ink),
                          const SizedBox(width: 12),
                          Text(
                            'Recycle Bin',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans',color: InnerChrome.ink),
                          ),
                        ],
                      ),
                    ),

                    PopupMenuItem<String>(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 21, color: InnerChrome.ink),
                          const SizedBox(width: 12),
                          Text(
                            'Settings',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans',color: InnerChrome.ink),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          );
        }),
      ),
      floatingActionButton: controller.mediaType == UtilityMediaType.favorites
          ? FloatingActionButton(
              onPressed: controller.openFavoriteImportScreen,
              backgroundColor: InnerChrome.accent,
              elevation: 6,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
      body: Obx(() {
        if (controller.isLoading.value && controller.media.isEmpty) {
          return const Center(child: SplashLoader());
        }
        if (controller.media.isEmpty) {
          return _EmptyView(
            title: controller.title,
            onRefresh: controller.refreshMedia,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.refreshMedia,
          child: Obx(() {
            return _buildSelectableContent();
          }),
        );
      }),
      bottomNavigationBar: Obx(() {
        if (controller.selectedIds.isEmpty) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: InnerChrome.sheet,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: InnerChrome.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _utilitySelectionActionButton(
                    context,
                    Icons.share_outlined,
                    "Share",
                    () async {
                      await controller.shareSelected();
                    },
                  ),
                  _utilitySelectionActionButton(
                    context,
                    Icons.favorite_border_rounded,
                    "Favorite",
                    () async {
                      await controller.toggleFavoriteSelected();
                    },
                  ),
                  _utilitySelectionActionButton(
                    context,
                    Icons.delete_outline_rounded,
                    "Delete",
                    () async {
                      await controller.deleteSelected();
                    },
                    iconColor: InnerChrome.danger,
                  ),
                  _utilitySelectionActionButton(
                    context,
                    Icons.more_vert,
                    "More",
                    () {
                      final assets = controller.selectedAssets;

                      if (assets.length != 1) {
                        AppToast.show(
                          "Please select only one item for More actions",
                        );
                        return;
                      }

                      _showMoreMenu(context, controller);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _showMoreMenu(
    BuildContext context,
    UtilityMediaController controller,
  ) async {
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

    final String? value = await showMenu<String>(
      context: context,
      position: position,
      color: InnerChrome.sheet,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Text(
            'Copy To',
            style: TextStyle(
              color: InnerChrome.ink,
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
              color: InnerChrome.ink,
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
              color: InnerChrome.ink,
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
              color: InnerChrome.ink,
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
              color: InnerChrome.ink,
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
              color: InnerChrome.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (controller.mediaType == UtilityMediaType.favorites)
          PopupMenuItem<String>(
            value: 'remove_favorite',
            child: Text(
              'Remove from favorite',
              style: TextStyle(
                color: InnerChrome.ink,
                fontSize: 15,
                fontFamily: FontFamily.robotoBold,
              ),
            ),
          ),
        PopupMenuItem<String>(
          value: 'info',
          child: Text(
            'Info',
            style: TextStyle(
              color: InnerChrome.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    if (value == null) {
      return;
    }

    await controller.handleMoreAction(value);
  }
}

Widget _utilitySelectionActionButton(
  BuildContext context,
  IconData icon,
  String title,
  VoidCallback onTap, {
  Color? iconColor,
}) {
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
            color: iconColor ?? InnerChrome.ink,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,fontFamily: 'Plus Jakarta Sans',
              color: InnerChrome.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildMediaGridView(
  UtilityMediaController controller, {
  ScrollController? scrollController,
}) {
  final int columns = controller.gridColumns.value;

  return GridView.builder(
    controller: scrollController,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
    physics: const AlwaysScrollableScrollPhysics(),

    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),

    itemCount: controller.media.length,

    itemBuilder: (context, index) {
      final AssetEntity asset = controller.media[index];

      controller.loadMoreIfNeeded(index);

      return _MediaGridItem(asset: asset, controller: controller);
    },
  );
}

Widget _buildMediaListView(
  UtilityMediaController controller, {
  ScrollController? scrollController,
}) {
  return ListView.builder(
    controller: scrollController,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
    physics: const AlwaysScrollableScrollPhysics(),

    itemCount: controller.media.length,

    itemBuilder: (context, index) {
      final AssetEntity asset = controller.media[index];

      controller.loadMoreIfNeeded(index);

      return _MediaListItem(asset: asset, controller: controller);
    },
  );
}

class _MediaListItem extends StatelessWidget {
  final AssetEntity asset;
  final UtilityMediaController controller;

  const _MediaListItem({required this.asset, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool selected = controller.isSelected(asset);

      return GestureDetector(
        onTap: () {
          if (controller.selectionMode.value) {
            controller.toggleSelection(asset);
          } else {
            _openPreview(context, asset);
          }
        },

        child: Container(
          height: 76,
          margin: const EdgeInsets.symmetric(vertical: 4),

          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 68,
                  height: 68,

                  child: FutureBuilder<Uint8List?>(
                    future: asset.thumbnailDataWithSize(
                      const ThumbnailSize(300, 300),
                    ),

                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ColoredBox(color: InnerChrome.alt);
                      }

                      if (snapshot.hasError || snapshot.data == null) {
                        return ColoredBox(
                          color: InnerChrome.alt,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: InnerChrome.muted,
                          ),
                        );
                      }

                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      asset.title ?? 'Untitled',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: InnerChrome.ink,fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      asset.type == AssetType.video
                          ? _formatDuration(asset.videoDuration)
                          : _formatDate(asset.createDateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: InnerChrome.muted,fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ],
                ),
              ),

              if (asset.isFavorite)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              if (controller.selectionMode.value)
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? InnerChrome.pick
                        : Colors.black26,
                    shape: BoxShape.circle,
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
                          size: 16,
                        )
                      : null,
                ),
            ],
          ),
        ),
      );
    });
  }

  void _openPreview(BuildContext context, AssetEntity asset) {
    if (asset.type == AssetType.video) {
      Get.to(() => VideoViewScreen(asset: asset));
    } else {
      Get.to(() => PhotoViewScreen(asset: asset));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MediaGridItem extends StatefulWidget {
  final AssetEntity asset;
  final UtilityMediaController controller;

  const _MediaGridItem({required this.asset, required this.controller});

  @override
  State<_MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<_MediaGridItem> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();

    _thumbnailFuture = widget.controller.getThumbnail(widget.asset, size: 500);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final asset = widget.asset;
    return Obx(() {
      final bool selected = controller.isSelected(asset);

      return GestureDetector(
        onTap: () {
          if (controller.selectionMode.value) {
            controller.toggleSelection(asset);
          } else {
            _openPreview(context, asset);
          }
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
                  future: _thumbnailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ColoredBox(color: InnerChrome.alt);
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return ColoredBox(
                        color: InnerChrome.alt,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: InnerChrome.muted,
                          ),
                        ),
                      );
                    }

                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    );
                  },
                ),

                if (asset.type == AssetType.video)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _formatDuration(asset.videoDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ),
                  ),

                if (asset.isFavorite)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),

                if (selected) Container(color: Colors.black26),

                if (controller.selectionMode.value)
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
  }

  void _openPreview(BuildContext context, AssetEntity asset) {
    if (asset.type == AssetType.video) {
      Get.to(() => VideoViewScreen(asset: asset));
    } else {
      Get.to(() => PhotoViewScreen(asset: asset));
    }
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _EmptyView extends StatelessWidget {
  final String title;
  final Future<void> Function() onRefresh;

  const _EmptyView({required this.title, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),

          Center(
            child: Image.asset(
              'assets/images/Empty.webp',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'No Photos and Videos Available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: InnerChrome.ink,
                fontSize: 18,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                'All your photos and videos will\n appear here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: InnerChrome.muted,
                  fontSize: 13,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPreviewScreen extends StatefulWidget {
  final AssetEntity asset;

  const _MediaPreviewScreen({required this.asset});

  @override
  State<_MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<_MediaPreviewScreen> {
  final Rxn<VideoPlayerController> _videoController =
      Rxn<VideoPlayerController>();
  final RxBool _isPlaying = false.obs;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();

    _isVideo = widget.asset.type == AssetType.video;

    if (_isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final File? file = await widget.asset.file;

    if (file == null) {
      return;
    }

    final controller = VideoPlayerController.file(file);

    await controller.initialize();

    if (!mounted) {
      controller.dispose();
      return;
    }

    _videoController.value = controller;

    _isPlaying.value = controller.value.isPlaying;

    await controller.play();
  }

  @override
  void dispose() {
    _videoController.value?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),

      body: Center(child: _isVideo ? _buildVideo() : _buildImage()),
    );
  }

  Widget _buildVideo() {
    return Obx(() {
      final controller = _videoController.value;
      final bool isPlaying = _isPlaying.value;

      if (controller == null || !controller.value.isInitialized) {
        return const CircularProgressIndicator(color: Colors.white);
      }

      return GestureDetector(
        onTap: () {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }

          _isPlaying.value = controller.value.isPlaying;
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),

            if (!isPlaying)
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 70,
              ),
          ],
        ),
      );
    });
  }

  Widget _buildImage() {
    return FutureBuilder<File?>(
      future: widget.asset.file,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(color: Colors.white);
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 60,
          );
        }

        return InteractiveViewer(
          child: Image.file(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 60,
              );
            },
          ),
        );
      },
    );
  }
}
