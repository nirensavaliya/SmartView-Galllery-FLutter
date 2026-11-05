import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/PlaceScreen/PlacePhotosScreen.dart';
import 'package:gallery_photos/View/Screen/PlaceScreen/controller/PlacesController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class PlacesScreen extends StatelessWidget {
  PlacesScreen({super.key});

  final PlacesController controller = Get.find<PlacesController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InnerChrome.page,

      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: Get.back,

          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 19,
            color: InnerChrome.ink,
          ),
        ),

        title: Text(
          'Places',

          style: TextStyle(
            color: InnerChrome.ink,
            fontSize: 19,
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: Obx(() {
        if (controller.places.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.refreshPlaces,

            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),

              children: [
                SizedBox(height: 220),

                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 50,
                        color: InnerChrome.muted,
                      ),

                      SizedBox(height: 12),

                      Text(
                        'No places found',

                        style: TextStyle(
                          color: InnerChrome.ink,
                          fontSize: 15,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        'Photos with location will appear here',

                        style: TextStyle(
                          color: InnerChrome.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshPlaces,

          child: GestureDetector(
            behavior: HitTestBehavior.translucent,

onScaleStart: (details) {
              controller.onGridScaleStart();
            },

onScaleUpdate: (details) {
              controller.onGridScaleUpdate(
                details.scale,
              );
            },

            child: GridView.builder(
              physics:
              const AlwaysScrollableScrollPhysics(),

              padding:
              const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                30,
              ),

              gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                controller.gridColumns.value,

                crossAxisSpacing: 10,

                mainAxisSpacing: 12,

                childAspectRatio: 0.88,
              ),

              itemCount:
              controller.places.length,

              itemBuilder:
                  (context, index) {
                final PlaceGroup place =
                controller.places[index];

                if (place.assets.isEmpty) {
                  return const SizedBox.shrink();
                }

                return _PlaceCard(
                  place: place,

                  onTap: () {
                    Get.to(
                          () => PlacePhotosScreen(
                        place: place,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

class _PlacesPinchGrid extends StatefulWidget {
  final PlacesController controller;

  const _PlacesPinchGrid({required this.controller});

  @override
  State<_PlacesPinchGrid> createState() => _PlacesPinchGridState();
}

class _PlacesPinchGridState extends State<_PlacesPinchGrid> {
  late final ScaleGestureRecognizer _scaleGestureRecognizer;

  double _startScale = 1.0;

  bool _changedThisGesture = false;

  @override
  void initState() {
    super.initState();

    _scaleGestureRecognizer = ScaleGestureRecognizer();

    _scaleGestureRecognizer.onStart = (details) {
      _startScale = 1.0;
      _changedThisGesture = false;
    };

    _scaleGestureRecognizer.onUpdate = (details) {
      if (_changedThisGesture) {
        return;
      }

      final double scale = details.scale;

if (scale > 1.15) {
        _changedThisGesture = true;

        widget.controller.increaseGridColumns();

        return;
      }

if (scale < 0.85) {
        _changedThisGesture = true;

        widget.controller.decreaseGridColumns();
      }
    };

    _scaleGestureRecognizer.onEnd = (details) {
      _startScale = 1.0;
      _changedThisGesture = false;
    };
  }

  @override
  void dispose() {
    _scaleGestureRecognizer.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
              () => ScaleGestureRecognizer(),

              (instance) {
                instance.onStart = _scaleGestureRecognizer.onStart;

                instance.onUpdate = _scaleGestureRecognizer.onUpdate;

                instance.onEnd = _scaleGestureRecognizer.onEnd;
              },
            ),
      },

      behavior: HitTestBehavior.opaque,

      child: Obx(() {
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),

          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.controller.gridColumns.value,

            crossAxisSpacing: 10,

            mainAxisSpacing: 12,

            childAspectRatio: 0.88,
          ),

          itemCount: widget.controller.places.length,

          itemBuilder: (context, index) {
            final PlaceGroup place = widget.controller.places[index];

            if (place.assets.isEmpty) {
              return const SizedBox.shrink();
            }

            return _PlaceCard(
              place: place,

              onTap: () {
                Get.to(() => PlacePhotosScreen(place: place));
              },
            );
          },
        );
      }),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PlaceGroup place;
  final VoidCallback onTap;

  const _PlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),

        child: Container(
          color: InnerChrome.card,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Expanded(child: _PlaceThumbnail(asset: place.assets.first)),

              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      place.title,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: InnerChrome.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${place.assets.length} photos',

                      style: TextStyle(
                        color: InnerChrome.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _PlaceThumbnail({required this.asset});

  static final Map<String, Future<Uint8List?>> _cache = {};

  Future<Uint8List?> _loadImage() {
    final String id = asset.id;

    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }

    final Future<Uint8List?> future = asset.thumbnailDataWithSize(
      const ThumbnailSize(600, 600),
    );

    _cache[id] = future;

    return future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _loadImage(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ShimmerBox();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            color: InnerChrome.alt,

            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: InnerChrome.muted,
                size: 28,
              ),
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
    );
  }
}

class _PlaceShimmerCard extends StatelessWidget {
  const _PlaceShimmerCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),

      child: Container(
        color: InnerChrome.card,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Expanded(child: _ShimmerBox()),

            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  _ShimmerLine(width: 90, height: 13),

                  const SizedBox(height: 5),

                  _ShimmerLine(width: 55, height: 9),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
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
        return ShaderMask(
          shaderCallback: (rect) {
            final double x = -1.0 + (_controller.value * 3.0);

            return LinearGradient(
              begin: Alignment.centerLeft,

              end: Alignment.centerRight,

              stops: const [0.0, 0.5, 1.0],

              colors: [
                AppColors.surface(InnerChrome.mapBlock),
                AppColors.surface(InnerChrome.alt),
                AppColors.surface(InnerChrome.mapBlock),
              ],
            ).createShader(
              Rect.fromLTWH(rect.width * x, 0, rect.width * 2, rect.height),
            );
          },

          blendMode: BlendMode.srcATop,

          child: Container(color: InnerChrome.alt),
        );
      },
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height, child: const _ShimmerBox());
  }
}
