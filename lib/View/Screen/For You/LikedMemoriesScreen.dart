import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/For%20You/MemoryShareScreen.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Screen/For%20You/MemoryDetailScreen.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:photo_manager/photo_manager.dart';

class LikedMemoriesScreen extends StatelessWidget {
  final List<MemoryGroup> memories;

  const LikedMemoriesScreen({
    super.key,
    required this.memories,
  });

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

  String _dateText(DateTime date) {
    return '${_monthName(date.month)} ${date.year}';
  }

  Map<String, List<MemoryGroup>> _groupByMonth() {
    final Map<String, List<MemoryGroup>> grouped = {};

    for (final MemoryGroup memory in memories) {
      final String key =
          '${memory.date.year}-'
          '${memory.date.month.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(
        key,
            () => <MemoryGroup>[],
      ).add(memory);
    }

    final List<String> keys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final Map<String, List<MemoryGroup>> sorted = {};

    for (final String key in keys) {
      final List<MemoryGroup> monthMemories =
      List<MemoryGroup>.from(grouped[key]!);

      monthMemories.sort(
            (a, b) => b.date.compareTo(a.date),
      );

      sorted[key] = monthMemories;
    }

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final ForYouController controller =
    Get.find<ForYouController>();

    return Obx(() {
      final List<MemoryGroup> likedMemories =
      controller.memories.where((memory) {
        return controller.isMemoryLiked(memory);
      }).toList();

      final Map<String, List<MemoryGroup>> grouped =
      _groupByMonthFromList(likedMemories);

      return Scaffold(
        backgroundColor: Colors.white,

        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,

          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () {
              Get.back();
            },
          ),
          title: Text(
            'Liked Memories',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

        ),

        body: likedMemories.isEmpty
            ? const Center(
          child: Text(
            'No liked memories',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            30,
          ),
          itemCount: grouped.length,
          itemBuilder: (context, monthIndex) {
            final String monthKey =
            grouped.keys.elementAt(monthIndex);

            final List<MemoryGroup> monthMemories =
            grouped[monthKey]!;

            if (monthMemories.isEmpty) {
              return const SizedBox.shrink();
            }

            final DateTime monthDate =
                monthMemories.first.date;

            return Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: 2,
                    right: 2,
                    bottom: 12,
                    top: monthIndex == 0 ? 0 : 14,
                  ),
                  child: Text(
                    '${_monthName(monthDate.month)} '
                        '${monthDate.year}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                ...monthMemories.map(
                      (MemoryGroup memory) {
                    if (memory.assets.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return _LikedMemoryCard(
                      memory: memory,
                      dateText:
                      _dateText(memory.date),
                      controller: controller,
                      onTap: () {
                        Get.to(
                              () => MemoryDetailScreen(
                            title: memory.title,
                            date: _dateText(
                              memory.date,
                            ),
                            assets: memory.assets,
                            initialIndex: 0,

                            // Important:
                            // liked memories hi pass
                            memories: likedMemories,

                            currentMemory: memory,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      );
    });
  }

  Map<String, List<MemoryGroup>>
  _groupByMonthFromList(
      List<MemoryGroup> list,
      ) {
    final Map<String, List<MemoryGroup>> grouped = {};

    for (final MemoryGroup memory in list) {
      final String key =
          '${memory.date.year}-'
          '${memory.date.month.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(
        key,
            () => <MemoryGroup>[],
      ).add(memory);
    }

    final List<String> keys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final Map<String, List<MemoryGroup>> sorted = {};

    for (final String key in keys) {
      final List<MemoryGroup> items =
      List<MemoryGroup>.from(grouped[key]!);

      items.sort(
            (a, b) => b.date.compareTo(a.date),
      );

      sorted[key] = items;
    }

    return sorted;
  }
}
class _LikedMemoryCard extends StatelessWidget {
  final MemoryGroup memory;
  final String dateText;
  final VoidCallback onTap;
  final ForYouController controller;

  const _LikedMemoryCard({
    required this.memory,
    required this.dateText,
    required this.onTap,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final AssetEntity cover = _getMemoryCover(memory);
    final String displayName = _getMemoryName(memory);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 255,
        margin: const EdgeInsets.only(
          bottom: 14,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade200,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: cover.thumbnailDataWithSize(
                const ThumbnailSize(
                  1000,
                  1000,
                ),
              ),
              builder: (
                  context,
                  snapshot,
                  ) {
                if (!snapshot.hasData) {
                  return Container(
                    color: Colors.grey.shade300,
                  );
                }

                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),

            // Bottom gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.88),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom information
            Positioned(
              left: 8,
              right: 8,
              bottom: 15,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 4,
                  top: 8,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.30),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                             fontFamily: FontFamily.robotoBold
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            displayName,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                                fontFamily: FontFamily.robotoRegular

                            ),
                          ),
                        ],
                      ),
                    ),

                    // LIKE
                    IconButton(
                      onPressed: () {
                        controller.toggleMemoryLike(
                          memory,
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints:
                      const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _showMemoryMenu(context, memory);
                      },
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  AssetEntity _getMemoryCover(MemoryGroup memory) {
    if (memory.assets.isEmpty) {
      throw Exception('Memory has no assets');
    }

    final Map<String, dynamic> savedCovers =
    Map<String, dynamic>.from(
      GetStorageData.readObject(
        GetStorageData.memoryCovers,
      ) ??
          {},
    );

    final String memoryKey =
        memory.assets.first.id;

    final String? coverId =
    savedCovers[memoryKey]?.toString();

    if (coverId != null) {
      for (final AssetEntity asset in memory.assets) {
        if (asset.id == coverId) {
          return asset;
        }
      }
    }

    return memory.assets.first;
  }
  String _getMemoryName(MemoryGroup memory) {
    if (memory.assets.isEmpty) {
      return memory.title;
    }

    final Map<String, dynamic> savedNames =
    Map<String, dynamic>.from(
      GetStorageData.readObject(
        GetStorageData.memoryNames,
      ) ??
          {},
    );

    final String memoryKey =
        memory.assets.first.id;

    final String? savedName =
    savedNames[memoryKey]?.toString();

    if (savedName != null && savedName.isNotEmpty) {
      return savedName;
    }

    return memory.title;
  }
  void _showMemoryMenu(BuildContext context, MemoryGroup memory) {
    final RenderBox button = context.findRenderObject() as RenderBox;

    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final Size buttonSize = button.size;

    const double menuWidth = 155;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(
        buttonPosition.dx + buttonSize.width - menuWidth,
        buttonPosition.dy + buttonSize.height,
        menuWidth,
        0,
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(minWidth: 155, maxWidth: 155),
      items: [
        PopupMenuItem<String>(
          value: 'share',
          height: 42,
          child: const Text(
            'Share',
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ),

        PopupMenuItem<String>(
          value: 'rename',
          height: 42,
          child: const Text(
            'Rename',
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ),

        PopupMenuItem<String>(
          value: 'cover',
          height: 42,
          child: const Text(
            'Change Cover',
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ),

        PopupMenuItem<String>(
          value: 'delete',
          height: 42,
          child: const Text(
            'Delete Memory',
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      if (value == 'share') {
        Get.to(
              () => MemoryShareScreen(title: memory.title, assets: memory.assets),
        );
      } else if (value == 'rename') {
        _showRenameDialog(context, memory);
      } else if (value == 'cover') {
        final result = await Get.to(
              () => MemoryShareScreen(
            title: memory.title,
            assets: memory.assets,
            isChangeCover: true,
          ),
        );

        if (result == true) {
          controller.memories.refresh();
        }
      } else if (value == 'delete') {
        _showDeleteMemoryDialog(context, memory);

      }
    });
  }

  void _showRenameDialog(BuildContext context, MemoryGroup memory) {
    final TextEditingController nameController = TextEditingController(
      text: memory.title,
    );

    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                'Rename',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: true,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Enter memory name',
                  hintStyle: const TextStyle(
                    color: Colors.black45,
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: Colors.black54),
                  ),
                ),
                onSubmitted: (_) {
                  _renameMemory(nameController, memory);
                },
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();

                          Get.back();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextButton(
                        onPressed: () {
                          _renameMemory(nameController, memory);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Rename',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
  void _renameMemory(
      TextEditingController nameController,
      MemoryGroup memory,
      ) async {
    final String newName = nameController.text.trim();

    if (newName.isEmpty) {
      return;
    }
    memory.title = newName;
    final Map<String, dynamic> savedNames = Map<String, dynamic>.from(
      GetStorageData.readObject(GetStorageData.memoryNames) ?? {},
    );
    final String memoryKey = memory.assets.isNotEmpty
        ? memory.assets.first.id
        : memory.date.millisecondsSinceEpoch.toString();
    savedNames[memoryKey] = newName;
    await GetStorageData.saveObject(GetStorageData.memoryNames, savedNames);
    controller.memories.refresh();
    FocusManager.instance.primaryFocus?.unfocus();
    Get.back();
  }

  void _showDeleteMemoryDialog(
      BuildContext context,
      MemoryGroup memory,
      ) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // =========================
              // TITLE
              // =========================
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Do you want to delete this memory?',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =========================
              // BUTTONS
              // =========================
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextButton(
                        onPressed: () {
                          _deleteMemory(memory);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xff29262A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
  Future<void> _deleteMemory(
      MemoryGroup memory,
      ) async {
    if (memory.assets.isEmpty) {
      Get.back();
      return;
    }

    final String memoryKey = memory.assets.first.id;
    final List<dynamic> savedDeleted =
        GetStorageData.readObject(
          GetStorageData.deletedMemories,
        ) ??
            [];

    final Set<String> deletedIds =
    savedDeleted.map((e) => e.toString()).toSet();

    // Is memory ko deleted mark karo
    deletedIds.add(memoryKey);

    // Permanently save
    await GetStorageData.saveObject(
      GetStorageData.deletedMemories,
      deletedIds.toList(),
    );

    // Rename data bhi remove kar do
    final Map<String, dynamic> savedNames =
    Map<String, dynamic>.from(
      GetStorageData.readObject(
        GetStorageData.memoryNames,
      ) ??
          {},
    );

    savedNames.remove(memoryKey);

    await GetStorageData.saveObject(
      GetStorageData.memoryNames,
      savedNames,
    );

    // Current screen se immediately remove
    controller.memories.remove(memory);
    controller.memories.refresh();

    // Dialog close
    Get.back();
  }
}