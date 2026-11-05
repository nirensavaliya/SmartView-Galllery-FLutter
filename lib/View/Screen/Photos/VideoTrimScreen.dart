import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class VideoTrimScreen extends StatefulWidget {
  final AssetEntity asset;

  const VideoTrimScreen({super.key, required this.asset});

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  static const MethodChannel _channel = MethodChannel('native_camera');

  VideoPlayerController? _player;
  int _durationMs = 1;
  int _startMs = 0;
  int _endMs = 1;
  int _positionMs = 0;
  bool _ready = false;
  bool _playing = false;
  bool _saving = false;
  _Drag _drag = _Drag.none;
  int _windowStartMs = 0;
  double _dragOriginDx = 0;
  final List<Uint8List> _frames = <Uint8List>[];

  int get _minGap => _durationMs < 500 ? _durationMs : 500;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final File? file = await widget.asset.file;
      if (file == null || !await file.exists()) {
        AppToast.show('Video file not found');
        return;
      }
      final VideoPlayerController player = VideoPlayerController.file(file);
      await player.initialize();
      await player.setLooping(false);
      final int duration = player.value.duration.inMilliseconds;
      player.addListener(_onTick);
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _durationMs = duration > 0 ? duration : 1;
        _endMs = duration > 0 ? duration : 1;
        _ready = true;
      });
      _loadFrames(file.path);
    } catch (e) {
      debugPrint('TRIM OPEN ERROR: $e');
      AppToast.show('Unable to open video');
    }
  }

  Future<void> _loadFrames(String path) async {
    const int count = 8;
    final List<Uint8List> frames = <Uint8List>[];
    for (int index = 0; index < count; index++) {
      final int timeUs = (_durationMs * 1000 * (index + 1) / (count + 1)).round();
      try {
        final Uint8List? bytes = await widget.asset.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
          quality: 60,
          frame: timeUs,
        );
        if (bytes != null && bytes.isNotEmpty) {
          frames.add(bytes);
          if (mounted) {
            setState(() {
              _frames
                ..clear()
                ..addAll(frames);
            });
          }
        }
      } catch (e) {
        debugPrint('TRIM FRAME $index ERROR: $e');
      }
      if (!mounted) return;
    }
    if (frames.isNotEmpty || !mounted) return;
    try {
      final Object? raw = await _channel.invokeMethod('trimFrames', {
        'sourcePath': path,
        'assetId': widget.asset.id,
        'count': count,
      });
      if (!mounted || raw is! List) return;
      for (final Object? item in raw) {
        if (item is Uint8List && item.isNotEmpty) {
          frames.add(item);
        }
      }
      if (frames.isEmpty) return;
      setState(() {
        _frames
          ..clear()
          ..addAll(frames);
      });
    } catch (e) {
      debugPrint('TRIM FRAMES ERROR: $e');
    }
  }

  void _onTick() {
    final VideoPlayerController? player = _player;
    if (player == null || !player.value.isInitialized || !mounted) return;
    final int position = player.value.position.inMilliseconds;
    if (player.value.isPlaying && position >= _endMs) {
      player.seekTo(Duration(milliseconds: _startMs));
      player.play();
    }
    if (position != _positionMs || player.value.isPlaying != _playing) {
      setState(() {
        _positionMs = position;
        _playing = player.value.isPlaying;
      });
    }
  }

  Future<void> _togglePlay() async {
    final VideoPlayerController? player = _player;
    if (player == null || _saving) return;
    if (player.value.isPlaying) {
      await player.pause();
    } else {
      if (player.value.position.inMilliseconds < _startMs ||
          player.value.position.inMilliseconds >= _endMs) {
        await player.seekTo(Duration(milliseconds: _startMs));
      }
      await player.play();
    }
  }

  void _beginDrag(double x, double width) {
    final double startX = width * _startMs / _durationMs;
    final double endX = width * _endMs / _durationMs;
    if ((x - startX).abs() <= 28) {
      _drag = _Drag.start;
    } else if ((x - endX).abs() <= 28) {
      _drag = _Drag.end;
    } else if (x >= startX && x <= endX) {
      _drag = _Drag.window;
      _windowStartMs = _startMs;
      _dragOriginDx = x;
    } else {
      _drag = _Drag.none;
    }
    _player?.pause();
  }

  void _updateDrag(double x, double width) {
    if (width <= 0 || _drag == _Drag.none) return;
    final int ms = (x / width * _durationMs).round().clamp(0, _durationMs);
    if (_drag == _Drag.start) {
      final int next = ms.clamp(0, _endMs - _minGap);
      setState(() => _startMs = next);
      _player?.seekTo(Duration(milliseconds: next));
    } else if (_drag == _Drag.end) {
      final int next = ms.clamp(_startMs + _minGap, _durationMs);
      setState(() => _endMs = next);
      _player?.seekTo(Duration(milliseconds: next));
    } else if (_drag == _Drag.window) {
      final int length = _endMs - _startMs;
      final int delta = ((x - _dragOriginDx) / width * _durationMs).round();
      final int next = (_windowStartMs + delta).clamp(0, _durationMs - length);
      setState(() {
        _startMs = next;
        _endMs = next + length;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_ready) return;
    final File? file = await widget.asset.file;
    if (file == null) {
      AppToast.show('Video file not found');
      return;
    }
    setState(() => _saving = true);
    await _player?.pause();
    try {
      final String? output = await _channel.invokeMethod<String>('trim', {
        'sourcePath': file.path,
        'startMs': _startMs,
        'endMs': _endMs,
      });
      if (output == null || output.isEmpty) {
        AppToast.show('Could not trim video');
        return;
      }
      final String rawTitle = widget.asset.title ?? 'Video';
      final String stem = rawTitle.replaceAll(RegExp(r'\.[^.]+$'), '');
      final String title = 'Trim_$stem.mp4';
      String? folder = widget.asset.relativePath;
      if (folder != null && folder.isNotEmpty && !folder.endsWith('/')) {
        folder = '$folder/';
      }
      try {
        await PhotoManager.editor.saveVideo(
          File(output),
          title: title,
          relativePath: folder,
        );
      } catch (_) {
        await PhotoManager.editor.saveVideo(File(output), title: title);
      }
      try {
        await File(output).delete();
      } catch (_) {}
      try {
        if (Get.isRegistered<PhotosController>()) {
          await Get.find<PhotosController>().showNewPhotosNow();
        }
      } catch (_) {}
      AppToast.show('Trimmed video saved');
      if (mounted) Get.back();
    } on PlatformException catch (e) {
      AppToast.show(e.message ?? 'Could not trim video');
    } catch (e) {
      debugPrint('TRIM SAVE ERROR: $e');
      AppToast.show('Could not trim video');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _badge(int ms) {
    final Duration duration = Duration(milliseconds: ms < 0 ? 0 : ms);
    final String minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _clock(int ms) {
    final Duration duration = Duration(milliseconds: ms < 0 ? 0 : ms);
    final int minutes = duration.inMinutes.remainder(60);
    final String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? player = _player;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _saving ? null : () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _ready && !_saving ? _save : null,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  child: Center(
                    child: !_ready || player == null
                        ? const CircularProgressIndicator(color: Colors.white)
                        : AspectRatio(
                            aspectRatio: player.value.aspectRatio == 0
                                ? 1
                                : player.value.aspectRatio,
                            child: VideoPlayer(player),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _ready && !_saving ? _togglePlay : null,
                        icon: Icon(
                          _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    Text(
                      '${_clock(_positionMs)}  |  ${_clock(_durationMs)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final double startX = width * _startMs / _durationMs;
                    final double endX = width * _endMs / _durationMs;
                    return SizedBox(
                      height: 56,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          if (!_ready) return;
                          final double x = details.localPosition.dx;
                          if ((x - startX).abs() <= 22 || (x - endX).abs() <= 22) {
                            return;
                          }
                          final int ms = (x / width * _durationMs).round().clamp(0, _durationMs);
                          _player?.seekTo(Duration(milliseconds: ms));
                        },
                        onHorizontalDragStart: (details) {
                          _beginDrag(details.localPosition.dx, width);
                        },
                        onHorizontalDragUpdate: (details) {
                          _updateDrag(details.localPosition.dx, width);
                        },
                        onHorizontalDragEnd: (_) => _drag = _Drag.none,
                        child: _Filmstrip(
                          frames: _frames,
                          startX: startX,
                          endX: endX,
                          durationLabel: _badge(_endMs - _startMs),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Drag { none, start, end, window }

class _Filmstrip extends StatelessWidget {
  final List<Uint8List> frames;
  final double startX;
  final double endX;
  final String durationLabel;

  const _Filmstrip({
    required this.frames,
    required this.startX,
    required this.endX,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double selection = (endX - startX).clamp(36, width);
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.white),
                  if (frames.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final Uint8List frame in frames)
                          Expanded(
                            child: Image.memory(
                              frame,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                      ],
                    ),
                  if (startX > 1)
                    Positioned(
                      left: 0,
                      width: startX,
                      top: 0,
                      bottom: 0,
                      child: const ColoredBox(color: Color(0xAA000000)),
                    ),
                  if (endX < width - 1)
                    Positioned(
                      left: endX,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: const ColoredBox(color: Color(0xAA000000)),
                    ),
                ],
              ),
            ),
            Positioned(
              left: startX,
              width: selection,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              left: startX,
              top: 0,
              bottom: 0,
              child: const _EdgeHandle(left: true),
            ),
            Positioned(
              left: (endX - 18).clamp(0, width - 18),
              top: 0,
              bottom: 0,
              child: const _EdgeHandle(left: false),
            ),
            Positioned(
              left: (endX - 18 - 52).clamp(8, width - 60),
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A1A1A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    durationLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  final bool left;

  const _EdgeHandle({required this.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(
          left: left ? const Radius.circular(8) : Radius.zero,
          right: left ? Radius.zero : const Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(width: 1.4, height: 14, child: ColoredBox(color: Color(0xFF8E8E93))),
          SizedBox(width: 3),
          SizedBox(width: 1.4, height: 14, child: ColoredBox(color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }
}
