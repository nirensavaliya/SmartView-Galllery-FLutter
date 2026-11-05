import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/IntruderSelfieService.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:get/get.dart';

class IntruderSelfiesFolderTile extends StatefulWidget {
  const IntruderSelfiesFolderTile({super.key});

  @override
  State<IntruderSelfiesFolderTile> createState() =>
      _IntruderSelfiesFolderTileState();
}

class _IntruderSelfiesFolderTileState extends State<IntruderSelfiesFolderTile> {
  final RxInt _count = 0.obs;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final List<File> files = await IntruderSelfieService.listPhotos();

    if (mounted) {
      _count.value = files.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async {
        await Get.to(() => const IntruderSelfiesScreen());
        _loadCount();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.folder_rounded,
                color: colors.onSurface.withOpacity(0.7),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Intruder Selfies',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Obx(
                    () => Text(
                      '${_count.value} ${_count.value == 1 ? 'photo' : 'photos'}',
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class IntruderSelfiesScreen extends StatefulWidget {
  const IntruderSelfiesScreen({super.key});

  @override
  State<IntruderSelfiesScreen> createState() => _IntruderSelfiesScreenState();
}

class _IntruderSelfiesScreenState extends State<IntruderSelfiesScreen> {
  final RxList<File> _files = <File>[].obs;
  final RxBool _loading = true.obs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<File> files = await IntruderSelfieService.listPhotos();

    if (mounted) {
      _files.assignAll(files);
      _loading.value = false;
    }
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('INTRUDER SELFIE DELETE ERROR: $e');
    }

    _load();
  }

  void _confirmDelete(File file) {
    Get.dialog(
      ChromeDialog(
        title: 'Delete photo?',
        message: 'Do you want to permanently delete this photo?',
        actions: [
          ChromeButton.cancel(onPressed: Get.back),
          ChromeButton.danger(
            label: 'Delete',
            onPressed: () {
              Get.back();
              _delete(file);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: Get.back,
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: colors.onSurface,
            size: 20,
          ),
        ),
        title: Text(
          'Intruder Selfies',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Obx(
        () => _loading.value
            ? const Center(child: SplashLoader())
            : RefreshIndicator(
                onRefresh: _load,
                child: _files.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.3,
                          ),
                          Icon(
                            Icons.no_photography_outlined,
                            size: 70,
                            color: colors.onSurface.withOpacity(0.35),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              'No intruder photos',
                              style: TextStyle(
                                fontSize: 16,
                                color: colors.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Photos of wrong password attempts appear here',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurface.withOpacity(0.45),
                              ),
                            ),
                          ),
                        ],
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(2),
                        itemCount: _files.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                        itemBuilder: (context, index) {
                          final File file = _files[index];

                          return GestureDetector(
                            onTap: () async {
                              await Get.to(
                                () => _IntruderPhotoViewer(file: file),
                              );
                            },
                            onLongPress: () => _confirmDelete(file),
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              cacheWidth: 400,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey,
                                    size: 35,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

class _IntruderPhotoViewer extends StatelessWidget {
  const _IntruderPhotoViewer({required this.file});

  final File file;

  String _dateText() {
    final String name = file.path.split(Platform.pathSeparator).last;
    final String digits = name.replaceAll(RegExp(r'[^0-9]'), '');
    final int? millis = int.tryParse(digits);

    if (millis == null) {
      return 'Intruder Selfie';
    }

    final DateTime d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int v) => v.toString().padLeft(2, '0');

    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_dateText(), style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 60,
              );
            },
          ),
        ),
      ),
    );
  }
}
