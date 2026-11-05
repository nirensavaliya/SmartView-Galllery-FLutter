import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/Controller/CleanerController.dart';
import 'package:gallery_photos/View/Screen/For%20You/MemoryPhotosScreen.dart';
import 'package:gallery_photos/View/Screen/For%20You/PeopleScreen.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/FaceGroupController.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/PlaceScreen/PlacesScreen.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/RecycleBinView.dart';
import 'package:gallery_photos/View/Screen/UtilityMedia/UtilityMediaScreen.dart';
import 'package:gallery_photos/View/Screen/UtilityMedia/controller/UtilityMediaController.dart';
import 'package:gallery_photos/View/Setting/SettingScreen.dart';
import 'package:gallery_photos/View/Utils/App_Routes.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class _Fy {
  static const bg = Color(0xFF05070B);
  static const card = Color(0xFF0E131B);
  static const cardAlt = Color(0xFF121925);
  static const border = Color(0xFF1E2633);
  static const textPrimary = Color(0xFFF4F6FA);
  static const textSecondary = Color(0xFF8A94A8);
  static const amber = Color(0xFFF5B544);
  static const violet = Color(0xFFA78BFA);
  static const rose = Color(0xFFFB7185);
  static const green = Color(0xFF34D399);
  static const blue = Color(0xFF4C9BFF);

  static const pageLight = Color(0xFFF6F7F9);
  static const inkLight = Color(0xFF111827);
  static const mutedLight = Color(0xFF6B7280);
  static const lineLight = Color(0xFFE6EAEF);
  static const washLight = Color(0xFFE8EDF2);
  static const linkLight = Color(0xFFE82868);

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color page(BuildContext context) => isLight(context) ? pageLight : bg;

  static Color ink(BuildContext context) =>
      isLight(context) ? inkLight : textPrimary;

  static Color muted(BuildContext context) =>
      isLight(context) ? mutedLight : textSecondary;

  static Color surface(BuildContext context) =>
      isLight(context) ? Colors.white : card;

  static Color surfaceAlt(BuildContext context) =>
      isLight(context) ? const Color(0xFFF3F5F8) : cardAlt;

  static Color line(BuildContext context) =>
      isLight(context) ? lineLight : border;

  static Color wash(BuildContext context) =>
      isLight(context) ? washLight : cardAlt;

  static List<BoxShadow> lift(BuildContext context) => isLight(context)
      ? const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ]
      : const [];

  static Color pastel(Color color) {
    if (color == amber) return const Color(0xFFFFF1D4);
    if (color == violet) return const Color(0xFFF1E9FF);
    if (color == rose) return const Color(0xFFFFE6EC);
    if (color == blue) return const Color(0xFFE7F1FF);
    if (color == green) return const Color(0xFFE5F8F0);
    return Color.alphaBlend(color.withValues(alpha: 0.16), Colors.white);
  }
}

class ForYouScreen extends StatelessWidget {
  ForYouScreen({super.key});

  final ForYouController controller = Get.put(
    ForYouController(),
    permanent: false,
  );
  final FaceGroupController faceController = Get.put(
    FaceGroupController(),
    permanent: false,
  );
  final CleanerController cleanerController =
      Get.isRegistered<CleanerController>()
      ? Get.find<CleanerController>()
      : Get.put(CleanerController());

  void _openUtility(UtilityMediaType type) {
    Get.to(() => UtilityMediaScreen(mediaType: type))?.then((_) {
      controller.loadUtilityCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool light = _Fy.isLight(context);
    return Scaffold(
      backgroundColor: _Fy.page(context),
      appBar: AppBar(
        backgroundColor: _Fy.page(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Text(
          'For You',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: _Fy.ink(context),
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: controller.openCamera,
            child: const _FyCircleIcon(icon: Icons.photo_camera_outlined),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            color: light ? Colors.white : _Fy.cardAlt,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const _FyCircleIcon(icon: Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == "recycle") {
                Get.to(() => RecycleBinScreen());
              } else if (value == "setting") {
                Get.to(() => SettingsScreen());
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: "recycle",
                  child: Text(
                    "Recycle Bin",
                    style: TextStyle(
                      fontSize: 15,
                      color: _Fy.ink(context),
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: "setting",
                  child: Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 15,
                      color: _Fy.ink(context),
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: SplashLoader());
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.media.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 50,
                    color: _Fy.muted(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Plus Jakarta Sans',
                      color: _Fy.muted(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: controller.loadForYouMedia,
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Plus Jakarta Sans',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
              children: [
                SizedBox(height: 250),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 55,
                        color: _Fy.muted(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No photos or videos found',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Plus Jakarta Sans',
                          color: _Fy.muted(context),
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
          onRefresh: controller.refreshForYou,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TopActionCard(
                      title: 'Cleaner',
                      icon: Icons.cleaning_services_rounded,
                      color: _Fy.amber,
                      onTap: () {
                        Get.toNamed(AppRoutes.cleanerScreen);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TopActionCard(
                      title: 'Private',
                      icon: Icons.visibility_off_rounded,
                      color: _Fy.violet,
                      onTap: controller.openPrivate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TopActionCard(
                      title: 'Trash Bin',
                      icon: Icons.delete_rounded,
                      color: _Fy.rose,
                      onTap: () {
                        Get.toNamed(AppRoutes.recycleBinView);
                      },
                    ),
                  ),
                ],
              ),
              Obx(() {
                final bool scanning = faceController.isScanning.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _SmartLibraryBanner(
                    scanning: scanning,
                    onOptimize: () {
                      if (faceController.needsWholeScan) {
                        faceController.scanWholeGallery();
                      }
                      controller.refreshForYou();
                    },
                  ),
                );
              }),
              Obx(() {
                final hasPeople = faceController.visiblePeople.isNotEmpty;
                if (!hasPeople) {
                  return SizedBox.shrink();
                }
                return Column(
                  children: [
                    _PeopleSection(
                      controller: faceController,
                      assets: controller.media.toList(),
                    ),
                    // SizedBox(height: 10),
                  ],
                );
              }),
              Obx(() {
                final bool hasMemories = controller.memories.any(
                  (memory) => memory.assets.isNotEmpty,
                );
                final bool hasPlaces = controller.places.any(
                  (place) => place.assets.isNotEmpty,
                );
                if (!hasMemories && !hasPlaces) {
                  return const SizedBox.shrink();
                }

                final List<Widget> cards = [];
                if (hasMemories) {
                  cards.add(
                    Expanded(
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
                if (hasPlaces) {
                  if (cards.isNotEmpty) {
                    cards.add(const SizedBox(width: 12));
                  }
                  cards.add(
                    Expanded(
                      child: _PlacesCard(
                        places: List<PlaceGroup>.from(controller.places),
                        onTap: () {
                          Get.to(() => PlacesScreen());
                        },
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 30, 0, 14),
                      child: Text(
                        'Memories & Places',
                        style: TextStyle(
                          fontSize: 19,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: _Fy.ink(context),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: Row(children: cards),
                    ),
                  ],
                );
              }              ),
              const SizedBox(height: 16),
              Obx(
                () => _DuplicatePhotosCard(
                  count: cleanerController.duplicateCount.value,
                  onTap: cleanerController.openDuplicates,
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => _SimilarPhotosCard(
                  count: cleanerController.similarCount.value,
                  onTap: cleanerController.openSimilarPhotos,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 30, 0, 14),
                child: Text(
                  'Utilities',
                  style: TextStyle(
                    color: _Fy.ink(context),
                    fontSize: 19,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Obx(
                () => _UtilitiesCard(
                  videosCount: controller.videosCount.value,
                  screenshotsCount: controller.screenshotsCount.value,
                  favoritesCount: controller.favoritesCount.value,
                  gifsLivePhotosCount:
                      controller.gifsCount.value +
                      controller.livePhotosCount.value,
                  onVideosTap: () => _openUtility(UtilityMediaType.videos),
                  onScreenshotsTap: () =>
                      _openUtility(UtilityMediaType.screenshots),
                  onFavoritesTap: () =>
                      _openUtility(UtilityMediaType.favorites),
                  onGifsTap: () => _openUtility(UtilityMediaType.gifs),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SmartLibraryBanner extends StatelessWidget {
  final bool scanning;
  final VoidCallback onOptimize;

  const _SmartLibraryBanner({
    required this.scanning,
    required this.onOptimize,
  });

  @override
  Widget build(BuildContext context) {
    final bool light = _Fy.isLight(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171E2C), Color(0xFF10151F)],
        ),
        border: Border.all(color: light ? const Color(0xFF1A2230) : _Fy.border),
        boxShadow: light
            ? const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Library Sync',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: _Fy.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Auto-organizing trips, faces & clips',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _Fy.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: scanning ? null : onOptimize,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6A9A), Color(0xFFFF3D78)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D7E).withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scanning) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    scanning ? 'Syncing' : 'Optimize',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleSection extends StatelessWidget {
  final FaceGroupController controller;
  final List<AssetEntity> assets;

  const _PeopleSection({required this.controller, required this.assets});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.needsWholeScan) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.needsWholeScan) {
            controller.scanWholeGallery();
          }
        });
      }

      final people = controller.visiblePeople;
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'People',
                  style: TextStyle(
                    fontSize: 19,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: _Fy.ink(context),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Get.to(() => PeopleScreen(controller: controller));
                  },
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      color: _Fy.isLight(context) ? _Fy.linkLight : _Fy.blue,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            SizedBox(
              height: 125,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(right: 16),
                itemCount: people.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(width: 16);
                },
                itemBuilder: (context, index) {
                  final FacePerson person = people[index];
                  return GestureDetector(
                    onTap: () {
                      Get.to(
                        () => PeopleScreen(
                          controller: controller,
                          selectedPerson: person,
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 78,
                      child: Column(
                        children: [

                          ClipOval(
                            child: SizedBox(
                              width: 76,
                              height: 76,
                              child: FutureBuilder<Uint8List?>(
                                future: controller.getCover(person),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(
                                      color: _Fy.wash(context),
                                      child: Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _Fy.muted(context),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError ||
                                      snapshot.data == null) {
                                    return ColoredBox(
                                      color: _Fy.wash(context),
                                      child: Icon(
                                        Icons.person,
                                        size: 35,
                                        color: _Fy.muted(context),
                                      ),
                                    );
                                  }

                                  return Image.memory(
                                    snapshot.data!,
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 7),
                          Column(
                            children: [
                              Text(
                                person.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: _Fy.ink(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                person.assetIds.length == 1
                                    ? '1 photo'
                                    : '${person.assetIds.length} photos',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: _Fy.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _FaceLocationGroupingCard extends StatelessWidget {
  final int faceCount;
  final int locationCount;
  final VoidCallback onTap;

  const _FaceLocationGroupingCard({
    required this.faceCount,
    required this.locationCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF3A414B) : const Color(0xFFE5E9F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF263D58)
                      : const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded,
                  color: Color(0xFF3678E8),
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Face & Location Grouping',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Group photos by faces, places & dates',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        _GroupingBadge(
                          icon: Icons.face_rounded,
                          text: '$faceCount faces',
                        ),
                        const SizedBox(width: 7),
                        _GroupingBadge(
                          icon: Icons.location_on_rounded,
                          text: '$locationCount places',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupingBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GroupingBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicatePhotosCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _DuplicatePhotosCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FyInfoCard(
      icon: Icons.content_copy_rounded,
      color: _Fy.green,
      title: 'Duplicate Photos',
      subtitle: 'Find repeated photos and free up space',
      badge: count > 0 ? '$count found' : 'No duplicates',
      onTap: onTap,
    );
  }
}

class _FyInfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _FyInfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool light = _Fy.isLight(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Fy.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _Fy.line(context)),
          boxShadow: _Fy.lift(context),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: light ? _Fy.pastel(color) : color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: light
                    ? null
                    : Border.all(color: color.withValues(alpha: 0.32)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      color: _Fy.ink(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'Plus Jakarta Sans',
                      color: _Fy.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _Fy.muted(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SimilarPhotosCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _SimilarPhotosCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FyInfoCard(
      icon: Icons.auto_awesome_rounded,
      color: _Fy.violet,
      title: 'Similar Photos',
      subtitle: 'Find photos that look alike',
      badge: count > 0 ? '$count found' : 'No similar photos',
      onTap: onTap,
    );
  }
}

class _UtilitiesCard extends StatelessWidget {
  final int videosCount;
  final int screenshotsCount;
  final int favoritesCount;
  final int gifsLivePhotosCount;

  final VoidCallback onVideosTap;
  final VoidCallback onScreenshotsTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onGifsTap;

  const _UtilitiesCard({
    required this.videosCount,
    required this.screenshotsCount,
    required this.favoritesCount,
    required this.gifsLivePhotosCount,
    required this.onVideosTap,
    required this.onScreenshotsTap,
    required this.onFavoritesTap,
    required this.onGifsTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool light = _Fy.isLight(context);
    return Container(
      decoration: BoxDecoration(
        color: _Fy.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Fy.line(context)),
        boxShadow: _Fy.lift(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _UtilityItem(
            title: 'Videos',
            subtitle: '4K & Slow-mo captures',
            count: videosCount.toString(),
            icon: Icons.play_arrow_rounded,
            iconColor: _Fy.blue,
            onTap: onVideosTap,
          ),
          Divider(height: 1, color: light ? _Fy.lineLight : _Fy.border),
          _UtilityItem(
            title: 'Screenshots',
            subtitle: 'Recent receipts & UI snaps',
            count: screenshotsCount.toString(),
            icon: Icons.phone_android_rounded,
            iconColor: _Fy.violet,
            onTap: onScreenshotsTap,
          ),
          Divider(height: 1, color: light ? _Fy.lineLight : _Fy.border),
          _UtilityItem(
            title: 'Favorites',
            subtitle: 'Quick starred moments',
            count: favoritesCount.toString(),
            icon: Icons.favorite_rounded,
            iconColor: _Fy.rose,
            onTap: onFavoritesTap,
          ),
          Divider(height: 1, color: light ? _Fy.lineLight : _Fy.border),
          _UtilityItem(
            title: 'GIFs & Live Photos',
            subtitle: 'Motion animated clips',
            count: gifsLivePhotosCount.toString(),
            icon: Icons.gif_box_rounded,
            iconColor: _Fy.green,
            onTap: onGifsTap,
          ),
        ],
      ),
    );
  }
}

class _UtilityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String count;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _UtilityItem({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool light = _Fy.isLight(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: light
                    ? _Fy.pastel(iconColor)
                    : iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: light
                    ? null
                    : Border.all(color: iconColor.withValues(alpha: 0.32)),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      color: _Fy.ink(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'Plus Jakarta Sans',
                      color: _Fy.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              count,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: light ? iconColor : _Fy.textSecondary,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: _Fy.muted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TopActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool light = _Fy.isLight(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 116,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: light ? _Fy.pastel(color) : null,
          gradient: light
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.24),
                    color.withValues(alpha: 0.04),
                  ],
                ),
          border: Border.all(
            color: light
                ? color.withValues(alpha: 0.16)
                : color.withValues(alpha: 0.38),
          ),
          boxShadow: light
              ? _Fy.lift(context)
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: light
                    ? Colors.white.withValues(alpha: 0.72)
                    : color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: light
                    ? null
                    : Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      color: _Fy.ink(context),
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 14, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FyCircleIcon extends StatelessWidget {
  final IconData icon;

  const _FyCircleIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final bool light = _Fy.isLight(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: light ? Colors.white : _Fy.cardAlt,
        shape: BoxShape.circle,
        border: Border.all(color: light ? _Fy.lineLight : _Fy.border),
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
      child: Icon(icon, size: 20, color: light ? _Fy.inkLight : _Fy.textPrimary),
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

  final RxInt _currentIndex = 0.obs;

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

      int nextIndex = _currentIndex.value + 1;

      if (nextIndex >= widget.memories.length) {
        nextIndex = 0;
      }

      _currentIndex.value = nextIndex;
    });
  }

  @override
  void didUpdateWidget(covariant _ChangingMemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.memories.length != oldWidget.memories.length) {
      if (_currentIndex.value >= widget.memories.length) {
        _currentIndex.value = 0;
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
    return Obx(() {
      final int currentIndex = _currentIndex.value;

      if (widget.memories.isEmpty) {
        return const SizedBox.shrink();
      }

      final MemoryGroup memory =
          widget.memories[currentIndex % widget.memories.length];

      if (memory.assets.isEmpty) {
        return const SizedBox.shrink();
      }

      final AssetEntity coverAsset = _getMemoryCover(memory);

      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _Fy.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Fy.line(context)),
            boxShadow: _Fy.lift(context),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: SizedBox.expand(
                        key: ValueKey(coverAsset.id),
                        child: _PhotoThumbnail(asset: coverAsset),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: _Fy.surfaceAlt(context),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _Fy.ink(context),
                        fontSize: 16,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.memories.length} memories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: _Fy.muted(context),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  AssetEntity _getMemoryCover(MemoryGroup memory) {
    if (memory.assets.isEmpty) {
      throw Exception('Memory has no assets');
    }

    final Map<String, dynamic> savedCovers = Map<String, dynamic>.from(
      GetStorageData.readObject(GetStorageData.memoryCovers) ?? {},
    );

    final String memoryKey = memory.assets.first.id;

    final String? coverId = savedCovers[memoryKey]?.toString();

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

  const _PhotoThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(500, 500)),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ColoredBox(color: _Fy.wash(context));
        }

        if (snapshot.hasError || snapshot.data == null) {
          return ColoredBox(
            color: _Fy.wash(context),
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: _Fy.muted(context),
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

class _PlacesCard extends StatefulWidget {
  final List<PlaceGroup> places;
  final VoidCallback onTap;

  const _PlacesCard({required this.places, required this.onTap});

  @override
  State<_PlacesCard> createState() => _PlacesCardState();
}

class _PlacesCardState extends State<_PlacesCard> {
  Timer? _timer;

  final RxInt _currentIndex = 0.obs;

  @override
  void initState() {
    super.initState();

    _startChangingPlaces();
  }

  void _startChangingPlaces() {
    _timer?.cancel();

    if (widget.places.length <= 1) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.places.isEmpty) {
        return;
      }

      int nextIndex = _currentIndex.value + 1;

      if (nextIndex >= widget.places.length) {
        nextIndex = 0;
      }

      _currentIndex.value = nextIndex;
    });
  }

  @override
  void didUpdateWidget(covariant _PlacesCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.places.length != oldWidget.places.length) {
      if (_currentIndex.value >= widget.places.length) {
        _currentIndex.value = 0;
      }

      _startChangingPlaces();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int currentIndex = _currentIndex.value;

      if (widget.places.isEmpty) {
        return const SizedBox.shrink();
      }

      final PlaceGroup place =
          widget.places[currentIndex % widget.places.length];

      if (place.assets.isEmpty) {
        return const SizedBox.shrink();
      }

      final AssetEntity coverAsset = place.assets.first;

      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _Fy.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Fy.line(context)),
            boxShadow: _Fy.lift(context),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: SizedBox.expand(
                        key: ValueKey(coverAsset.id),
                        child: _PlacePreviewImage(asset: coverAsset),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: _Fy.surfaceAlt(context),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: _Fy.ink(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${place.assets.length} photos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: _Fy.muted(context),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _PlacePreviewImage extends StatelessWidget {
  final AssetEntity asset;

  const _PlacePreviewImage({required this.asset});

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
          return const _PlacePreviewShimmer();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return ColoredBox(
            color: _Fy.wash(context),
            child: Center(
              child: Icon(
                Icons.location_on_outlined,
                color: _Fy.muted(context),
                size: 32,
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

class _PlacePreviewShimmer extends StatefulWidget {
  const _PlacePreviewShimmer();

  @override
  State<_PlacePreviewShimmer> createState() => _PlacePreviewShimmerState();
}

class _PlacePreviewShimmerState extends State<_PlacePreviewShimmer>
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
            final double x = -1 + (_controller.value * 3);

            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.surface(Colors.grey.shade300),
                AppColors.surface(Colors.grey.shade100),
                AppColors.surface(Colors.grey.shade300),
              ],
            ).createShader(
              Rect.fromLTWH(rect.width * x, 0, rect.width * 2, rect.height),
            );
          },

          blendMode: BlendMode.srcATop,

          child: Container(color: AppColors.surface(Colors.grey.shade300)),
        );
      },
    );
  }
}
