import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/Controller/CleanerController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

class CleanerCategoryScreen extends StatelessWidget {
  const CleanerCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CleanerController>();
    final type = Get.arguments as CleanerCategoryType? ??
        CleanerCategoryType.largeFiles;

    return Obx(() {
      final category = controller.categoryOf(type);
      final items = category.items;
      final selectedCount = controller.selectedIds.length;
      final selectedBytes = controller.selectedBytes(items);

      return Scaffold(
        backgroundColor: InnerChrome.page,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: InnerChrome.page,
          surfaceTintColor: Colors.transparent,
          foregroundColor: InnerChrome.ink,
          automaticallyImplyLeading: false,
          leading:    Padding(
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
          title: Text(
            category.title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              fontFamily: 'Plus Jakarta Sans',
              color: InnerChrome.ink,
              letterSpacing: -0.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: items.isEmpty
                  ? null
                  : () {
                      if (selectedCount == items.length) {
                        controller.clearSelection();
                      } else {
                        controller.selectAll(items);
                      }
                    },
              child: Text(
                selectedCount == items.length && items.isNotEmpty
                    ? 'Clear'
                    : 'Select all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: InnerChrome.accent,
                ),
              ),
            ),
          ],
        ),
        body: items.isEmpty
            ? Center(
                child: controller.scanning.value
                    ? const SplashLoader()
                    : Text(
                        'No items in this category',
                        style: TextStyle(color: InnerChrome.muted),
                      ),
              )
            : type == CleanerCategoryType.duplicatePhotos
                ? _DuplicateList(controller: controller)
                : _AssetGrid(controller: controller, items: items),
        bottomNavigationBar: selectedCount == 0
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 52,
                    child: _DetailCleanButton(
                      busy: controller.deleting.value,
                      label:
                          'Delete $selectedCount · ${CleanerController.formatBytes(selectedBytes)}',
                      onTap: () => _confirmDelete(
                        context,
                        controller,
                        items,
                        selectedCount,
                        selectedBytes,
                      ),
                    ),
                  ),
                ),
              ),
      );
    });
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CleanerController controller,
    List<CleanerAssetItem> items,
    int count,
    int bytes,
  ) async {
    final ok = await Get.dialog<bool>(
      ChromeDialog(
        title: 'Delete selected?',
        message:
            'Delete $count item(s) (${CleanerController.formatBytes(bytes)}) from your gallery? This cannot be undone from Cleaner.',
        actions: [
          ChromeButton.cancel(onPressed: () => Get.back(result: false)),
          ChromeButton.danger(
            label: 'Delete',
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final deleted = await controller.deleteSelected(items);
    Get.snackbar(
      deleted > 0 ? 'Cleaned' : 'Not deleted',
      deleted > 0
          ? '$deleted item(s) deleted'
          : 'Could not delete the selected photos',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
    if (controller.categoryOf(Get.arguments as CleanerCategoryType).count ==
        0) {
      Get.back();
    }
  }
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.controller,
    required this.items,
  });

  final CleanerController controller;
  final List<CleanerAssetItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Obx(() {
          final selected = controller.selectedIds.contains(item.asset.id);
          return _ThumbTile(
            key: ValueKey(item.asset.id),
            asset: item.asset,
            bytesLabel: CleanerController.formatBytes(item.bytes),
            selected: selected,
            onTap: () => controller.toggleSelection(item.asset.id),
          );
        });
      },
    );
  }
}

class _DuplicateList extends StatelessWidget {
  const _DuplicateList({required this.controller});

  final CleanerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final groups = controller.duplicateGroups;
      if (groups.isEmpty) {
        return Center(
          child: Text(
            'No duplicates found',
            style: TextStyle(color: InnerChrome.muted),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: groups.length,
        itemBuilder: (_, index) {
          final group = groups[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                child: Text(
                  'Group ${index + 1} · ${group.items.length} photos · reclaim ${CleanerController.formatBytes(group.reclaimableBytes)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: InnerChrome.muted,
                  ),
                ),
              ),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: group.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final item = group.items[i];
                    final isKeep = i == 0;
                    return Obx(() {
                      final selected =
                          controller.selectedIds.contains(item.asset.id);
                      return SizedBox(
                        width: 100,
                        child: Stack(
                          children: [
                            _ThumbTile(
                              key: ValueKey(item.asset.id),
                              asset: item.asset,
                              bytesLabel:
                                  CleanerController.formatBytes(item.bytes),
                              selected: selected,
                              onTap: () =>
                                  controller.toggleSelection(item.asset.id),
                            ),
                            if (isKeep)
                              Positioned(
                                left: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: InnerChrome.accent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Keep',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          );
        },
      );
    });
  }
}

class _ThumbTile extends StatefulWidget {
  const _ThumbTile({
    super.key,
    required this.asset,
    required this.bytesLabel,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity asset;
  final String bytesLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ThumbTile> createState() => _ThumbTileState();
}

class _ThumbTileState extends State<_ThumbTile> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _load(widget.asset);
  }

  @override
  void didUpdateWidget(covariant _ThumbTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnailFuture = _load(widget.asset);
    }
  }

  Future<Uint8List?> _load(AssetEntity asset) async {
    final Uint8List? first = await _bytes(asset);
    if (first != null && first.isNotEmpty) return first;
    final AssetEntity? fresh = await AssetEntity.fromId(asset.id);
    if (fresh == null) return first;
    return _bytes(fresh);
  }

  Future<Uint8List?> _bytes(AssetEntity asset) {
    return asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: widget.selected
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
                builder: (context, snap) {
                  if (snap.data == null) {
                    return ColoredBox(color: InnerChrome.alt);
                  }
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  color: Colors.black54,
                  child: Text(
                    widget.bytesLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
              if (widget.selected) Container(color: Colors.black26),
              Positioned(
                right: 6,
                top: 6,
                child: widget.selected
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
                          border: Border.all(color: Colors.white54, width: 1.5),
                        ),
                      ),
              ),
              if (widget.asset.type == AssetType.video)
                const Positioned(
                  left: 4,
                  bottom: 18,
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
