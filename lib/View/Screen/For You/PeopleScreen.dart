import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'controller/FaceGroupController.dart';

class PeopleScreen extends StatelessWidget {
  final FaceGroupController controller;
  final FacePerson? selectedPerson;

  const PeopleScreen({
    super.key,
    required this.controller,
    this.selectedPerson,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedPerson != null) {
      return _PersonPhotosScreen(
        controller: controller,
        person: selectedPerson!,
      );
    }
    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const _PeopleBackButton(),
        title: Text(
          'People',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: InnerChrome.ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: Obx(() {
        final List<FacePerson> people = controller.visiblePeople;

        if (people.isEmpty) {
          return Center(
            child: Text(
              controller.isScanning.value
                  ? 'Finding people...'
                  : 'No people found',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: InnerChrome.muted,
                fontSize: 15,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: 0.72,
          ),
          itemCount: people.length,
          itemBuilder: (context, index) {
            final FacePerson person = people[index];

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // preventDuplicates:false is REQUIRED - this grid is itself a
                // PeopleScreen, and GetX silently ignores Get.to() to a route
                // with the same name as the current one.
                Get.to(
                  () => PeopleScreen(
                    controller: controller,
                    selectedPerson: person,
                  ),
                  preventDuplicates: false,
                );
              },
              child: Column(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: FutureBuilder<Uint8List?>(
                        future: controller.getCover(person),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ColoredBox(
                              color: InnerChrome.alt,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: InnerChrome.accent,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError || snapshot.data == null) {
                            return ColoredBox(
                              color: InnerChrome.alt,
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: InnerChrome.muted,
                              ),
                            );
                          }

                          return Image.memory(
                            snapshot.data!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: InnerChrome.ink,
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
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: InnerChrome.muted,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

class _PersonPhotosScreen extends StatefulWidget {
  final FaceGroupController controller;
  final FacePerson person;

  const _PersonPhotosScreen({required this.controller, required this.person});

  @override
  State<_PersonPhotosScreen> createState() => _PersonPhotosScreenState();
}

class _PersonPhotosScreenState extends State<_PersonPhotosScreen> {
  List<AssetEntity> _assets = <AssetEntity>[];
  bool _loading = true;
  int _loadedCount = -1;
  Worker? _worker;

  FaceGroupController get controller => widget.controller;
  FacePerson get person => widget.person;
  late final PhotosController photosController;
  final ScrollController _peopleScrollController =
  ScrollController();

  final RxBool _showScrollControls = false.obs;

  final RxDouble _scrollThumbTop = 100.0.obs;

  Timer? _scrollHideTimer;
  @override
  void initState() {
    super.initState();

    photosController = Get.find<PhotosController>();

    _assets = controller.getAssetsForPerson(person);
    _loading = _assets.isEmpty;
    _loadedCount = _assets.length;

    _reload();

    _worker = debounce(
      controller.people,
          (_) => _reload(),
      time: const Duration(milliseconds: 400),
    );

    _peopleScrollController.addListener(
      _onPeopleScroll,
    );
  }
  void _onPeopleScroll() {
    if (!_peopleScrollController.hasClients) {
      return;
    }

    final position = _peopleScrollController.position;

    final double maxScroll = position.maxScrollExtent;
    final double currentScroll = position.pixels;

    _showScrollControls.value = currentScroll > 20;

    if (maxScroll <= 0) {
      _scrollThumbTop.value = 70;
      return;
    }

    final double progress =
    (currentScroll / maxScroll).clamp(0.0, 1.0);

    final double screenHeight =
        MediaQuery.of(context).size.height;

    const double minTop = 70;
    final double maxTop = screenHeight - 180;

    _scrollThumbTop.value =
        minTop + ((maxTop - minTop) * progress);

    _showScrollControls.value = true;

    _scrollHideTimer?.cancel();

    _scrollHideTimer = Timer(
      const Duration(milliseconds: 1200),
          () {
        if (mounted) {
          _showScrollControls.value = false;
        }
      },
    );
  }
  void _scrollPeopleUp() {
    if (!_peopleScrollController.hasClients) {
      return;
    }

    final double target =
    (_peopleScrollController.offset - 350).clamp(
      0.0,
      _peopleScrollController.position.maxScrollExtent,
    );

    _peopleScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );

    _showScrollControls.value = true;
  }

  void _scrollPeopleDown() {
    if (!_peopleScrollController.hasClients) {
      return;
    }

    final double target =
    (_peopleScrollController.offset + 350).clamp(
      0.0,
      _peopleScrollController.position.maxScrollExtent,
    );

    _peopleScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );

    _showScrollControls.value = true;
  }

  void _scrollPeopleToTop() {
    if (!_peopleScrollController.hasClients) {
      return;
    }

    _peopleScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }
  @override
  void dispose() {
    _worker?.dispose();

    _scrollHideTimer?.cancel();

    _peopleScrollController.removeListener(
      _onPeopleScroll,
    );

    _peopleScrollController.dispose();

    super.dispose();
  }
  Future<void> _reload() async {
    final bool complete =
        _assets.length >= person.assetIds.length && _assets.isNotEmpty;

    if (complete && _loadedCount == person.assetIds.length) return;

    final List<AssetEntity> loaded = await controller.loadAssetsForPerson(
      person,
    );

    if (!mounted) return;

    setState(() {
      _assets = loaded;
      _loadedCount = person.assetIds.length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const _PeopleBackButton(),
        title: Text(
          person.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: InnerChrome.ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Same person? Merge',
            icon: Icon(Icons.merge_type, color: InnerChrome.ink),
            onPressed: () {
              _mergeDialog(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: InnerChrome.ink),
            onPressed: () {
              _renamePerson(context, person);
            },
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: SplashLoader());
    }

    final List<AssetEntity> assets = _assets;

    if (assets.isEmpty) {
      return Center(
        child: Text(
          'No photos found',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: InnerChrome.muted,
            fontSize: 15,
          ),
        ),
      );
    }

    return Obx(() {
      final int columns =
          photosController.crossAxisCount.value;

      return Stack(
        children: [
          // =================================================
          // PEOPLE PHOTOS GRID
          // =================================================

          GestureDetector(
            behavior: HitTestBehavior.translucent,

            onScaleStart: (_) {
              photosController.onGridScaleStart();
            },

            onScaleUpdate: (details) {
              photosController.onGridScaleUpdate(
                details.scale,
              );
            },

            child: GridView.builder(
              controller: _peopleScrollController,

              padding: const EdgeInsets.all(2),

              gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),

              itemCount: assets.length,

              itemBuilder: (context, index) {
                final AssetEntity asset = assets[index];

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  onTap: () {
                    Get.to(
                          () => PhotoViewScreen(
                        asset: asset,
                        albumMedia: assets,
                      ),
                    );
                  },

                  child: AssetEntityImage(
                    asset,
                    isOriginal: false,
                    thumbnailSize:
                    const ThumbnailSize(500, 500),
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),

          // =================================================
          // RIGHT SIDE ↑ ↓ ACTION
          // =================================================

          Obx(
                () => Positioned(
              right: 0,
              top: _scrollThumbTop.value,

              child: AnimatedOpacity(
                duration:
                const Duration(milliseconds: 180),

                opacity:
                _showScrollControls.value
                    ? 1.0
                    : 0.0,

                child: IgnorePointer(
                  ignoring:
                  !_showScrollControls.value,

                  child: Container(
                    width: 38,
                    height: 62,

                    decoration: const BoxDecoration(
                      color: Color(0xff333333),

                      borderRadius:
                      BorderRadius.only(
                        topLeft:
                        Radius.circular(20),
                        bottomLeft:
                        Radius.circular(20),
                      ),
                    ),

                    child: Column(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _scrollPeopleUp,

                            child: const Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),

                        Expanded(
                          child: InkWell(
                            onTap: _scrollPeopleDown,

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

          // =================================================
          // BOTTOM CENTER ↑ BUTTON
          // =================================================

          Obx(
                () => Positioned(
              left: 0,
              right: 0,
              bottom: 16,

              child: AnimatedOpacity(
                duration:
                const Duration(milliseconds: 180),

                opacity:
                _showScrollControls.value
                    ? 1.0
                    : 0.0,

                child: IgnorePointer(
                  ignoring:
                  !_showScrollControls.value,

                  child: Center(
                    child: Material(
                      color:
                      const Color(0xff333333),

                      shape:
                      const CircleBorder(),

                      elevation: 5,

                      child: InkWell(
                        customBorder:
                        const CircleBorder(),

                        onTap: _scrollPeopleToTop,

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
      );
    });
  }
  Future<void> _mergeDialog(BuildContext context) async {
    final List<FacePerson> others = controller.visiblePeople
        .where((p) => p.id != person.id)
        .toList();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: InnerChrome.sheet,
          title: Text(
            'Merge into which person?',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: InnerChrome.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: others.isEmpty
                ? Center(
                    child: Text(
                      'No other people',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: InnerChrome.muted,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: others.length,
                    itemBuilder: (context, index) {
                      final FacePerson other = others[index];
                      return ListTile(
                        leading: ClipOval(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: FutureBuilder<Uint8List?>(
                              future: controller.getCover(other),
                              builder: (context, snapshot) {
                                if (snapshot.data == null) {
                                  return ColoredBox(
                                    color: InnerChrome.alt,
                                    child: Icon(
                                      Icons.person,
                                      color: InnerChrome.muted,
                                    ),
                                  );
                                }
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                        title: Text(
                          other.name,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: InnerChrome.ink,
                          ),
                        ),
                        subtitle: Text(
                          '${other.assetIds.length} photos',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: InnerChrome.muted,
                          ),
                        ),
                        onTap: () async {
                          await controller.mergePeople(other, person);

                          Get.back();
                          Get.back();
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: InnerChrome.muted,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renamePerson(BuildContext context, FacePerson person) async {
    final TextEditingController nameController = TextEditingController(
      text: person.name.startsWith('Person ') ? '' : person.name,
    );

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: InnerChrome.sheet,
          title: Text(
            'Name this person',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: InnerChrome.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: InnerChrome.ink,
            ),
            cursorColor: InnerChrome.accent,
            decoration: InputDecoration(
              hintText: 'Enter name',
              hintStyle: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: InnerChrome.muted,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: InnerChrome.line),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: InnerChrome.accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: InnerChrome.muted,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await controller.renamePerson(person, nameController.text);

                Get.back();
              },
              child: Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: InnerChrome.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PeopleBackButton extends StatelessWidget {
  const _PeopleBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: GestureDetector(
        onTap: Get.back,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: InnerChrome.light ? Colors.white : InnerChrome.alt,
            shape: BoxShape.circle,
            border: Border.all(color: InnerChrome.line),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: InnerChrome.ink,
          ),
        ),
      ),
    );
  }
}
