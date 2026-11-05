import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import 'Controller/CleanerSelectionController.dart';

class CleanerMediaSelectionScreen extends StatelessWidget {
  final List<AssetEntity> assets;
  final String title;
  final bool groupBySize;
  final bool groupByDate;
  const CleanerMediaSelectionScreen({
    super.key,
    required this.assets,
    required this.title,
    this.groupBySize = false,
    this.groupByDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final String tag =
        'cleaner_${title}_${DateTime.now().microsecondsSinceEpoch}';

    final CleanerSelectionController controller = Get.put(
      CleanerSelectionController(
        assets: assets,
        title: title,
        groupBySize: groupBySize,
        groupByDate: groupByDate,
      ),
      tag: tag,
    );

    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading:   Padding(
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
              onPressed: () => Get.back(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: InnerChrome.ink,
              size: 18,
            ),
            ),
          ),
        ),
        title: Obx(
          () => Text(
            controller.selectedCount == 0
                ? title
                : '${controller.selectedCount} selected',
            style: TextStyle(
              color: InnerChrome.ink,
              fontSize: 19,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),

        actions: [
          Obx(
            () => IconButton(
              onPressed: controller.assets.isEmpty
                  ? null
                  : controller.toggleSelectAll,
              icon: Icon(
                controller.isAllSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: controller.isAllSelected
                    ? InnerChrome.pick
                    : InnerChrome.muted,
                size: 22,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final currentAssets = controller.assets;

              if (currentAssets.isEmpty) {
                return Center(
                  child: Text(
                    'No items found',
                    style: TextStyle(
                      color: InnerChrome.muted,
                      fontSize: 14,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 90),
                physics: const BouncingScrollPhysics(),
                children: [
                  if (controller.assets.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.content_copy_rounded,
                              size: 52,
                              color: InnerChrome.muted,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'No duplicate photos found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: InnerChrome.ink,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Your gallery has no duplicate photos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: InnerChrome.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (groupBySize)
                    _GroupedMediaGrid(controller: controller)
                  else if (groupByDate)
                    _DateGroupedMediaGrid(controller: controller)
                  else
                    _MediaGrid(controller: controller),
                ],
              );
            }),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _DetailCleanButton(
                    busy: controller.isDeleting.value,
                    label: controller.isDeleting.value
                        ? 'Deleting...'
                        : 'Delete (${controller.selectedSizeText})',
                    onTap: controller.selectedCount == 0
                        ? null
                        : controller.deleteSelected,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateGroupedMediaGrid extends StatelessWidget {
  final CleanerSelectionController controller;

  const _DateGroupedMediaGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<AssetEntity>>>(
      future: _createDateGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashLoader();
        }

        final groups = snapshot.data ?? {};

        if (groups.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: 50),
            child: Center(
              child: Text(
                'No duplicate photos found',
                style: TextStyle(
                  color: InnerChrome.muted,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
        final List<AssetEntity> photoViewAssets = groups.values
            .expand((group) => group)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in groups.entries)
              _DateGroup(
                title: entry.key,
                assets: entry.value,
                controller: controller,
                photoViewAssets: photoViewAssets,
              ),
          ],
        );
      },
    );
  }

  Future<Map<String, List<AssetEntity>>> _createDateGroups() async {
    final Map<String, List<AssetEntity>> groups = {};

    final List<AssetEntity> sortedAssets = List<AssetEntity>.from(
      controller.assets,
    );

    sortedAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    for (final asset in sortedAssets) {
      final DateTime date = asset.createDateTime;

      final String month = _monthName(date.month);
      final String key = '$month ${date.day}';

      groups.putIfAbsent(key, () => <AssetEntity>[]);

      groups[key]!.add(asset);
    }

    return groups;
  }

  String _monthName(int month) {
    const months = [
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

class _DateGroup extends StatelessWidget {
  final String title;
  final List<AssetEntity> assets;
  final CleanerSelectionController controller;
  final List<AssetEntity> photoViewAssets;

  const _DateGroup({
    required this.title,
    required this.assets,
    required this.controller,
    required this.photoViewAssets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Plus Jakarta Sans',
                      color: InnerChrome.ink,
                    ),
                  ),
                ),

                Obx(() {
                  final bool allSelected =
                      assets.isNotEmpty &&
                      assets.every(
                        (asset) => controller.selectedIds.contains(asset.id),
                      );

                  return GestureDetector(
                    onTap: () async {
                      if (allSelected) {
                        for (final asset in assets) {
                          controller.selectedIds.remove(asset.id);
                        }
                      } else {
                        for (final asset in assets) {
                          controller.selectedIds.add(asset.id);
                        }
                      }

                      controller.selectedIds.refresh();
                      await controller.recalculate();
                    },
                    child: Icon(
                      allSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: InnerChrome.pick,
                      size: 21,
                    ),
                  );
                }),
              ],
            ),
          ),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: assets.length,
            itemBuilder: (context, index) {
              return _CleanerMediaTile(
                asset: assets[index],
                controller: controller,
                photoViewAssets: photoViewAssets,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final CleanerSelectionController controller;

  const _MediaGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final assets = controller.assets;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return _CleanerMediaTile(asset: assets[index], controller: controller);
      },
    );
  }
}

class _GroupedMediaGrid extends StatelessWidget {
  final CleanerSelectionController controller;

  const _GroupedMediaGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<AssetEntity>>>(
      future: _createGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashLoader();
        }

        final groups = snapshot.data ?? {};

        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.only(top: 50),
              child: Text(
                'No large media found',
                style: TextStyle(color: InnerChrome.muted),
              ),
            ),
          );
        }

        final orderedKeys = [
          'Photos - 50+ MB',
          'Photos - 30-50 MB',
          'Photos - 20-30 MB',
          'Videos - 50+ MB',
          'Videos - 30-50 MB',
          'Videos - 20-30 MB',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final key in orderedKeys)
              if (groups[key]?.isNotEmpty == true)
                _SizeGroup(
                  title: key,
                  assets: groups[key]!,
                  controller: controller,
                ),
          ],
        );
      },
    );
  }

  Future<Map<String, List<AssetEntity>>> _createGroups() async {
    final Map<String, List<AssetEntity>> groups = {};

    for (final asset in controller.assets) {
      final int bytes = await asset.fileSize;

      if (bytes < 20 * 1024 * 1024) {
        continue;
      }

      final double mb = bytes / (1024 * 1024);

      final String mediaType = asset.type == AssetType.video
          ? 'Videos'
          : 'Photos';

      String sizeGroup;

      if (mb >= 50) {
        sizeGroup = '50+ MB';
      } else if (mb >= 30) {
        sizeGroup = '30-50 MB';
      } else {
        sizeGroup = '20-30 MB';
      }

      final String group = '$mediaType - $sizeGroup';

      groups.putIfAbsent(group, () => <AssetEntity>[]);

      groups[group]!.add(asset);
    }

    return groups;
  }
}

class _SizeGroup extends StatelessWidget {
  final String title;
  final List<AssetEntity> assets;
  final CleanerSelectionController controller;

  const _SizeGroup({
    required this.title,
    required this.assets,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Plus Jakarta Sans',
                      color: InnerChrome.ink,
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () async {
                    bool allSelected = assets.every(
                      (asset) => controller.selectedIds.contains(asset.id),
                    );

                    for (final asset in assets) {
                      if (allSelected) {
                        controller.selectedIds.remove(asset.id);
                      } else {
                        controller.selectedIds.add(asset.id);
                      }
                    }

                    controller.selectedIds.refresh();
                    await controller.recalculate();
                  },
                  child: Obx(() {
                    final bool allSelected = assets.every(
                      (asset) => controller.selectedIds.contains(asset.id),
                    );

                    return Icon(
                      allSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: InnerChrome.pick,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
          ),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),

            itemCount: assets.length,

            itemBuilder: (context, index) {
              return _CleanerMediaTile(
                asset: assets[index],
                controller: controller,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CleanerMediaTile extends StatefulWidget {
  final AssetEntity asset;
  final CleanerSelectionController controller;
  final List<AssetEntity>? photoViewAssets;

  const _CleanerMediaTile({
    required this.asset,
    required this.controller,
    this.photoViewAssets,
  });

  @override
  State<_CleanerMediaTile> createState() => _CleanerMediaTileState();
}

class _CleanerMediaTileState extends State<_CleanerMediaTile> {
  Future<File?>? _fileFuture;
  Future<int>? _fileSizeFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = widget.asset.file;
    _fileSizeFuture = widget.asset.fileSize;
  }

  @override
  void didUpdateWidget(covariant _CleanerMediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.asset.id != widget.asset.id) {
      _fileFuture = widget.asset.file;
      _fileSizeFuture = widget.asset.fileSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PhotosController photosController = Get.find<PhotosController>();

    return Obx(() {
      final bool selected = widget.controller.selectedIds.contains(
        widget.asset.id,
      );

      return GestureDetector(
        onTap: () {
          final List<AssetEntity> mediaList =
              widget.photoViewAssets ?? widget.controller.assets.toList();

          final int index = mediaList.indexWhere(
            (asset) => asset.id == widget.asset.id,
          );

          if (index == -1) return;

          Get.to(
            () => PhotoViewScreen(
              asset: widget.asset,
              albumMedia: List<AssetEntity>.from(mediaList),
            ),
          );
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
                  future: photosController.getThumbnail(widget.asset),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return ColoredBox(color: InnerChrome.alt);
                    }
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    );
                  },
                ),

                if (selected) Container(color: Colors.black26),

                if (widget.asset.type == AssetType.video)
                  Positioned(
                    right: 6,
                    bottom: 6,
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

                Positioned(
                  left: 6,
                  bottom: 6,
                  child: FutureBuilder<int>(
                    future: _fileSizeFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatSize(snapshot.data!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Positioned(
                  top: 6,
                  left: 6,
                  child: selected
                      ? Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: InnerChrome.pick,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: InnerChrome.pickInk,
                          ),
                        )
                      : Container(
                          width: 22,
                          height: 22,
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

  String _formatSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }

    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }

    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }

    return '$bytes B';
  }
}

class _DetailCleanButton extends StatelessWidget {
  const _DetailCleanButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final canTap = onTap != null && !busy;
    const radius = BorderRadius.all(Radius.circular(16));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: InnerChrome.actionShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: canTap ? onTap : null,
          borderRadius: radius,
          child: Ink(
            decoration: const BoxDecoration(
              borderRadius: radius,
              gradient: InnerChrome.actionGradient,
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
