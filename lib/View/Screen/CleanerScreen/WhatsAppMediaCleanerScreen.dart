import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/CleanerMediaSelectionScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

class WhatsAppMediaCleanerScreen extends StatefulWidget {
  const WhatsAppMediaCleanerScreen({super.key});

  static Future<bool> deviceHasWhatsAppFolders() async {
    try {
      final PermissionState permission = await PhotoManager.getPermissionState(
        requestOption: const PermissionRequestOption(),
      );
      if (!permission.hasAccess) {
        return false;
      }
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: false,
      );
      return albums.any(
        (album) => album.name.toLowerCase().contains('whatsapp'),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  State<WhatsAppMediaCleanerScreen> createState() =>
      _WhatsAppMediaCleanerScreenState();
}

class WhatsAppCleanerOption extends StatefulWidget {
  const WhatsAppCleanerOption({super.key, required this.child});

  final Widget child;

  @override
  State<WhatsAppCleanerOption> createState() => _WhatsAppCleanerOptionState();
}

class _WhatsAppCleanerOptionState extends State<WhatsAppCleanerOption> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && !_show) {
        _refresh();
      }
    });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && !_show) {
        _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    final bool found = await WhatsAppMediaCleanerScreen.deviceHasWhatsAppFolders();
    if (!mounted || found == _show) {
      return;
    }
    setState(() => _show = found);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}

enum _WaKind { images, videos, voice, other }

class _WaBucket {
  int bytes = 0;
  final List<AssetEntity> assets = [];
}

class _WhatsAppMediaCleanerScreenState extends State<WhatsAppMediaCleanerScreen>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF25D366);

  final Map<_WaKind, _WaBucket> _buckets = {
    for (final kind in _WaKind.values) kind: _WaBucket(),
  };

  late final AnimationController _enter;
  Timer? _counter;
  int _shownBytes = 0;
  int _targetBytes = 0;
  bool _scanning = true;
  bool _stop = false;
  String _scanningFile = 'Preparing scan...';

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _counter = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (!mounted || _shownBytes == _targetBytes) {
        return;
      }
      final int gap = _targetBytes - _shownBytes;
      final int step = math.max(1, gap ~/ 10);
      setState(() => _shownBytes = math.min(_targetBytes, _shownBytes + step));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _stop = true;
    _counter?.cancel();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _scanning = true;
      _stop = false;
      _targetBytes = 0;
      _scanningFile = 'Looking through WhatsApp folders...';
      for (final bucket in _buckets.values) {
        bucket.bytes = 0;
        bucket.assets.clear();
      }
    });

    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess || _stop) {
      _finish('Photos permission is needed to scan WhatsApp media');
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: false,
    );
    if (_stop) {
      _finish('Scan stopped');
      return;
    }

    final List<AssetPathEntity> whatsappAlbums = albums.where((album) {
      return album.name.toLowerCase().contains('whatsapp');
    }).toList();

    final List<AssetPathEntity> source =
        whatsappAlbums.isEmpty ? albums : whatsappAlbums;
    final Set<String> seen = {};

    for (final AssetPathEntity album in source) {
      if (_stop) {
        break;
      }
      final int count = await album.assetCountAsync;
      if (count <= 0) {
        continue;
      }
      const int pageSize = 60;
      final int pages = (count / pageSize).ceil();
      for (int page = 0; page < pages; page++) {
        if (_stop) {
          break;
        }
        final List<AssetEntity> assets = await album.getAssetListPaged(
          page: page,
          size: pageSize,
        );
        for (final AssetEntity asset in assets) {
          if (_stop) {
            break;
          }
          if (!seen.add(asset.id)) {
            continue;
          }
          final String path =
              '${album.name} ${asset.relativePath ?? ''} ${asset.title ?? ''}'
                  .toLowerCase();
          if (!path.contains('whatsapp') && !path.contains('/wa')) {
            continue;
          }
          final String label = asset.relativePath?.isNotEmpty == true
              ? '${asset.relativePath}${asset.title ?? ''}'
              : (asset.title ?? album.name);
          if (mounted) {
            setState(() => _scanningFile = 'Scanning $label');
          }
          final _WaKind kind = _kindFor(asset, path);
          int size = 0;
          try {
            size = await asset.fileSize;
          } catch (_) {
            size = 0;
          }
          if (_stop || !mounted) {
            break;
          }
          final _WaBucket bucket = _buckets[kind]!;
          bucket.assets.add(asset);
          if (size > 0) {
            bucket.bytes += size;
            _targetBytes += size;
          }
          setState(() {});
          await Future<void>.delayed(const Duration(milliseconds: 18));
        }
      }
    }

    _finish(_stop ? 'Scan stopped' : 'Scan finished');
  }

  void _finish(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _scanning = false;
      _scanningFile = message;
      _targetBytes = _buckets.values.fold<int>(0, (sum, b) => sum + b.bytes);
    });
  }

  _WaKind _kindFor(AssetEntity asset, String path) {
    if (path.contains('voice') ||
        path.contains('ptt') ||
        path.contains('audio') ||
        asset.type == AssetType.audio) {
      return _WaKind.voice;
    }
    if (asset.type == AssetType.video || path.contains('video')) {
      return _WaKind.videos;
    }
    if (asset.type == AssetType.image || path.contains('image')) {
      return _WaKind.images;
    }
    return _WaKind.other;
  }

  String _format(int bytes) {
    if (bytes < 1024) {
      return '$bytes';
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toStringAsFixed(0);
    }
    if (bytes < 1024 * 1024 * 1024) {
      return (bytes / (1024 * 1024)).toStringAsFixed(1);
    }
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
  }

  String _unit(int bytes) {
    if (bytes < 1024) {
      return 'B';
    }
    if (bytes < 1024 * 1024) {
      return 'KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return 'MB';
    }
    return 'GB';
  }

  String _formatFull(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    return '${_format(bytes)} ${_unit(bytes)}';
  }

  void _openBucket(_WaKind kind, String title) {
    if (_scanning) {
      return;
    }
    final List<AssetEntity> assets = _buckets[kind]!.assets;
    if (assets.isEmpty) {
      Get.snackbar(
        title,
        'Nothing found in this folder',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }
    Get.to(
      () => CleanerMediaSelectionScreen(
        assets: assets,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color page = isDark ? const Color(0xFF000000) : const Color(0xFFF6F7F8);
    final Color text = isDark ? Colors.white : const Color(0xFF17191C);
    final Color muted = isDark ? const Color(0xFF8E8E93) : const Color(0xFF7A818A);

    return Scaffold(
      backgroundColor: page,
      appBar: AppBar(
        backgroundColor: page,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            _stop = true;
            Get.back();
          },
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Text(
              'WhatsApp cleaner',
              style: TextStyle(
                color: text,
                fontSize: 32,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.86, end: 1).animate(
                  CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _format(_shownBytes),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 64,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 2),
                      child: Text(
                        _unit(_shownBytes),
                        style: const TextStyle(
                          color: _green,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                _shrink(_scanningFile),
                key: ValueKey(_scanningFile),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 36),
          _row(_WaKind.images, 'Images', 0),
          _row(_WaKind.videos, 'Videos', 1),
          _row(_WaKind.voice, 'Voice messages', 2),
          _row(_WaKind.other, 'Other', 3),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  if (_scanning) {
                    _stop = true;
                    return;
                  }
                  _shownBytes = 0;
                  _startScan();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _scanning ? 'Stop' : 'Scan again',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(_WaKind kind, String title, int index) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color text = isDark ? Colors.white : const Color(0xFF17191C);
    final _WaBucket bucket = _buckets[kind]!;
    final Animation<double> slide = CurvedAnimation(
      parent: _enter,
      curve: Interval(0.15 + index * 0.12, 1, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: slide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(slide),
        child: InkWell(
          onTap: () => _openBucket(kind, title),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: text, fontSize: 17),
                  ),
                ),
                if (_scanning)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _green,
                    ),
                  )
                else
                  Text(
                    _formatFull(bucket.bytes),
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF9A9AA0)
                          : const Color(0xFF7A818A),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shrink(String value) {
    if (value.length <= 46) {
      return value;
    }
    return '${value.substring(0, 22)}...${value.substring(value.length - 18)}';
  }
}
