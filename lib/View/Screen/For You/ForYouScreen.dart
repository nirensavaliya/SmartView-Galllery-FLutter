import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/For%20You/MemoryPhotosScreen.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Utils/App_Routes.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

class ForYouScreen extends StatelessWidget {
  ForYouScreen({super.key});

  final ForYouController controller = Get.put(
    ForYouController(),
    permanent: false,
  );

  String _placeTitle(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(3)}, '
        '${longitude.toStringAsFixed(3)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'For You',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.black),
            onPressed: controller.openCamera,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {},
            itemBuilder: (context) {
              return const [
                PopupMenuItem(value: 'settings', child: Text('Settings')),
              ];
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.media.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: controller.loadForYouMedia,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.media.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.loadForYouMedia,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 250),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 55,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No photos or videos found',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshForYou,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 30),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: _TopActionCard(
                        title: 'Cleaner',
                        icon: Icons.cleaning_services_rounded,
                        iconColor: const Color(0xFF3159D9),
                        backgroundColor: const Color(0xFFE3EBFF),
                        onTap: () {
                        Get.toNamed(AppRoutes.cleanerScreen);
                        },
                      ),
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: _TopActionCard(
                        title: 'Private',
                        icon: Icons.visibility_off_rounded,
                        iconColor: const Color(0xFF8B3DD1),
                        backgroundColor: const Color(0xFFF0E1FA),
                        onTap: () {
                        },
                      ),
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: _TopActionCard(
                        title: 'Trash Bin',
                        icon: Icons.delete_rounded,
                        iconColor: const Color(0xFFFF7518),
                        backgroundColor: const Color(0xFFFFEED2),
                        onTap: () {
                          Get.toNamed(AppRoutes.recycleBinView);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 15,),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Memories & Places',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 14),
              SizedBox(
                height: 165,
                child: Obx(() {
                  final List<Widget> cards = [];
                  if (controller.memories.isNotEmpty) {
                    cards.add(
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _ChangingMemoryCard(
                          memories: List<MemoryGroup>.from(controller.memories),
                          onTap: () {
                            Get.to(
                              () => MemoryPhotosScreen(
                                title: 'Memories',
                                memories: List<MemoryGroup>.from(
                                  controller.memories,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }

                  if (cards.isEmpty) {
                    return const Center(
                      child: Text(
                        'Memories and places will appear here',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    );
                  }

                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: cards,
                  );
                }),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TopActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _TopActionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 23,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontFamily: FontFamily.robotoSemiBold,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _ChangingMemoryCard extends StatefulWidget {
  final List<MemoryGroup> memories;
  final VoidCallback onTap;

  const _ChangingMemoryCard({required this.memories, required this.onTap});

  @override
  State<_ChangingMemoryCard> createState() => _ChangingMemoryCardState();
}

class _ChangingMemoryCardState extends State<_ChangingMemoryCard> {
  Timer? _timer;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _startChangingMemory();
  }

  void _startChangingMemory() {
    _timer?.cancel();

    if (widget.memories.length <= 1) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.memories.isEmpty) {
        return;
      }

      setState(() {
        _currentIndex++;

        if (_currentIndex >= widget.memories.length) {
          _currentIndex = 0;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant _ChangingMemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.memories.length != oldWidget.memories.length) {
      if (_currentIndex >= widget.memories.length) {
        _currentIndex = 0;
      }

      _startChangingMemory();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.memories.isEmpty) {
      return const SizedBox.shrink();
    }

    final MemoryGroup memory =
        widget.memories[_currentIndex % widget.memories.length];

    if (memory.assets.isEmpty) {
      return const SizedBox.shrink();
    }

    final AssetEntity coverAsset = _getMemoryCover(memory);

    return GestureDetector(
      onTap: widget.onTap,

      child: SizedBox(
        // =============================================================
        // SQUARE MEMORY CARD
        // =============================================================
        width: 165,
        height: 165,

        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),

          child: Stack(
            fit: StackFit.expand,

            children: [
              // =======================================================
              // FULL IMAGE
              // =======================================================
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,

                child: SizedBox.expand(
                  key: ValueKey(coverAsset.id),
                  child: _PhotoThumbnail(asset: coverAsset),
                ),
              ),

              // =======================================================
              // GRADIENT
              // =======================================================
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.82),
                      ],
                    ),
                  ),
                ),
              ),

              // =======================================================
              // TEXT
              // =======================================================
              Positioned(
                left: 12,
                right: 10,
                bottom: 12,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Memories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${widget.memories.length} memories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // =======================================================
              // 30/67 INDICATOR REMOVED
              // =======================================================
            ],
          ),
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

    final String memoryKey = memory.assets.first.id;

    final String? coverId =
    savedCovers[memoryKey]?.toString();

    if (coverId != null && coverId.isNotEmpty) {
      for (final AssetEntity asset in memory.assets) {
        if (asset.id == coverId) {
          return asset;
        }
      }
    }

    return memory.assets.first;
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _PhotoThumbnail({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(500, 500)),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.grey.shade200);
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            color: Colors.grey.shade300,

            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          width: double.infinity,
          height: double.infinity,

          // ===========================================================
          // IMAGE FULL SQUARE CARD ME FILL HOGI
          // ===========================================================
          fit: BoxFit.cover,

          gaplessPlayback: true,
        );
      },
    );
  }
}
