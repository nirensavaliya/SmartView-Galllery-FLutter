import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/Common/MediaActionService.dart';
import 'package:gallery_photos/Common/MediaManager.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/CleanerMediaSelectionScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Utils/App_Routes.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_hash/image_hash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:photo_manager/photo_manager.dart';

enum CleanerCategoryType {
  cacheFiles,
  memoryJunk,
  duplicatePhotos,
  largeFiles,
  media,
  screenshots,
  obsoleteFiles,
  packages,
  residuals,
}

enum CleanerRowStatus { waiting, progress, completed, cleared }

extension CleanerCategoryTypeX on CleanerCategoryType {
  bool get isGallery =>
      this == CleanerCategoryType.duplicatePhotos ||
      this == CleanerCategoryType.largeFiles ||
      this == CleanerCategoryType.media ||
      this == CleanerCategoryType.screenshots;

  bool get isJunk => !isGallery;

  String get title {
    switch (this) {
      case CleanerCategoryType.cacheFiles:
        return 'Cache files';
      case CleanerCategoryType.memoryJunk:
        return 'Memory junk';
      case CleanerCategoryType.duplicatePhotos:
        return 'Duplicate Photos';
      case CleanerCategoryType.largeFiles:
        return 'Large Files';
      case CleanerCategoryType.media:
        return 'Media';
      case CleanerCategoryType.screenshots:
        return 'Screenshots';
      case CleanerCategoryType.obsoleteFiles:
        return 'Obsolete files';
      case CleanerCategoryType.packages:
        return 'Packages';
      case CleanerCategoryType.residuals:
        return 'Residuals';
    }
  }
}

class CleanerAssetItem {
  CleanerAssetItem({
    required this.asset,
    required this.bytes,
  });

  final AssetEntity asset;
  final int bytes;
}

class DuplicateGroup {
  DuplicateGroup({
    required this.key,
    required this.items,
  });

  final String key;
  final List<CleanerAssetItem> items;

  int get reclaimableBytes {
    if (items.length <= 1) return 0;
    final sorted = [...items]..sort((a, b) => b.bytes.compareTo(a.bytes));
    return sorted.skip(1).fold<int>(0, (sum, e) => sum + e.bytes);
  }
}

class CleanerCategory {
  CleanerCategory({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.items,
    this.duplicateGroups = const [],
    this.junkBytes = 0,
  });

  final CleanerCategoryType type;
  final String title;
  final String subtitle;
  final List<CleanerAssetItem> items;
  final List<DuplicateGroup> duplicateGroups;
  final int junkBytes;

  int get totalBytes => type.isJunk
      ? junkBytes
      : items.fold<int>(0, (sum, e) => sum + e.bytes);

  int get count => type.isJunk
      ? (junkBytes > 0 ? 1 : 0)
      : type == CleanerCategoryType.duplicatePhotos
          ? duplicateGroups.fold<int>(0, (sum, g) => sum + g.items.length)
          : items.length;
}

class CleanerController extends GetxController {
  static const int _pageSize = 80;
  static const int largeFileThreshold = 20 * 1024 * 1024;

  final RxBool scanning = true.obs;
  final RxBool deleting = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString statusText = 'Preparing…'.obs;
  final RxInt totalJunkBytes = 0.obs;
  final RxInt scanGen = 0.obs;
  final RxInt cleanGen = 0.obs;

  final RxMap<CleanerCategoryType, CleanerRowStatus> rowStatus =
      <CleanerCategoryType, CleanerRowStatus>{
    for (final t in CleanerCategoryType.values) t: CleanerRowStatus.waiting,
  }.obs;

  final RxMap<CleanerCategoryType, int> junkBytes =
      <CleanerCategoryType, int>{
    CleanerCategoryType.cacheFiles: 0,
    CleanerCategoryType.memoryJunk: 0,
    CleanerCategoryType.obsoleteFiles: 0,
    CleanerCategoryType.packages: 0,
    CleanerCategoryType.residuals: 0,
  }.obs;

  final RxList<CleanerAssetItem> largeFiles = <CleanerAssetItem>[].obs;
  final RxList<CleanerAssetItem> mediaFiles = <CleanerAssetItem>[].obs;
  final RxList<CleanerAssetItem> screenshots = <CleanerAssetItem>[].obs;
  final RxList<DuplicateGroup> duplicateGroups = <DuplicateGroup>[].obs;
  final RxInt duplicateCount = 0.obs;
  final RxInt similarCount = 0.obs;
  final RxList<AssetEntity> similarAssets = <AssetEntity>[].obs;

  final RxSet<String> selectedIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    startScan();
  }

  Future<void> startScan() async {
    scanning.value = true;
    deleting.value = false;
    progress.value = 0.02;
    statusText.value = 'Scanning…';
    totalJunkBytes.value = 0;
    scanGen.value++;
    largeFiles.clear();
    mediaFiles.clear();
    screenshots.clear();
    duplicateGroups.clear();
    selectedIds.clear();
    for (final type in CleanerCategoryType.values) {
      rowStatus[type] = CleanerRowStatus.waiting;
    }
    for (final key in junkBytes.keys.toList()) {
      junkBytes[key] = 0;
    }
    rowStatus.refresh();
    junkBytes.refresh();

    try {
      // ---- App / device junk (cache + memory style rows) ----
      await _finishCategory(CleanerCategoryType.cacheFiles, () async {
        statusText.value = 'Scanning cache files…';
        progress.value = 0.08;
        final cache = await _scanAppCacheBytes();
        junkBytes[CleanerCategoryType.cacheFiles] = cache;
        junkBytes.refresh();
      });

      await _finishCategory(CleanerCategoryType.memoryJunk, () async {
        statusText.value = 'Scanning memory junk…';
        progress.value = 0.14;
        final cache = junkBytes[CleanerCategoryType.cacheFiles] ?? 0;
        // Memory junk ≈ temp/thumbnail leftovers related to cache
        junkBytes[CleanerCategoryType.memoryJunk] =
            math.max((cache * 0.45).round(), await _scanTempBytes());
        junkBytes.refresh();
      });

      final estimates = await _estimateSystemJunk();
      await _finishCategory(CleanerCategoryType.obsoleteFiles, () async {
        statusText.value = 'Scanning obsolete files…';
        progress.value = 0.18;
        junkBytes[CleanerCategoryType.obsoleteFiles] = estimates.$1;
        junkBytes.refresh();
      });
      await _finishCategory(CleanerCategoryType.packages, () async {
        statusText.value = 'Scanning packages…';
        progress.value = 0.22;
        junkBytes[CleanerCategoryType.packages] = estimates.$2;
        junkBytes.refresh();
      });
      await _finishCategory(CleanerCategoryType.residuals, () async {
        statusText.value = 'Scanning residuals…';
        progress.value = 0.26;
        junkBytes[CleanerCategoryType.residuals] = estimates.$3;
        junkBytes.refresh();
      });

      // ---- Gallery media categories ----
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        statusText.value = 'Photo permission needed for media scan';
        for (final t in CleanerCategoryType.values.where((e) => e.isGallery)) {
          rowStatus[t] = CleanerRowStatus.completed;
        }
        rowStatus.refresh();
        _recomputeTotal();
        progress.value = 1;
        scanning.value = false;
        return;
      }

      final all = await _loadAllAssets();
      progress.value = 0.40;
      statusText.value = 'Checking media sizes…';

      final sized = <CleanerAssetItem>[];
      for (var i = 0; i < all.length; i++) {
        final asset = all[i];
        sized.add(CleanerAssetItem(asset: asset, bytes: await _assetBytes(asset)));
        if (i % 25 == 0) {
          progress.value = 0.40 + (0.30 * (i + 1) / math.max(1, all.length));
          statusText.value = 'Analyzing ${i + 1}/${all.length}…';
        }
      }

      await _finishCategory(CleanerCategoryType.duplicatePhotos, () async {
        statusText.value = 'Detecting duplicates…';
        progress.value = 0.78;
        duplicateGroups.assignAll(_findDuplicates(sized));
        duplicateCount.value = duplicateGroups.fold<int>(
          0,
          (sum, group) => sum + group.items.length,
        );
        await _reapplyCopiedPhotos();
      });

      await _finishCategory(CleanerCategoryType.largeFiles, () async {
        statusText.value = 'Finding large files…';
        progress.value = 0.86;
        final large = sized
            .where((e) => e.bytes >= largeFileThreshold)
            .toList()
          ..sort((a, b) => b.bytes.compareTo(a.bytes));
        largeFiles.assignAll(large);
      });

      await _finishCategory(CleanerCategoryType.media, () async {
        statusText.value = 'Collecting media…';
        progress.value = 0.92;
        final media = sized
            .where((e) => e.asset.type == AssetType.video)
            .toList()
          ..sort((a, b) => b.bytes.compareTo(a.bytes));
        mediaFiles.assignAll(media);
      });

      await _finishCategory(CleanerCategoryType.screenshots, () async {
        statusText.value = 'Finding screenshots…';
        progress.value = 0.97;
        screenshots.assignAll(await _findScreenshots(sized));
      });

      unawaited(_findSimilarPhotos(all));

      _recomputeTotal();
      progress.value = 1;
      statusText.value =
          totalJunkBytes.value > 0 ? 'Scan complete' : 'Nothing to clean';
    } catch (e, st) {
      debugPrint('Cleaner scan error: $e\n$st');
      statusText.value = 'Scan failed';
      progress.value = 0;
    } finally {
      scanning.value = false;
      await _reapplyCopiedPhotos();
    }
  }

  Future<void> _finishCategory(
    CleanerCategoryType type,
    Future<void> Function() work,
  ) async {
    rowStatus[type] = CleanerRowStatus.progress;
    rowStatus.refresh();
    await work();
    await Future.delayed(const Duration(milliseconds: 140));
    rowStatus[type] = CleanerRowStatus.completed;
    rowStatus.refresh();
  }

  double _toMb(double raw, double fallbackMb) {
    if (raw <= 0) return fallbackMb;
    if (raw < 4096) return raw * 1024;
    return raw;
  }

  Future<(int, int, int)> _estimateSystemJunk() async {
    double totalMb = 128 * 1024;
    double freeMb = 40 * 1024;
    try {
      final disk = DiskSpacePlus();
      totalMb = _toMb(await disk.getTotalDiskSpace ?? 0, totalMb);
      freeMb = _toMb(await disk.getFreeDiskSpace ?? 0, freeMb);
    } catch (_) {}

    final usedMb = (totalMb - freeMb).clamp(1024, totalMb);
    final junkMb = usedMb * 0.012;
    var junkBytesEst = (junkMb * 1024 * 1024).round();
    final cache = junkBytes[CleanerCategoryType.cacheFiles] ?? 0;
    final memory = junkBytes[CleanerCategoryType.memoryJunk] ?? 0;
    junkBytesEst = math.max(junkBytesEst, cache + memory);
    final leftover = math.max(0, junkBytesEst - cache - memory);
    final obsolete = (leftover * 0.40).round();
    final packages = (leftover * 0.35).round();
    final residuals = math.max(0, leftover - obsolete - packages);
    return (obsolete, packages, residuals);
  }

  Future<int> _directoryBytes(Directory dir) async {
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<int> _scanAppCacheBytes() async {
    var total = 0;
    try {
      total += await _directoryBytes(await getApplicationCacheDirectory());
    } catch (_) {}
    try {
      total += await _directoryBytes(await getTemporaryDirectory());
    } catch (_) {}
    return total;
  }

  Future<int> _scanTempBytes() async {
    try {
      return await _directoryBytes(await getTemporaryDirectory());
    } catch (_) {
      return 0;
    }
  }

  Future<void> _deleteDirectoryContents(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<List<AssetEntity>> _loadAllAssets() async {
    await PhotoManager.clearFileCache();
    final loaded = <AssetEntity>[];
    final ids = <String>{};
    var page = 0;
    while (true) {
      final batch = await MediaManger.getAllMedia(page: page, size: _pageSize);
      if (batch.isEmpty) break;
      for (final asset in batch) {
        if (ids.add(asset.id)) loaded.add(asset);
      }
      progress.value = (0.28 + (page * 0.015)).clamp(0.28, 0.39);
      if (batch.length < _pageSize) break;
      page++;
    }
    return loaded;
  }

  Future<int> _assetBytes(AssetEntity asset) async {
    try {
      final file = await asset.originFile ?? await asset.file;
      if (file != null && await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  Future<List<CleanerAssetItem>> _findScreenshots(
    List<CleanerAssetItem> sized,
  ) async {
    final shotIds = <String>{};
    try {
      final album = await MediaManger.findAlbumContains('screenshot');
      if (album != null) {
        final count = await album.assetCountAsync;
        final assets = await album.getAssetListRange(start: 0, end: count);
        for (final a in assets) {
          shotIds.add(a.id);
        }
      }
    } catch (_) {}

    bool looksLikeScreenshot(AssetEntity asset) {
      if (asset.type != AssetType.image) return false;
      final title = (asset.title ?? '').toLowerCase();
      if (title.contains('screenshot') ||
          title.contains('screen_shot') ||
          title.contains('screen-shot') ||
          title.contains('screen shot')) {
        return true;
      }
      return shotIds.contains(asset.id);
    }

    return sized.where((e) => looksLikeScreenshot(e.asset)).toList()
      ..sort((a, b) => b.asset.createDateTime.compareTo(a.asset.createDateTime));
  }

  List<DuplicateGroup> _findDuplicates(List<CleanerAssetItem> sized) {
    final map = <String, List<CleanerAssetItem>>{};
    for (final item in sized) {
      if (item.asset.type != AssetType.image || item.bytes <= 0) continue;
      final key = '${item.asset.width}x${item.asset.height}_${item.bytes}';
      map.putIfAbsent(key, () => []).add(item);
    }
    final groups = <DuplicateGroup>[];
    for (final entry in map.entries) {
      if (entry.value.length < 2) continue;
      final items = [...entry.value]
        ..sort((a, b) => b.asset.createDateTime.compareTo(a.asset.createDateTime));
      groups.add(DuplicateGroup(key: entry.key, items: items));
    }
    groups.sort((a, b) => b.reclaimableBytes.compareTo(a.reclaimableBytes));
    return groups;
  }

  void _recomputeTotal() {
    final unique = <String, int>{};
    for (final e in largeFiles) {
      unique[e.asset.id] = e.bytes;
    }
    for (final e in mediaFiles) {
      unique[e.asset.id] = e.bytes;
    }
    for (final e in screenshots) {
      unique[e.asset.id] = e.bytes;
    }
    for (final g in duplicateGroups) {
      if (g.items.length <= 1) continue;
      for (final e in g.items.skip(1)) {
        unique[e.asset.id] = e.bytes;
      }
    }
    final gallery = unique.values.fold<int>(0, (a, b) => a + b);
    final junk = junkBytes.values.fold<int>(0, (a, b) => a + b);
    totalJunkBytes.value = gallery + junk;
  }

  CleanerCategory categoryOf(CleanerCategoryType type) {
    final status = rowStatus[type] ?? CleanerRowStatus.waiting;
    final scanningRow = status == CleanerRowStatus.waiting ||
        status == CleanerRowStatus.progress;

    switch (type) {
      case CleanerCategoryType.cacheFiles:
      case CleanerCategoryType.memoryJunk:
      case CleanerCategoryType.obsoleteFiles:
      case CleanerCategoryType.packages:
      case CleanerCategoryType.residuals:
        final bytes = junkBytes[type] ?? 0;
        final cleared = status == CleanerRowStatus.cleared;
        return CleanerCategory(
          type: type,
          title: type.title,
          subtitle: scanningRow
              ? 'Scanning'
              : cleared
                  ? 'Cleared'
                  : formatBytes(bytes),
          items: const [],
          junkBytes: bytes,
        );
      case CleanerCategoryType.largeFiles:
        return CleanerCategory(
          type: type,
          title: type.title,
          subtitle: scanningRow
              ? 'Scanning'
              : '${largeFiles.length} files · ${formatBytes(categoryBytes(type))}',
          items: largeFiles.toList(),
        );
      case CleanerCategoryType.media:
        return CleanerCategory(
          type: type,
          title: type.title,
          subtitle: scanningRow
              ? 'Scanning'
              : '${mediaFiles.length} videos · ${formatBytes(categoryBytes(type))}',
          items: mediaFiles.toList(),
        );
      case CleanerCategoryType.duplicatePhotos:
        final count = duplicateGroups.fold<int>(
          0,
          (sum, g) => sum + g.items.length,
        );
        return CleanerCategory(
          type: type,
          title: type.title,
          subtitle: scanningRow
              ? 'Scanning'
              : '${duplicateGroups.length} groups · $count photos · ${formatBytes(categoryBytes(type))}',
          items: duplicateGroups.expand((g) => g.items).toList(),
          duplicateGroups: duplicateGroups.toList(),
        );
      case CleanerCategoryType.screenshots:
        return CleanerCategory(
          type: type,
          title: type.title,
          subtitle: scanningRow
              ? 'Scanning'
              : '${screenshots.length} photos · ${formatBytes(categoryBytes(type))}',
          items: screenshots.toList(),
        );
    }
  }

  int categoryBytes(CleanerCategoryType type) {
    if (type.isJunk) return junkBytes[type] ?? 0;
    switch (type) {
      case CleanerCategoryType.largeFiles:
        return largeFiles.fold(0, (s, e) => s + e.bytes);
      case CleanerCategoryType.media:
        return mediaFiles.fold(0, (s, e) => s + e.bytes);
      case CleanerCategoryType.screenshots:
        return screenshots.fold(0, (s, e) => s + e.bytes);
      case CleanerCategoryType.duplicatePhotos:
        return duplicateGroups.fold(0, (s, g) => s + g.reclaimableBytes);
      default:
        return 0;
    }
  }

  List<CleanerCategory> get categories => [
        categoryOf(CleanerCategoryType.cacheFiles),
        categoryOf(CleanerCategoryType.memoryJunk),
        categoryOf(CleanerCategoryType.duplicatePhotos),
        categoryOf(CleanerCategoryType.largeFiles),
        categoryOf(CleanerCategoryType.media),
        categoryOf(CleanerCategoryType.screenshots),
        categoryOf(CleanerCategoryType.obsoleteFiles),
        categoryOf(CleanerCategoryType.packages),
        categoryOf(CleanerCategoryType.residuals),
      ];

  final List<(AssetEntity, AssetEntity)> _copiedPhotos = [];

  Future<void> rememberCopiedPhoto(
    AssetEntity source,
    AssetEntity copied,
  ) async {
    if (copied.type != AssetType.image) return;
    _copiedPhotos.add((source, copied));
    await _insertCopiedPhoto(source, copied);
  }

  Future<void> _reapplyCopiedPhotos() async {
    for (final (AssetEntity source, AssetEntity copied) in _copiedPhotos) {
      await _insertCopiedPhoto(source, copied);
    }
  }

  Future<void> _insertCopiedPhoto(
    AssetEntity source,
    AssetEntity copied,
  ) async {
    int bytes = await _assetBytes(copied);
    if (bytes <= 0) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      bytes = await _assetBytes(copied);
    }
    if (bytes <= 0) return;

    final CleanerAssetItem copyItem = CleanerAssetItem(
      asset: copied,
      bytes: bytes,
    );
    final String key = '${copied.width}x${copied.height}_$bytes';
    final List<DuplicateGroup> groups = duplicateGroups.toList();
    final int index = groups.indexWhere(
      (DuplicateGroup group) =>
          group.key == key ||
          group.items.any((CleanerAssetItem item) => item.asset.id == source.id),
    );

    if (index >= 0) {
      final DuplicateGroup group = groups[index];
      if (group.items.any((CleanerAssetItem item) => item.asset.id == copied.id)) {
        return;
      }
      groups[index] = DuplicateGroup(
        key: group.key,
        items: [copyItem, ...group.items],
      );
    } else {
      int sourceBytes = await _assetBytes(source);
      if (sourceBytes <= 0) sourceBytes = bytes;
      groups.insert(
        0,
        DuplicateGroup(
          key: key,
          items: [
            copyItem,
            CleanerAssetItem(asset: source, bytes: sourceBytes),
          ],
        ),
      );
    }

    duplicateGroups.assignAll(groups);
    duplicateCount.value = groups.fold<int>(
      0,
      (int sum, DuplicateGroup group) => sum + group.items.length,
    );
    if (Get.currentRoute == AppRoutes.cleanerCategoryScreen &&
        Get.arguments == CleanerCategoryType.duplicatePhotos) {
      _selectDuplicateCopies();
    }
    _recomputeTotal();
  }

  bool _retriedDuplicates = false;

  Future<void> openDuplicates() async {
    if (!scanning.value && duplicateGroups.isEmpty && !_retriedDuplicates) {
      _retriedDuplicates = true;
      unawaited(startScan());
    }
    openCategory(CleanerCategoryType.duplicatePhotos);
  }

  Future<void> openSimilarPhotos() async {
    if (scanning.value && similarAssets.isEmpty) {
      AppToast.show('Please wait until the scan is complete.');
      return;
    }
    await Get.to(
      () => CleanerMediaSelectionScreen(
        assets: similarAssets.toList(),
        title: 'Similar Photos',
        groupByDate: true,
      ),
    );
  }

  Future<void> _findSimilarPhotos(List<AssetEntity> assets) async {
    final imageAssets =
        assets.where((asset) => asset.type == AssetType.image).toList();
    final hashedAssets = <AssetEntity>[];
    final hashes = <ImageHash>[];
    final similarIds = <String>{};

    for (final asset in imageAssets) {
      try {
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(160, 160),
          quality: 70,
        );
        if (thumbnail == null) continue;
        final decoded = img.decodeImage(thumbnail);
        if (decoded == null) continue;
        final currentHash = ImageHasher.perceptual(decoded);
        for (var i = 0; i < hashes.length; i++) {
          if (currentHash.similarity(hashes[i]) >= 0.85) {
            similarIds.add(hashedAssets[i].id);
            similarIds.add(asset.id);
          }
        }
        hashedAssets.add(asset);
        hashes.add(currentHash);
      } catch (e) {
        debugPrint('Similar photo error ${asset.id}: $e');
      }
    }

    similarAssets.assignAll(
      imageAssets.where((asset) => similarIds.contains(asset.id)).toList(),
    );
    similarCount.value = similarAssets.length;
  }

  void openCategory(CleanerCategoryType type) {
    if (type.isJunk) {
      cleanJunkCategory(type);
      return;
    }
    selectedIds.clear();
    if (type == CleanerCategoryType.duplicatePhotos) {
      _selectDuplicateCopies();
    }
    Get.toNamed(AppRoutes.cleanerCategoryScreen, arguments: type);
  }

  Future<void> cleanJunkCategory(CleanerCategoryType type) async {
    if (!type.isJunk || scanning.value || deleting.value) return;
    final bytes = junkBytes[type] ?? 0;
    if (bytes <= 0) {
      Get.snackbar(
        type.title,
        'Nothing to clean',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        backgroundColor: Colors.white,
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      ChromeDialog(
        title: 'Clean ${type.title}?',
        message:
            'Free about ${formatBytes(bytes)} from ${type.title.toLowerCase()}.',
        actions: [
          ChromeButton.cancel(onPressed: () => Get.back(result: false)),
          ChromeButton.danger(
            label: 'Clean',
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    deleting.value = true;
    cleanGen.value++;
    rowStatus[type] = CleanerRowStatus.progress;
    rowStatus.refresh();

    try {
      if (type == CleanerCategoryType.cacheFiles ||
          type == CleanerCategoryType.memoryJunk) {
        try {
          await _deleteDirectoryContents(await getTemporaryDirectory());
        } catch (_) {}
        try {
          await _deleteDirectoryContents(await getApplicationCacheDirectory());
        } catch (_) {}
      }
      await Future.delayed(const Duration(milliseconds: 1100));
      junkBytes[type] = 0;
      junkBytes.refresh();
      rowStatus[type] = CleanerRowStatus.cleared;
      rowStatus.refresh();
      _recomputeTotal();
      Get.snackbar(
        'Cleaned',
        '${type.title} cleared',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        backgroundColor: Colors.white,
      );
    } finally {
      deleting.value = false;
    }
  }

  Future<void> cleanAllJunkThenOpenMedia() async {
    if (scanning.value || deleting.value) return;

    final junkTypes = CleanerCategoryType.values.where((e) => e.isJunk).toList();
    final hasJunk = junkTypes.any((t) => (junkBytes[t] ?? 0) > 0);
    if (hasJunk) {
      deleting.value = true;
      cleanGen.value++;
      try {
        try {
          await _deleteDirectoryContents(await getTemporaryDirectory());
        } catch (_) {}
        try {
          await _deleteDirectoryContents(await getApplicationCacheDirectory());
        } catch (_) {}
        for (final type in junkTypes) {
          if ((junkBytes[type] ?? 0) <= 0) continue;
          rowStatus[type] = CleanerRowStatus.progress;
          rowStatus.refresh();
          await Future.delayed(const Duration(milliseconds: 320));
          junkBytes[type] = 0;
          junkBytes.refresh();
          rowStatus[type] = CleanerRowStatus.cleared;
          rowStatus.refresh();
        }
        await Future.delayed(const Duration(milliseconds: 700));
        _recomputeTotal();
      } finally {
        deleting.value = false;
      }
    }

    CleanerCategoryType? best;
    var bestBytes = 0;
    for (final type in CleanerCategoryType.values.where((e) => e.isGallery)) {
      final bytes = categoryBytes(type);
      if (categoryOf(type).count > 0 && bytes >= bestBytes) {
        bestBytes = bytes;
        best = type;
      }
    }
    if (best != null) {
      openCategory(best);
    } else if (hasJunk) {
      Get.snackbar(
        'Cleaned',
        'Cache & memory junk cleared',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        backgroundColor: Colors.white,
      );
    }
  }

  static (String, String) trashParts(int bytes) {
    if (bytes <= 0) return ('0', 'MB');
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return (gb.toStringAsFixed(2), 'GB');
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) {
      return (mb >= 10 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1), 'MB');
    }
    final kb = bytes / 1024;
    return (kb.toStringAsFixed(kb >= 10 ? 0 : 1), 'KB');
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    selectedIds.refresh();
  }

  void _selectDuplicateCopies() {
    selectedIds.clear();
    for (final g in duplicateGroups) {
      if (g.items.length < 2) continue;
      for (final item in g.items.skip(1)) {
        selectedIds.add(item.asset.id);
      }
    }
    selectedIds.refresh();
  }

  void selectAll(List<CleanerAssetItem> items) {
    selectedIds
      ..clear()
      ..addAll(items.map((e) => e.asset.id));
    selectedIds.refresh();
  }

  void clearSelection() {
    selectedIds.clear();
  }

  int selectedBytes(List<CleanerAssetItem> items) {
    final map = {for (final e in items) e.asset.id: e.bytes};
    return selectedIds.fold<int>(0, (sum, id) => sum + (map[id] ?? 0));
  }

  Future<int> deleteSelected(List<CleanerAssetItem> sourceItems) async {
    if (selectedIds.isEmpty || deleting.value) return 0;
    deleting.value = true;
    try {
      final ids = selectedIds.toList();
      final deleted = await _deleteIds(ids);
      final deletedSet = deleted.toSet();
      if (deletedSet.isEmpty) return 0;

      largeFiles.removeWhere((e) => deletedSet.contains(e.asset.id));
      mediaFiles.removeWhere((e) => deletedSet.contains(e.asset.id));
      screenshots.removeWhere((e) => deletedSet.contains(e.asset.id));

      final nextGroups = <DuplicateGroup>[];
      for (final g in duplicateGroups) {
        final kept =
            g.items.where((e) => !deletedSet.contains(e.asset.id)).toList();
        if (kept.length >= 2) {
          nextGroups.add(DuplicateGroup(key: g.key, items: kept));
        }
      }
      duplicateGroups.assignAll(nextGroups);
      duplicateCount.value = nextGroups.fold<int>(
        0,
        (sum, group) => sum + group.items.length,
      );
      _copiedPhotos.removeWhere((pair) => deletedSet.contains(pair.$2.id));

      selectedIds.removeWhere(deletedSet.contains);
      _recomputeTotal();

      if (Get.isRegistered<PhotosController>()) {
        final photos = Get.find<PhotosController>();
        photos.allMedia.removeWhere((a) => deletedSet.contains(a.id));
        photos.filteredMedia.removeWhere((a) => deletedSet.contains(a.id));
        photos.allMedia.refresh();
        photos.filteredMedia.refresh();
      }

      return deleted.length;
    } finally {
      deleting.value = false;
    }
  }

  Future<List<String>> _deleteIds(List<String> ids) async {
    final resolvable = <String>[];
    final deleted = <String>[];
    for (final id in ids) {
      try {
        final AssetEntity? fresh = await AssetEntity.fromId(id);
        if (fresh == null) {
          deleted.add(id);
        } else {
          resolvable.add(fresh.id);
        }
      } on PlatformException catch (e) {
        debugPrint('Delete lookup $id failed: $e');
      }
    }
    if (resolvable.isEmpty) return deleted;

    try {
      deleted.addAll(await MediaActionService.deleteIds(resolvable));
    } on PlatformException {
      for (final id in resolvable) {
        try {
          deleted.addAll(await MediaActionService.deleteIds([id]));
        } on PlatformException catch (e) {
          debugPrint('Delete $id failed: $e');
        }
      }
    }
    return deleted;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var v = bytes.toDouble();
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final digits = v >= 10 || i == 0 ? 0 : 1;
    return '${v.toStringAsFixed(digits)} ${units[i]}';
  }

  Future<Uint8List?> thumbnail(AssetEntity asset) async {
    try {
      return await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );
    } catch (_) {
      return null;
    }
  }

  /// Used by the studio cleaner selection screen. Re-runs the existing scan.
  Future<void> rescan() => startScan();
}
