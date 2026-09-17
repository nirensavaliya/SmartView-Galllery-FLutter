import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinView.dart';
import 'package:gallery_photos/View/Utils/App_Routes.dart';
import 'package:gallery_photos/View/Widget/Common_Text.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import 'Controller/PhotosController.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final PhotosController controller = Get.find<PhotosController>();
  final ScrollController _scrollController = ScrollController();

  Timer? _scrollButtonTimer;

  bool _showScrollButton = true;

  @override
  void dispose() {
    _scrollButtonTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
  void _showScrollButtonTemporarily() {
    if (!mounted) return;

    setState(() {
      _showScrollButton = true;
    });

    _scrollButtonTimer?.cancel();

    _scrollButtonTimer = Timer(
      const Duration(seconds: 2),
          () {
        if (!mounted) return;

        setState(() {
          _showScrollButton = false;
        });
      },
    );
  }
  void _scrollUp() {
    _showScrollButtonTemporarily();

    if (!_scrollController.hasClients) return;

    final double current =
        _scrollController.offset;

    final double target =
    (current - 300).clamp(
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
    _showScrollButtonTemporarily();

    if (!_scrollController.hasClients) return;

    final double current =
        _scrollController.offset;

    final double target =
    (current + 300).clamp(
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
    return Scaffold(
      backgroundColor: const Color(0xffF1F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xffF1F3F5),
        elevation: 0,
        title: Text(
          "Photos",
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
                // Settings
              }
            },

            itemBuilder: (context) => [
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
                value: "group",
                child: Text(
                  "Group By",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
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

      body: Obx(() {
        if (!controller.firstPageLoaded.value &&
            controller.filteredMedia.isEmpty) {
          return const SizedBox();
        }
        if (controller.filteredMedia.isEmpty) {
          return const _NoMediaFound();
        }

        final grouped = controller.groupedMedia;

        // return GestureDetector(
        //   behavior: HitTestBehavior.translucent,
        //   onTap: () {
        //     _showScrollButtonTemporarily();
        //   },
        //   onScaleStart: (details) {
        //     controller.onGridScaleStart();
        //   },
        //
        //   onScaleUpdate: (details) {
        //     controller.onGridScaleUpdate(details.scale);
        //   },
        //
        //   child: ListView.builder(
        //     padding: const EdgeInsets.only(top: 8, bottom: 30),
        //     itemCount: _getTotalItemCount(grouped),
        //     itemBuilder: (context, index) {
        //       return _buildItem(context, grouped, index);
        //     },
        //   ),
        // );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,

          onTap: () {
            _showScrollButtonTemporarily();
          },

          onScaleStart: (details) {
            _showScrollButtonTemporarily();

            controller.onGridScaleStart();
          },

          onScaleUpdate: (details) {
            _showScrollButtonTemporarily();

            controller.onGridScaleUpdate(
              details.scale,
            );
          },

          child: Stack(
            children: [

              // =====================================================
              // MAIN SCROLLABLE PHOTO GRID
              // =====================================================

              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  _showScrollButtonTemporarily();

                  return false;
                },

                child: ListView.builder(
                  controller: _scrollController,

                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 30,
                  ),

                  itemCount:
                  _getTotalItemCount(grouped),

                  itemBuilder: (context, index) {
                    return _buildItem(
                      context,
                      grouped,
                      index,
                    );
                  },
                ),
              ),

              // =====================================================
              // RIGHT SIDE UP / DOWN BUTTON
              // =====================================================

              Positioned(
                right: 0,
                top: 8,

                child: AnimatedOpacity(
                  duration: const Duration(
                    milliseconds: 250,
                  ),

                  opacity:
                  _showScrollButton ? 1.0 : 0.0,

                  child: IgnorePointer(
                    ignoring: !_showScrollButton,

                    child: GestureDetector(
                      onTap: () {
                        _showScrollButtonTemporarily();
                      },

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
                              color: Colors.black.withOpacity(
                                0.20,
                              ),
                              blurRadius: 6,
                              offset: const Offset(
                                -2,
                                2,
                              ),
                            ),
                          ],
                        ),

                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,

                          children: [

                            // ===============================
                            // UP
                            // ===============================

                            SizedBox(
                              height: 30,
                              width: 42,

                              child: Material(
                                color: Colors.transparent,

                                child: InkWell(
                                  onTap: _scrollUp,

                                  borderRadius:
                                  const BorderRadius.only(
                                    topLeft:
                                    Radius.circular(20),
                                  ),

                                  child: const Icon(
                                    Icons.keyboard_arrow_up,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: 30,
                              width: 42,

                              child: Material(
                                color: Colors.transparent,

                                child: InkWell(
                                  onTap: _scrollDown,

                                  borderRadius:
                                  const BorderRadius.only(
                                    bottomLeft:
                                    Radius.circular(20),
                                  ),

                                  child: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 24,
                                  ),
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
          ),
        );
      }),
    );
  }

  int _getTotalItemCount(List<GroupSection> grouped) {
    int count = 0;
    for (final section in grouped) {
      if (section.title.isNotEmpty) {
        count++;
      }

      count +=
          (section.media.length + controller.crossAxisCount.value - 1) ~/
          controller.crossAxisCount.value;
    }

    return count;
  }

  Widget _buildItem(
    BuildContext context,
    List<GroupSection> grouped,
    int index,
  ) {
    int currentIndex = 0;

    final columns = controller.crossAxisCount.value;

    for (final section in grouped) {
      final title = section.title;
      final media = section.media;

      // Group header
      if (title.isNotEmpty) {
        if (index == currentIndex) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: FontFamily.robotoBold,
                    ),
                  ),
                ),

                if (controller.showFileCount.value)
                  Text(
                    "${media.length}",
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: FontFamily.robotoRegular,
                      color: const Color(0xff888888),
                    ),
                  ),
              ],
            ),
          );
        }

        currentIndex++;
      }

      final rowCount = (media.length + columns - 1) ~/ columns;

      for (int row = 0; row < rowCount; row++) {
        if (index == currentIndex) {
          final start = row * columns;

          final end = (start + columns > media.length)
              ? media.length
              : start + columns;

          final rowMedia = media.sublist(start, end);

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
                          Get.to(() => PhotoViewScreen(asset: asset));
                        },
                        child: MediaItem(asset: asset),
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
                            // Actual controller values ONLY on OK
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

  Future<void> showSortDialog() async {
    final RxString selectedSort = controller.sortBy.value.obs;
    final RxBool selectedOrder = controller.sortAscending.value.obs;
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
                            await controller.applySort(
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

  Future<void> showGroupByDialog() async {
    final RxString selectedGroup = controller.groupBy.value.obs;
    final RxBool selectedOrder = controller.groupAscending.value.obs;
    final RxBool selectedFileCount = controller.showFileCount.value.obs;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
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
                                  ? const Color(0xff333333)
                                  : const Color(0xff999999),
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
                                ? const Color(0xff444444)
                                : const Color(0xffAAAAAA),
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
                          onPressed: () {
                            controller.groupBy.value = selectedGroup.value;
                            controller.groupAscending.value =
                                selectedOrder.value;
                            controller.showFileCount.value =
                                selectedFileCount.value;

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
                      color: const Color(0xff333333),
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
                    ? const Color(0xff444444)
                    : const Color(0xffAAAAAA),
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
                      color: const Color(0xff333333),
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
                    ? const Color(0xff444444)
                    : const Color(0xffAAAAAA),
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

class MediaItem extends StatelessWidget {
  final AssetEntity asset;

  const MediaItem({
    super.key,
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    final PhotosController controller =
    Get.find<PhotosController>();

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: FutureBuilder<Uint8List?>(
          future: controller.getThumbnail(asset),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return Container(
                color: Colors.grey.shade300,
              );
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

String formatGalleryDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return "$day.$month.${date.year}";
}
