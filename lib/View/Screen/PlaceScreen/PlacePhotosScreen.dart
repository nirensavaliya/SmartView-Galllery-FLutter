import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:url_launcher/url_launcher.dart';
import 'package:gallery_photos/View/Screen/PlaceScreen/controller/PlacesController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class PlacePhotosScreen extends StatefulWidget {
  final PlaceGroup place;

  const PlacePhotosScreen({super.key, required this.place});

  @override
  State<PlacePhotosScreen> createState() => _PlacePhotosScreenState();
}

class _PlacePhotosScreenState extends State<PlacePhotosScreen> {
  late final PlacesController controller;
  final ScrollController _scrollController = ScrollController();
  final RxBool _showScrollControls = false.obs;
  final RxString _floatingDate = ''.obs;
  final RxDouble _scrollThumbTop = 100.0.obs;
  final Map<String, GlobalKey> _dateKeys = {};
  final Map<String, GlobalKey> _photoKeys = {};
  Timer? _scrollHideTimer;
  Timer? _dragAutoScrollTimer;
  Offset? _dragPosition;
  Offset? _lastPointerPosition;
  bool _longPressSelectionActive = false;
  bool _dragSelecting = false;
  @override
  void initState() {
    super.initState();
    controller = Get.find<PlacesController>();
    controller.clearSelection();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.offset;
    if (maxScroll <= 0) {
      return;
    }

    final double progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    final double screenHeight = MediaQuery.of(context).size.height;
    const double minTop = 70;
    final double maxTop = screenHeight - 190;

    _scrollThumbTop.value = minTop + ((maxTop - minTop) * progress);

    _showScrollControls.value = currentScroll > 20;

    _updateFloatingDate();

    _scrollHideTimer?.cancel();

    _scrollHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      _showScrollControls.value = false;
    });
  }

  void _updateFloatingDate() {
    if (!_scrollController.hasClients) {
      return;
    }

    DateTime? currentDate;

    double closestTop = -double.infinity;

    final double topLimit =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    for (final entry in _dateKeys.entries) {
      final BuildContext? keyContext = entry.value.currentContext;

      if (keyContext == null) {
        continue;
      }

      final RenderObject? renderObject = keyContext.findRenderObject();

      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final Offset position = renderObject.localToGlobal(Offset.zero);

      final double top = position.dy;

      if (top <= topLimit && top > closestTop) {
        closestTop = top;

        final parts = entry.key.split('-');

        if (parts.length == 2) {
          currentDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        }
      }
    }

    if (currentDate != null) {
      _floatingDate.value =
          '${_monthName(currentDate.month)} ${currentDate.year}';
    }
  }

  void _scrollUp() {
    if (!_scrollController.hasClients) {
      return;
    }

    final double target = (_scrollController.offset - 350).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _scrollDown() {
    if (!_scrollController.hasClients) {
      return;
    }

    final double target = (_scrollController.offset + 350).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _scrollHideTimer?.cancel();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    controller.clearSelection();

    super.dispose();
  }
  void _selectPhotoAtPosition(Offset position) {
    if (!_longPressSelectionActive) {
      return;
    }

    for (final entry in _photoKeys.entries) {
      final BuildContext? keyContext = entry.value.currentContext;

      if (keyContext == null) {
        continue;
      }

      final RenderObject? renderObject =
      keyContext.findRenderObject();

      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final Offset topLeft =
      renderObject.localToGlobal(Offset.zero);

      final Rect rect = topLeft & renderObject.size;

      if (rect.contains(position)) {
        final String assetId = entry.key;

        AssetEntity? matchedAsset;

        for (final asset in widget.place.assets) {
          if (asset.id == assetId) {
            matchedAsset = asset;
            break;
          }
        }

        if (matchedAsset != null) {
          controller.selectDuringDrag(matchedAsset);
        }

        break;
      }
    }
  }
  void _startDragSelectionAfterLongPress(AssetEntity asset) {
    final position = _lastPointerPosition;

    if (position == null) {
      return;
    }

    _dragPosition = position;
    _longPressSelectionActive = true;
    _dragSelecting = true;
    controller.startSelection(asset);
    controller.startDragSelection(asset, position);

    _startDragAutoScroll();
  }

  void _updateDragSelection(Offset position) {
    _lastPointerPosition = position;

    if (!_longPressSelectionActive) {
      return;
    }

    _dragPosition = position;

    _selectPhotoAtPosition(position);

    controller.updateDragSelection(position);

    if (controller.isDragSelecting.value) {
      _dragSelecting = true;
      _startDragAutoScroll();
    }
  }

  void _endDragSelection() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;

    _dragPosition = null;
    _lastPointerPosition = null;

    _dragSelecting = false;
    _longPressSelectionActive = false;

    controller.endDragSelection();
  }

  void _startDragAutoScroll() {
    if (_dragAutoScrollTimer != null) {
      return;
    }

    _dragAutoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16),
          (_) {
        if (!_longPressSelectionActive ||
            !_dragSelecting ||
            _dragPosition == null ||
            !controller.isDragSelecting.value) {
          return;
        }

        if (!_scrollController.hasClients) {
          return;
        }

        final screenHeight = MediaQuery.of(context).size.height;
        final y = _dragPosition!.dy;

        const double edgeSize = 100;
        const double maxSpeed = 18;

        double scrollAmount = 0;

        if (y < edgeSize) {
          final intensity =
          ((edgeSize - y) / edgeSize).clamp(0.0, 1.0);

          scrollAmount = -maxSpeed * intensity;
        }

        else if (y > screenHeight - edgeSize) {
          final intensity =
          ((y - (screenHeight - edgeSize)) / edgeSize)
              .clamp(0.0, 1.0);

          scrollAmount = maxSpeed * intensity;
        }

        if (scrollAmount == 0) {
          return;
        }

        final current = _scrollController.offset;

        final target = (current + scrollAmount).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );

        if (target == current) {
          return;
        }

        _scrollController.jumpTo(target);

            _selectPhotoAtPosition(_dragPosition!);

            controller.updateDragSelection(_dragPosition!);
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final PlacesController controller = Get.find<PlacesController>();

    final List<AssetEntity> assets = List<AssetEntity>.from(
      widget.place.assets,
    );

    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),

        child: Obx(() {
          if (controller.isSelectionMode) {
            return AppBar(
              backgroundColor: InnerChrome.page,
              surfaceTintColor: Colors.transparent,
              elevation: 0,

              leading: IconButton(
                onPressed: controller.clearSelection,
                icon: Icon(
                  Icons.close,
                  color: InnerChrome.ink,
                  size: 25,
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
            );
          }

          return AppBar(
            backgroundColor: InnerChrome.page,
            surfaceTintColor: Colors.transparent,
            elevation: 0,

            leading: IconButton(
              onPressed: () {
                Get.back();
              },
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 19,
                color: InnerChrome.ink,
              ),
            ),

            title: Text(
              widget.place.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: InnerChrome.ink,
                fontSize: 19,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }),
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.isSelectionMode) {
          return const SizedBox.shrink();
        }
        return _SelectionBottomBar(controller: controller, assets: assets);
      }),
      body: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,

            onPointerDown: (event) {
              _lastPointerPosition = event.position;
            },

            onPointerMove: (event) {
              _updateDragSelection(event.position);
            },

            onPointerUp: (event) {
              _lastPointerPosition = event.position;
              _endDragSelection();
            },

            onPointerCancel: (event) {
              _endDragSelection();
            },

            child: GestureDetector(
              behavior: HitTestBehavior.translucent,

              onScaleStart: (_) {
                controller.onGridScaleStart();
              },

              onScaleUpdate: (details) {
                controller.onGridScaleUpdate(details.scale);
              },

              child: Obx(
                    () => ListView(
                  controller: _scrollController,

                  physics: controller.isDragSelecting.value
                      ? const NeverScrollableScrollPhysics()
                      : null,

                  padding: const EdgeInsets.fromLTRB(
                    10,
                    4,
                    10,
                    80,
                  ),

                  children: [
                    _MapCard(place: widget.place),

                    const SizedBox(height: 14),

                    _buildMonthSections(
                      controller,
                      assets,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Obx(() {
            if (!_showScrollControls.value || _floatingDate.value.isEmpty) {
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
                            offset: Offset(0, 2),
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

                opacity: _showScrollControls.value ? 1.0 : 0.0,

                child: IgnorePointer(
                  ignoring: !_showScrollControls.value,

                  child: Container(
                    width: 40,
                    height: 62,

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
                              size: 22,
                            ),
                          ),
                        ),

                        Expanded(
                          child: InkWell(
                            onTap: _scrollDown,

                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 22,
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
          Obx(
            () => Positioned(
              left: 0,
              right: 0,
              bottom: 16,

              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),

                opacity: _showScrollControls.value ? 1.0 : 0.0,

                child: IgnorePointer(
                  ignoring: !_showScrollControls.value,

                  child: Center(
                    child: Material(
                      color: const Color(0xff333333),
                      shape: const CircleBorder(),
                      elevation: 5,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _scrollToTop,
                        child: const SizedBox(
                          width: 46,
                          height: 46,

                          child: Icon(
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
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSections(
    PlacesController controller,
    List<AssetEntity> assets,
  ) {
    final Map<String, List<AssetEntity>> grouped = {};

    for (final AssetEntity asset in assets) {
      final DateTime date = asset.createDateTime;

      final String key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(key, () => <AssetEntity>[]).add(asset);
    }

    final List<String> keys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: keys.map((key) {
          final List<AssetEntity> monthAssets = grouped[key]!;

          monthAssets.sort(
            (a, b) => b.createDateTime.compareTo(a.createDateTime),
          );

          final DateTime date = monthAssets.first.createDateTime;

          final String dateKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';

          final GlobalKey headerKey = _dateKeys.putIfAbsent(
            dateKey,
            () => GlobalKey(),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  key: headerKey,

                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),

                    child: Text(
                      '${_monthName(date.month)} ${date.year}',

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: InnerChrome.ink,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                GridView.builder(
                  shrinkWrap: true,

                  physics: const NeverScrollableScrollPhysics(),

                  padding: EdgeInsets.zero,

                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: controller.gridColumns.value,

                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,

                    childAspectRatio: 1,
                  ),

                  itemCount: monthAssets.length,

                  itemBuilder: (context, index) {
                    final AssetEntity asset = monthAssets[index];

                    return _PlacePhoto(
                      key: _photoKeys.putIfAbsent(
                        asset.id,
                            () => GlobalKey(),
                      ),
                      asset: asset,
                      controller: controller,
                      assets: assets,
                      onLongPress: () {
                        _startDragSelectionAfterLongPress(asset);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _monthName(int month) {
    const List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }
}

class _PlacePhoto extends StatelessWidget {
  final AssetEntity asset;
  final PlacesController controller;
  final List<AssetEntity> assets;
  final VoidCallback onLongPress;

  const _PlacePhoto({
    super.key,
    required this.asset,
    required this.controller,
    required this.assets,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,

      onTap: () {
        if (controller.isSelectionMode) {
          controller.toggleSelection(asset);
          return;
        }

        Get.to(() => PhotoViewScreen(asset: asset, albumMedia: assets));
      },

      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(const ThumbnailSize(800, 800)),

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  color: AppColors.surface(InnerChrome.alt),
                );
              }

              if (snapshot.hasError || snapshot.data == null) {
                return Container(
                  color: InnerChrome.alt,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: InnerChrome.muted,
                  ),
                );
              }

              return Image.memory(
                snapshot.data!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),

          Obx(() {
            if (!controller.isSelectionMode) {
              return const SizedBox.shrink();
            }

            final bool selected = controller.isSelected(asset);

            return Positioned(
              top: 6,
              left: 6,

              child: GestureDetector(
                onTap: () {
                  controller.toggleSelection(asset);
                },

                child: Container(
                  width: 25,
                  height: 25,

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
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SelectionBottomBar extends StatelessWidget {
  final PlacesController controller;
  final List<AssetEntity> assets;

  const _SelectionBottomBar({required this.controller, required this.assets});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: InnerChrome.sheet,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: InnerChrome.line),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,

          children: [
            _ActionButton(
              icon: Icons.share_outlined,
              title: 'Share',
              onTap: (_) {
                controller.shareSelected();
              },
            ),

            _ActionButton(
              icon: Icons.delete_outline,
              title: 'Delete',
              onTap: (_) {
                controller.deleteSelected(assets);
              },
            ),

            _ActionButton(
              icon: Icons.lock_outline,
              title: 'Lock',
              onTap: (_) {
                controller.lockSelected();
              },
            ),

            _ActionButton(
              icon: Icons.more_vert,
              title: 'More',
              onTap: (buttonContext) {
                _showMoreMenu(buttonContext, controller, assets);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final void Function(BuildContext context) onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,

          onTap: () {
            onTap(buttonContext);
          },

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 25,
                color: title == 'Delete'
                    ? InnerChrome.danger
                    : InnerChrome.ink,
              ),

              const SizedBox(height: 4),

              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: InnerChrome.ink,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _showMoreMenu(
  BuildContext context,
  PlacesController controller,
  List<AssetEntity> assets,
) {
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

      PopupMenuItem<String>(
        value: 'favorite',
        child: Text(
          'Add to Favorite',
          style: TextStyle(
            color: InnerChrome.ink,
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
            color: InnerChrome.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ).then((value) {
    if (value == null) {
      return;
    }

    switch (value) {
      case 'copy':
        controller.copySelected();
        break;

      case 'move':
        controller.moveSelected();
        break;

      case 'rename':
        controller.renameSelected();
        break;

      case 'edit':
        controller.editSelected();
        break;

      case 'wallpaper':
        controller.setAsSelected();
        break;

      case 'resize':
        controller.resizeSelected();
        break;

      case 'favorite':
        controller.favoriteSelected(assets);
        break;

      case 'info':
        controller.infoSelected();
        break;
    }
  });
}

class _MapCard extends StatelessWidget {
  final PlaceGroup place;

  const _MapCard({required this.place});

  Future<void> _openMap() async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${place.latitude},${place.longitude}',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('MAP ERROR => $e');
    }
  }

  Future<void> _openDirections() async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${place.latitude},${place.longitude}'
      '&travelmode=driving',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('DIRECTION ERROR => $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _openMap,

          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),

            child: SizedBox(
              height: 180,

              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: InnerChrome.alt,

                    child: CustomPaint(
                      painter: _MapPreviewPainter(
                        latitude: place.latitude,
                        longitude: place.longitude,
                      ),

                      child: Center(
                        child: Container(
                          width: 42,
                          height: 42,

                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,

                            border: Border.all(
                              color: AppColors.border(Colors.white),
                              width: 4,
                            ),

                            boxShadow: const [
                              BoxShadow(blurRadius: 6, color: Colors.black26),
                            ],
                          ),

                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,

                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),

                      color: AppColors.surface(Colors.black.withOpacity(0.55)),

                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.title,

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            '${place.assets.length}',

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _MapActionButton(
                icon: Icons.directions,
                title: 'Directions',
                onTap: _openDirections,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _MapActionButton(
                icon: Icons.map_outlined,
                title: 'Map',
                onTap: _openMap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  final double latitude;
  final double longitude;

  _MapPreviewPainter({required this.latitude, required this.longitude});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint roadPaint = Paint()
      ..color = InnerChrome.faint
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final Paint roadPaint2 = Paint()
      ..color = InnerChrome.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (double y = 15; y < size.height; y += 25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), roadPaint);
    }
    for (double x = 10; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x + 20, size.height), roadPaint);
    }
    for (double x = -100; x < size.width; x += 80) {
      final Path path = Path();

      path.moveTo(x, size.height);

      path.lineTo(x + 120, 0);

      canvas.drawPath(path, roadPaint2);
    }
    final Paint blockPaint = Paint()
      ..color = InnerChrome.mapBlock
      ..style = PaintingStyle.fill;

    for (double x = 5; x < size.width; x += 55) {
      for (double y = 5; y < size.height - 30; y += 42) {
        canvas.drawRect(Rect.fromLTWH(x, y, 30, 18), blockPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) {
    return oldDelegate.latitude != latitude ||
        oldDelegate.longitude != longitude;
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MapActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: InnerChrome.disabled,
      borderRadius: BorderRadius.circular(16),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(16),

        child: Container(
          height: 44,

          padding: const EdgeInsets.symmetric(horizontal: 14),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(
                icon,
                size: 21,
                color: InnerChrome.accent,
              ),

              const SizedBox(width: 7),

              Text(
                title,

                style: TextStyle(
                  color: InnerChrome.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
