import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinView.dart';
import 'package:gallery_photos/View/Setting/SettingScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'Controller/PhotosController.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final PhotosController controller = Get.find<PhotosController>();
  final ScrollController _scrollController = ScrollController();

  Timer? _scrollButtonTimer;
  final RxBool _showScrollButton = false.obs;
  final RxBool _showFloatingDate = false.obs;
  final RxString _floatingDate = ''.obs;
  final Map<String, GlobalKey> _dateHeaderKeys = {};
  final RxDouble _scrollThumbTop = 250.0.obs;
  bool _isScrolling = false;
  Timer? _scrollingTimer;
  Offset? _dragPosition;
  Offset? _lastPointerPosition;
  bool _longPressSelectionActive = false;
  Timer? _dragAutoScrollTimer;
  bool _dragSelecting = false;

  String? _dragStartAssetId;
  bool _pinchZooming = false;
  final Map<int, Offset> _pinchPoints = <int, Offset>{};
  double? _pinchStartSpan;

  void _trackPinchDown(int pointer, Offset position) {
    _pinchPoints[pointer] = position;
    if (_pinchPoints.length == 2 && !_pinchZooming) {
      _pinchStartSpan = _pinchSpan();
      controller.onGridScaleStart();
      setState(() {
        _pinchZooming = true;
      });
    }
  }

  void _trackPinchMove(int pointer, Offset position) {
    if (!_pinchPoints.containsKey(pointer)) {
      return;
    }
    _pinchPoints[pointer] = position;
    final double? span = _pinchSpan();
    if (!_pinchZooming ||
        span == null ||
        _pinchStartSpan == null ||
        _pinchStartSpan! <= 1) {
      return;
    }
    controller.onGridScaleUpdate(span / _pinchStartSpan!);
  }

  void _trackPinchEnd(int pointer) {
    _pinchPoints.remove(pointer);
    if (_pinchPoints.length < 2 && _pinchZooming) {
      _pinchStartSpan = null;
      setState(() {
        _pinchZooming = false;
      });
    }
  }

  double? _pinchSpan() {
    if (_pinchPoints.length < 2) {
      return null;
    }
    final List<Offset> points = _pinchPoints.values.toList();
    return (points[0] - points[1]).distance;
  }
  @override
  void dispose() {
    _scrollButtonTimer?.cancel();
    _dragAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFloatingDate() {
    if (!_scrollController.hasClients) return;

    final double topLimit =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    String? currentDate;

    for (final row in controller.galleryRows) {
      if (!row.isHeader) continue;
      final key = _dateHeaderKeys[row.title];
      if (key == null) continue;

      final keyContext = key.currentContext;
      if (keyContext == null) continue;
      final renderObject = keyContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }
      final position = renderObject.localToGlobal(Offset.zero);
      if (position.dy <= topLimit) {
        currentDate = row.title;
      }
    }

    if (currentDate != null &&
        currentDate.isNotEmpty &&
        _floatingDate.value != currentDate) {
      _floatingDate.value = currentDate;
    }
  }

  void _startDragSelectionAfterLongPress(AssetEntity asset) {
    final position = _lastPointerPosition;
    if (position == null) {
      return;
    }

    _dragPosition = position;
    _dragStartAssetId = asset.id;
    _longPressSelectionActive = true;
    _dragSelecting = true;
    controller.startPhotoSelection(asset);
    controller.startDragSelection(asset, position);
    controller.isDragSelecting.value = true;
    _startDragAutoScroll();
  }

  void _updateDragSelection(Offset position) {
    _lastPointerPosition = position;

    if (!_longPressSelectionActive) {
      return;
    }

    _dragPosition = position;

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
    _dragStartAssetId = null;
    _dragSelecting = false;
    _longPressSelectionActive = false;
    controller.endDragSelection();
  }

  void _startDragAutoScroll() {
    if (_dragAutoScrollTimer != null) {
      return;
    }

    _dragAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
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
        final intensity = ((edgeSize - y) / edgeSize).clamp(0.0, 1.0);

        scrollAmount = -maxSpeed * intensity;
      } else if (y > screenHeight - edgeSize) {
        final intensity = ((y - (screenHeight - edgeSize)) / edgeSize).clamp(
          0.0,
          1.0,
        );
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
      controller.updateDragSelection(_dragPosition!);
    });
  }

  void _showScrollControls() {
    if (!mounted) return;

    _showScrollButton.value = true;
    _showFloatingDate.value = true;
    _scrollButtonTimer?.cancel();
    _scrollButtonTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      _showScrollButton.value = false;
      _showFloatingDate.value = false;
    });
  }

  void _updateScrollThumbPosition() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    const double minTop = 70;
    final double maxTop = MediaQuery.of(context).size.height - 180;

    if (maxScroll <= 0) {
      _scrollThumbTop.value = minTop;
      return;
    }

    final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    _scrollThumbTop.value = minTop + ((maxTop - minTop) * progress);
  }

  void _scrollUp() {
    _showScrollControls();
    if (!_scrollController.hasClients) return;
    final double current = _scrollController.offset;
    final double target = (current - 300).clamp(
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
    _showScrollControls();

    if (!_scrollController.hasClients) return;

    final double current = _scrollController.offset;
    final double target = (current + 300).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    final Color page = light ? const Color(0xFFF6F7F9) : const Color(0xFF0A0E14);
    final Color ink = light ? const Color(0xFF111827) : Colors.white;
    final Color muted = light ? const Color(0xFF8A94A8) : Colors.white54;
    return Scaffold(
      backgroundColor: page,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Obx(() {
          if (controller.isSelectionMode.value) {
            return AppBar(
              backgroundColor: page,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 72,

              leading: IconButton(
                onPressed: controller.clearPhotoSelection,
                icon: Icon(
                  Icons.close,
                  size: 25,
                  color: ink,
                ),
              ),

              title: Text(
                "${controller.selectedMediaIds.length} selected",
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: controller.selectAllPhotos,
                  child: Text(
                    "Select all",
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ),
              ],
            );
          }
          return AppBar(
            backgroundColor: page,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            toolbarHeight: 72,
            titleSpacing: 20,

            title: Obx(() {
              if (!controller.isSearching.value) {
                return  Text(
                  "Photos",
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                );
              }

              return TextField(
                autofocus: true,
                style: TextStyle(color: ink, fontSize: 16),
                onChanged: (value) {
                  controller.searchPhotos(value);
                },
                onSubmitted: (value) {
                  controller.searchPhotos(value);
                },
                decoration: InputDecoration(
                  hintText: "Search photos...",
                  hintStyle: TextStyle(color: muted),
                  border: InputBorder.none,

                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: ink,
                    ),
                    onPressed: () {
                      controller.isSearching.value = false;
                      controller.searchQuery.value = '';

                      controller.searchPhotos('');
                    },
                  ),
                ),
              );
            }),

            actions: [
              _CircleIconButton(
                icon: Icons.search_rounded,
                onTap: () {
                  controller.isSearching.value = true;
                },
              ),
              const SizedBox(width: 10),
              _CircleIconButton(
                icon: Icons.photo_camera_outlined,
                filled: true,
                onTap: controller.openCamera,
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                color: Theme.of(context).cardColor,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const _CircleIconButton(
                  icon: Icons.more_vert_rounded,
                ),

                onSelected: (value) {
                  if (value == "filter") {
                    showFilterDialog();
                  } else if (value == "sort") {
                    showSortDialog();
                  } else if (value == "group") {
                    showGroupByDialog();
                  } else if (value == "columns") {
                    showColumnsDialog();
                  } else if (value == "recycle") {
                    Get.to(() => RecycleBinScreen());
                    controller.refreshMedia();
                  } else if (value == "setting") {
                    Get.to(() => SettingsScreen());
                  }
                },

                itemBuilder: (context) => [

                  PopupMenuItem<String>(
                    value: "filter",
                    child: Text(
                      "Filter Media",
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: FontFamily.robotoRegular,
                      ),
                    ),
                  ),

                  PopupMenuItem<String>(
                    value: "group",
                    child: Text(
                      "Group By",
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: FontFamily.robotoRegular,
                      ),
                    ),
                  ),

                  PopupMenuItem<String>(
                    value: "columns",
                    child: Text(
                      "Columns",
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: FontFamily.robotoRegular,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
            ],
          );
        }),
      ),
      body: Obx(() {
        if (controller.smartSearchController.isAnalyzing.value) {
          return const Center(child: SplashLoader());
        }

        if (!controller.firstPageLoaded.value &&
            controller.filteredMedia.isEmpty) {
          return const SizedBox();
        }
        if (controller.filteredMedia.isEmpty) {
          return const _NoMediaFound();
        }

        final rows = controller.galleryRows;
        if (_floatingDate.value.isEmpty && rows.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateFloatingDate();
            }
          });
        }
        final int columns = controller.crossAxisCount.value.clamp(2, 8);
        final List<_MosaicEntry> entries = columns == 3
            ? _mosaicEntries(controller.groupedMedia)
            : _columnEntries(controller.groupedMedia, columns);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _lastPointerPosition = event.position;
            _trackPinchDown(event.pointer, event.position);
          },

          onPointerMove: (event) {
            _updateDragSelection(event.position);
            _trackPinchMove(event.pointer, event.position);
          },
          onPointerUp: (event) {
            _lastPointerPosition = event.position;
            _trackPinchEnd(event.pointer);
            _endDragSelection();
          },
          onPointerCancel: (event) {
            _trackPinchEnd(event.pointer);
            _endDragSelection();
          },

          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _showScrollControls();
            },

            child: SizedBox(
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification) {
                        _isScrolling = true;

                        _scrollButtonTimer?.cancel();
                        _showScrollButton.value = true;
                        _showFloatingDate.value = true;
                        _updateScrollThumbPosition();

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _updateFloatingDate();
                          }
                        });
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

                    child: RefreshIndicator(
                      onRefresh: () async {
                        await controller.refreshMedia();
                      },

                      child: ListView.builder(
                        controller: _scrollController,

                        physics: controller.isDragSelecting.value || _pinchZooming
                            ? const NeverScrollableScrollPhysics()
                            : null,

                        padding: const EdgeInsets.only(top: 8, bottom: 130),

                        cacheExtent: 600,

                        addAutomaticKeepAlives: false,

                        addRepaintBoundaries: true,

                        itemCount: entries.length,

                        itemBuilder: (context, index) {
                          return _buildMosaicEntry(context, entries[index], index);
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 140,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: light
                                ? const [Color(0x00F6F7F9), Color(0xF2F6F7F9)]
                                : const [Color(0x000A0E14), Color(0xF20A0E14)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Obx(() {
                      if (!_showFloatingDate.value ||
                          _floatingDate.value.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return IgnorePointer(
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
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
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
                      );
                    }),
                  ),

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
                        duration: const Duration(milliseconds: 180),
                        opacity: _showScrollButton.value ? 1 : 0,

                        child: IgnorePointer(
                          ignoring: !_showScrollButton.value,

                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                _showScrollControls();
                                if (!_scrollController.hasClients) return;
                                _scrollController.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 500),
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
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
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
            ),
          ),
        );
      }),
    );
  }

  static const double _mosaicGap = 2;

  List<_MosaicEntry> _mosaicEntries(List<GroupSection> sections) {
    const List<_MosaicPattern> order = [
      _MosaicPattern.row,
      _MosaicPattern.bigLeft,
      _MosaicPattern.row,
    ];

    final List<_MosaicEntry> entries = <_MosaicEntry>[];
    for (final GroupSection section in sections) {
      if (section.title.isNotEmpty) {
        entries.add(_MosaicEntry.header(section.title, section.media.length));
      }
      final List<AssetEntity> items = section.media;
      int index = 0;
      int cycle = 0;
      while (index < items.length) {
        _MosaicPattern pattern = order[cycle % order.length];
        final int remaining = items.length - index;
        final int take = remaining < 3 ? remaining : 3;
        if (take < 3) {
          pattern = _MosaicPattern.row;
        }
        entries.add(
          _MosaicEntry.block(pattern, items.sublist(index, index + take)),
        );
        index += take;
        cycle++;
      }
    }
    return entries;
  }

  List<_MosaicEntry> _columnEntries(
    List<GroupSection> sections,
    int columns,
  ) {
    final List<_MosaicEntry> entries = <_MosaicEntry>[];
    for (final GroupSection section in sections) {
      if (section.title.isNotEmpty) {
        entries.add(_MosaicEntry.header(section.title, section.media.length));
      }
      final List<AssetEntity> items = section.media;
      for (int index = 0; index < items.length; index += columns) {
        final int end = index + columns > items.length
            ? items.length
            : index + columns;
        entries.add(
          _MosaicEntry.block(_MosaicPattern.row, items.sublist(index, end)),
        );
      }
    }
    return entries;
  }

  Widget _buildMosaicEntry(BuildContext context, _MosaicEntry entry, int index) {
    if (entry.title != null) {
      final GlobalKey headerKey = _dateHeaderKeys.putIfAbsent(
        entry.title!,
        () => GlobalKey(),
      );
      return Container(
        key: headerKey,
        padding: EdgeInsets.fromLTRB(20, index == 0 ? 8 : 20, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.title!,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFF111827)
                      : const Color(0xFFF8FAFC),
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
            ),
            if (controller.showFileCount.value)
              Text(
                '${entry.count}',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFF8A94A8)
                      : Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: _mosaicGap),
      child: _MosaicBlock(
        pattern: entry.pattern!,
        items: entry.items,
        gap: _mosaicGap,
        columns: entry.pattern == _MosaicPattern.bigLeft
            ? 3
            : controller.crossAxisCount.value.clamp(2, 8),
        tileBuilder: _photoTile,
      ),
    );
  }

  Widget _photoTile(AssetEntity asset, bool big) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          if (controller.isSelectionMode.value) {
            controller.togglePhotoSelection(asset);
            return;
          }
          Get.to(() => PhotoViewScreen(asset: asset));
        },
        onLongPress: () {
          _startDragSelectionAfterLongPress(asset);
        },
        child: MediaItem(
          key: controller.selectionKeyFor(asset.id),
          asset: asset,
          expand: true,
          big: big,
        ),
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
                    color: Theme.of(context).colorScheme.onSurface,
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
              color: value
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showFilterDialog() async {
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
          backgroundColor: InnerChrome.dialogBg,
          surfaceTintColor: Colors.transparent,
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                              borderRadius: BorderRadius.circular(12),
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

                            await controller.applyMediaFilter();

                            Navigator.pop(dialogContext);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: InnerChrome.dialogPrimaryBg,
                            foregroundColor: InnerChrome.dialogPrimaryFg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                    color: Theme.of(context).colorScheme.onSurface,
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
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: AppColors.fg(const Color(0xff333333)),
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
                    ? AppColors.fg(const Color(0xff444444))
                    : AppColors.fg(const Color(0xffAAAAAA)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showSortDialog() async {
    final RxString selectedSort = controller.sortBy.value.obs;
    final RxBool selectedOrder = controller.sortAscending.value.obs;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: InnerChrome.dialogBg,
          surfaceTintColor: Colors.transparent,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                _sortRow(title: "File Name", selectedSort: selectedSort),

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
                            await controller.applySort(
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

  Future<void> showGroupByDialog() async {
    final RxString selectedGroup = controller.groupBy.value.obs;
    final RxBool selectedOrder = controller.groupAscending.value.obs;
    final RxBool selectedFileCount = controller.showFileCount.value.obs;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: InnerChrome.dialogBg,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 39),
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
                    "Group by",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: FontFamily.robotoBold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                _groupRow(
                  title: "Do not group files",
                  selectedGroup: selectedGroup,
                ),

                _groupRow(
                  title: "Last modified (daily)",
                  selectedGroup: selectedGroup,
                ),

                _groupRow(
                  title: "Last modified (monthly)",
                  selectedGroup: selectedGroup,
                ),

                _groupRow(
                  title: "Date taken (daily)",
                  selectedGroup: selectedGroup,
                ),

                _groupRow(
                  title: "Date taken (monthly)",
                  selectedGroup: selectedGroup,
                ),

                _groupRow(title: "File type", selectedGroup: selectedGroup),

                _groupRow(title: "Extension", selectedGroup: selectedGroup),

                _groupRow(title: "Folder", selectedGroup: selectedGroup),

                const Divider(height: 18),

                _groupOrderRow(
                  title: "Ascending",
                  value: true,
                  selectedOrder: selectedOrder,
                ),

                _groupOrderRow(
                  title: "Descending",
                  value: false,
                  selectedOrder: selectedOrder,
                ),

                const Divider(height: 18),

                Obx(
                  () => SizedBox(
                    height: 35,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Show file count at section headers",
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: FontFamily.robotoRegular,
                              color: selectedFileCount.value
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            selectedFileCount.toggle();
                          },
                          child: Icon(
                            selectedFileCount.value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 19,
                            color: selectedFileCount.value
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

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
                              borderRadius: BorderRadius.circular(12),
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
                          onPressed: () {
                            controller.groupBy.value = selectedGroup.value;
                            controller.groupAscending.value =
                                selectedOrder.value;
                            controller.showFileCount.value =
                                selectedFileCount.value;

                            Navigator.pop(dialogContext);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: InnerChrome.dialogPrimaryBg,
                            foregroundColor: InnerChrome.dialogPrimaryFg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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

  Widget _groupRow({required String title, required RxString selectedGroup}) {
    return Obx(
      () => SizedBox(
        height: 35,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  selectedGroup.value = title;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: FontFamily.robotoRegular,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                selectedGroup.value = title;
              },
              child: Icon(
                selectedGroup.value == title
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectedGroup.value == title
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupOrderRow({
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: FontFamily.robotoRegular,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
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
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showColumnsDialog() async {
    final RxInt selectedColumns = controller.crossAxisCount.value.obs;

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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                _columnRow(
                  title: "2 Grid",
                  value: 2,
                  selectedColumns: selectedColumns,
                ),

                _columnRow(
                  title: "3 Grid",
                  value: 3,
                  selectedColumns: selectedColumns,
                ),

                _columnRow(
                  title: "4 Grid",
                  value: 4,
                  selectedColumns: selectedColumns,
                ),

                _columnRow(
                  title: "5 Grid",
                  value: 5,
                  selectedColumns: selectedColumns,
                ),

                _columnRow(
                  title: "6 Grid",
                  value: 6,
                  selectedColumns: selectedColumns,
                ),

                _columnRow(
                  title: "7 Grid",
                  value: 7,
                  selectedColumns: selectedColumns,
                ),

                _columnRow(
                  title: "8 Grid",
                  value: 8,
                  selectedColumns: selectedColumns,
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () {
                      controller.saveGridColumns(selectedColumns.value);

                      Navigator.pop(dialogContext);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: InnerChrome.dialogPrimaryBg,
                      foregroundColor: InnerChrome.dialogPrimaryFg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _columnRow({
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MediaItem extends StatefulWidget {
  final AssetEntity asset;
  final bool expand;
  final bool big;

  const MediaItem({
    super.key,
    required this.asset,
    this.expand = false,
    this.big = false,
  });

  @override
  State<MediaItem> createState() => _MediaItemState();
}

class _MediaItemState extends State<MediaItem> {
  final PhotosController controller = Get.find<PhotosController>();

  late Future<Uint8List?> _thumbnailFuture;

  AssetEntity get asset => widget.asset;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = controller.getThumbnail(widget.asset);
  }

  @override
  void dispose() {
    controller.removeSelectionKey(widget.asset.id);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MediaItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnailFuture = controller.getThumbnail(widget.asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget tile = ClipRRect(
        borderRadius: BorderRadius.circular(widget.expand ? 0 : 2),

        child: FutureBuilder<Uint8List?>(
          future: _thumbnailFuture,

          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return ColoredBox(
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFFE8EDF2)
                    : const Color(0xFF1A2230),
              );
            }

            return Stack(
              fit: StackFit.expand,

              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  cacheWidth: 300,
                ),

                if (asset.type == AssetType.video && widget.expand && widget.big)
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x73000000),
                      ),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                if (asset.type == AssetType.video &&
                    widget.expand &&
                    asset.videoDuration.inSeconds > 0)
                  Positioned(
                    right: 6,
                    bottom: 5,
                    child: Text(
                      _videoClock(asset.videoDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Color(0xB3000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                if (asset.type == AssetType.video &&
                    widget.expand &&
                    !widget.big &&
                    asset.videoDuration.inSeconds <= 0)
                  const Positioned(
                    right: 5,
                    bottom: 4,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                if (asset.type == AssetType.video && !widget.expand)
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surface(Colors.black54),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),

                Obx(() {
                  if (!controller.isSelectionMode.value) {
                    return const SizedBox.shrink();
                  }

                  final selected = controller.isPhotoSelected(asset);

                  return Positioned(
                    top: 6,
                    left: 6,

                    child: GestureDetector(
                      onTap: () {
                        controller.togglePhotoSelection(asset);
                      },

                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),

                        width: 25,
                        height: 25,

                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.black
                              : AppColors.surface(Colors.black26),

                          shape: BoxShape.circle,

                          border: Border.all(
                            color: AppColors.border(Colors.white),
                            width: 1.5,
                          ),
                        ),

                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 17,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
    );
    if (!widget.expand) {
      return AspectRatio(aspectRatio: 1, child: tile);
    }
    return tile;
  }
}

String _videoClock(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

enum _MosaicPattern { row, bigLeft }

class _MosaicEntry {
  final String? title;
  final int count;
  final _MosaicPattern? pattern;
  final List<AssetEntity> items;

  const _MosaicEntry.header(this.title, this.count)
    : pattern = null,
      items = const [];

  const _MosaicEntry.block(this.pattern, this.items) : title = null, count = 0;
}

class _MosaicBlock extends StatelessWidget {
  final _MosaicPattern pattern;
  final List<AssetEntity> items;
  final double gap;
  final int columns;
  final Widget Function(AssetEntity asset, bool big) tileBuilder;

  const _MosaicBlock({
    required this.pattern,
    required this.items,
    required this.gap,
    required this.columns,
    required this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int span = pattern == _MosaicPattern.bigLeft ? 3 : columns;
        final double tile =
            (constraints.maxWidth - gap * (span - 1)) / span;
        final double big = tile * 2 + gap;

        Widget cell(int index, double size, {bool isBig = false}) {
          return SizedBox(
            width: size,
            height: size,
            child: tileBuilder(items[index], isBig),
          );
        }

        if (pattern == _MosaicPattern.bigLeft && items.length == 3) {
          return SizedBox(
            height: big,
            child: Row(
              children: [
                cell(0, big, isBig: true),
                SizedBox(width: gap),
                Column(
                  children: [
                    cell(1, tile),
                    SizedBox(height: gap),
                    cell(2, tile),
                  ],
                ),
              ],
            ),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i != 0) SizedBox(width: gap),
              cell(i, tile),
            ],
          ],
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    final Widget button = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: light
            ? Colors.white
            : (filled ? Colors.white : const Color(0xFF121823)),
        border: light
            ? Border.all(color: const Color(0xFFE6EAEF))
            : (filled
                ? null
                : Border.all(color: const Color(0xFF2A3342), width: 1)),
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
        size: 22,
        color: light
            ? const Color(0xFF111827)
            : (filled ? const Color(0xFF0A0E14) : Colors.white),
      ),
    );
    if (onTap == null) {
      return button;
    }
    return GestureDetector(onTap: onTap, child: button);
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
              fontFamily: FontFamily.robotoBold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "All your photos and videos will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: FontFamily.robotoRegular,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
