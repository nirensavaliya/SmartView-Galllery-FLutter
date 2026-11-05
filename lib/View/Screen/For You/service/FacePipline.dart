import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// ================================================================
// RESULT MODEL
// ================================================================

class FaceResult {
  /// L2-normalised MobileFaceNet embedding (192 values)
  final List<double> embedding;

  /// Small JPEG of the face (for the People cards)
  final Uint8List faceCrop;

  /// Face box area in pixels (analysis image)
  final double faceArea;

  /// Higher = better cover candidate (big + frontal face)
  final double quality;

  FaceResult({
    required this.embedding,
    required this.faceCrop,
    required this.faceArea,
    required this.quality,
  });
}

// ================================================================
// FACE PIPELINE
//   ML Kit (detect)  ->  square crop  ->  MobileFaceNet (embed)
//   Everything runs on-device. No network.
// ================================================================

class FacePipeline {
  /// One detector + one temp file per parallel worker ("slot"), so several
  /// photos can be analysed at the same time without touching each other.
  final Map<int, FaceDetector> _detectors = <int, FaceDetector>{};
  final Map<int, File> _tempFiles = <int, File>{};

  Interpreter? _interpreter;
  Future<void>? _modelLoading;

  static const String modelPath = 'assets/models/mobilefacenet.tflite';

  static const int inputSize = 112;
  static const int embeddingSize = 192;

  /// Long side of the image we analyse. 1024 is plenty for faces and
  /// ~10x faster / lighter than decoding the 12-50 MP original.
  static const int analysisSize = 800;

  /// Ignore tiny faces (bad embeddings, usually strangers in background).
  static const double minFacePixels = 48;

  /// Ignore strong profile / looking up-down faces (bad embeddings).
  static const double maxYawDegrees = 35;
  static const double maxPitchDegrees = 30;

  FacePipeline();

  FaceDetector _detectorFor(int slot) {
    return _detectors.putIfAbsent(
      slot,
      () => FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
          enableClassification: false,
          enableContours: false,
          enableTracking: false,
          minFaceSize: 0.06,
        ),
      ),
    );
  }

  /// Loads the face model now (call at app start) so the first photo
  /// does not have to wait for it.
  Future<void> warmUp() async {
    try {
      await _ensureModel();
    } catch (e) {
      debugPrint('FACE WARMUP ERROR = $e');
    }
  }

  // ==============================================================
  // MODEL
  // ==============================================================

  Future<void> _ensureModel() {
    return _modelLoading ??= _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);

      debugPrint(
        'FACE MODEL LOADED '
            'in=${_interpreter!.getInputTensor(0).shape} '
            'out=${_interpreter!.getOutputTensor(0).shape}',
      );
    } catch (e) {
      _modelLoading = null; // allow retry
      rethrow;
    }
  }

  Future<File> _getTempFile(int slot) async {
    final File? existing = _tempFiles[slot];

    if (existing != null) return existing;

    final Directory dir = await getTemporaryDirectory();

    final File file = File('${dir.path}/face_scan_tmp_$slot.jpg');

    _tempFiles[slot] = file;

    return file;
  }

  // ==============================================================
  // ANALYZE ONE PHOTO (returns every usable face)
  // ==============================================================

  Future<List<FaceResult>> analyzeAsset(AssetEntity asset, {int slot = 0}) async {
    await _ensureModel();

    final int w = asset.orientatedWidth;
    final int h = asset.orientatedHeight;

    if (w <= 0 || h <= 0) {
      return <FaceResult>[];
    }

    // Keep the real aspect ratio, otherwise the thumbnail gets centre-cropped
    // and faces at the edges are lost.
    final double scale = analysisSize / math.max(w, h);

    final ThumbnailSize size = scale >= 1
        ? ThumbnailSize(w, h)
        : ThumbnailSize((w * scale).round(), (h * scale).round());

    // Thumbnail is already rotated correctly (no EXIF problem), so ML Kit
    // boxes and our crop use the exact same pixel space.
    final Uint8List? bytes = await asset.thumbnailDataWithSize(
      size,
      format: ThumbnailFormat.jpeg,
      quality: 85,
    );

    if (bytes == null || bytes.isEmpty) {
      return <FaceResult>[];
    }

    final File tmp = await _getTempFile(slot);

    await tmp.writeAsBytes(bytes, flush: true);

    final List<Face> faces = await _detectorFor(slot).processImage(
      InputImage.fromFilePath(tmp.path),
    );

    if (faces.isEmpty) {
      return <FaceResult>[];
    }

    // ------------------------------------------------------------
    // Quality filter
    // ------------------------------------------------------------
    final List<Face> good = <Face>[];

    for (final Face face in faces) {
      final Rect box = face.boundingBox;

      if (math.min(box.width, box.height) < minFacePixels) continue;

      final double yaw = (face.headEulerAngleY ?? 0).abs();
      final double pitch = (face.headEulerAngleX ?? 0).abs();

      if (yaw > maxYawDegrees || pitch > maxPitchDegrees) continue;

      // Eyes are needed for alignment. No eyes = no reliable embedding.
      if (face.landmarks[FaceLandmarkType.leftEye] == null ||
          face.landmarks[FaceLandmarkType.rightEye] == null) {
        continue;
      }

      good.add(face);
    }

    if (good.isEmpty) {
      return <FaceResult>[];
    }

    final List<Face> unique = _dropOverlappingFaces(good);

    // ------------------------------------------------------------
    // Decode / crop / resize in a background isolate (UI stays smooth)
    // ------------------------------------------------------------
    final List<_PreparedFace?> prepared = await compute(
      _prepareFaces,
      _PrepareRequest(
        jpeg: bytes,
        boxes: unique
            .map((f) {
          final le = f.landmarks[FaceLandmarkType.leftEye]!.position;
          final re = f.landmarks[FaceLandmarkType.rightEye]!.position;

          return <double>[
            f.boundingBox.left,
            f.boundingBox.top,
            f.boundingBox.width,
            f.boundingBox.height,
            le.x.toDouble(),
            le.y.toDouble(),
            re.x.toDouble(),
            re.y.toDouble(),
          ];
        })
            .toList(),
      ),
    );

    // ------------------------------------------------------------
    // Run MobileFaceNet for each face
    // ------------------------------------------------------------
    final List<FaceResult> results = <FaceResult>[];

    for (int i = 0; i < unique.length && i < prepared.length; i++) {
      final _PreparedFace? p = prepared[i];

      if (p == null) continue;

      try {
        // original + mirrored face, averaged: more stable embedding
        final List<double> e1 = _embed(p.input);
        final List<double> e2 = _embed(p.inputFlip);

        final List<double> embedding = _l2Normalize(
          List<double>.generate(embeddingSize, (i) => e1[i] + e2[i]),
        );

        final Face face = unique[i];

        final double area = face.boundingBox.width * face.boundingBox.height;

        final double yaw = math.min((face.headEulerAngleY ?? 0).abs(), 45);

        results.add(
          FaceResult(
            embedding: embedding,
            faceCrop: p.crop,
            faceArea: area,
            quality: area * (1 - yaw / 90),
          ),
        );
      } catch (e) {
        debugPrint('FACE EMBED ERROR = $e');
      }
    }

    return results;
  }

  /// Keeps the larger box when ML Kit draws two boxes on one face.
  List<Face> _dropOverlappingFaces(List<Face> faces) {
    final List<Face> sorted = List<Face>.from(faces)
      ..sort((a, b) {
        final double areaA = a.boundingBox.width * a.boundingBox.height;
        final double areaB = b.boundingBox.width * b.boundingBox.height;
        return areaB.compareTo(areaA);
      });

    final List<Face> kept = <Face>[];

    for (final Face face in sorted) {
      final bool sameFace = kept.any(
        (other) => _boxesOverlap(other.boundingBox, face.boundingBox),
      );

      if (!sameFace) kept.add(face);
    }

    return kept;
  }

  bool _boxesOverlap(Rect a, Rect b) {
    final Rect overlap = a.intersect(b);

    if (overlap.width <= 0 || overlap.height <= 0) return false;

    final double overlapArea = overlap.width * overlap.height;
    final double union =
        a.width * a.height + b.width * b.height - overlapArea;

    if (union <= 0) return false;

    if (overlapArea / union >= 0.35) return true;

    final bool aSmaller = a.width * a.height <= b.width * b.height;
    final Rect smaller = aSmaller ? a : b;
    final Rect larger = aSmaller ? b : a;

    return larger.contains(smaller.center);
  }

  // ==============================================================
  // EMBEDDING
  // ==============================================================

  List<double> _embed(Float32List flat) {
    // Perf: hand the raw float32 bytes to TFLite. The old nested
    // [1][112][112][3] list made ~37,000 tiny objects per call and converted
    // every number one by one on the UI isolate. Same bytes, same result,
    // a fraction of the work.
    final Uint8List input = flat.buffer.asUint8List(
      flat.offsetInBytes,
      flat.lengthInBytes,
    );

    final List<List<double>> output = <List<double>>[
      List<double>.filled(embeddingSize, 0),
    ];

    _interpreter!.run(input, output);

    return _l2Normalize(List<double>.from(output[0]));
  }

  static List<double> _l2Normalize(List<double> v) {
    double sum = 0;

    for (final double x in v) {
      sum += x * x;
    }

    final double mag = math.sqrt(sum);

    if (mag == 0) return v;

    return v.map((double x) => x / mag).toList();
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  Future<void> dispose() async {
    for (final FaceDetector d in _detectors.values) {
      try {
        await d.close();
      } catch (_) {}
    }

    _detectors.clear();

    _interpreter?.close();
    _interpreter = null;
    _modelLoading = null;

    for (final File f in _tempFiles.values) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    _tempFiles.clear();
  }
}

// ================================================================
// BACKGROUND ISOLATE WORK  (pure Dart, no plugins)
// ================================================================

class _PrepareRequest {
  final Uint8List jpeg;

  /// each box = [left, top, width, height]
  final List<List<double>> boxes;

  const _PrepareRequest({required this.jpeg, required this.boxes});
}

class _PreparedFace {
  /// aligned 112*112*3 floats in [-1, 1]
  final Float32List input;

  /// same face mirrored (used to average the embedding)
  final Float32List inputFlip;

  /// small JPEG for UI
  final Uint8List crop;

  const _PreparedFace({
    required this.input,
    required this.inputFlip,
    required this.crop,
  });
}

List<_PreparedFace?> _prepareFaces(_PrepareRequest req) {
  final img.Image? image = img.decodeJpg(req.jpeg);

  if (image == null) {
    return List<_PreparedFace?>.filled(req.boxes.length, null);
  }

  return req.boxes.map((List<double> b) => _prepareOne(image, b)).toList();
}

_PreparedFace? _prepareOne(img.Image image, List<double> b) {
  // ---- UI crop (square around the box) --------------------------
  int side = (math.max(b[2], b[3]) * 1.3).round();

  side = math.min(side, math.min(image.width, image.height));

  if (side < 20) return null;

  final int cx0 = (b[0] + b[2] / 2 - side / 2)
      .round()
      .clamp(0, image.width - side)
      .toInt();
  final int cy0 = (b[1] + b[3] / 2 - side / 2)
      .round()
      .clamp(0, image.height - side)
      .toInt();

  final img.Image cropped = img.copyCrop(
    image,
    x: cx0,
    y: cy0,
    width: side,
    height: side,
  );

  final img.Image ui = img.copyResize(
    cropped,
    width: 160,
    height: 160,
    interpolation: img.Interpolation.average,
  );

  // ---- aligned model input (ArcFace 112 template) ----------------
  final Float32List? aligned = _alignFace(image, b[4], b[5], b[6], b[7], false);
  final Float32List? flipped = _alignFace(image, b[4], b[5], b[6], b[7], true);

  if (aligned == null || flipped == null) return null;

  return _PreparedFace(
    input: aligned,
    inputFlip: flipped,
    crop: Uint8List.fromList(img.encodeJpg(ui, quality: 85)),
  );
}

/// Warps the face so both eyes land on the standard 112x112 positions
/// (left eye 38.3,51.7  right eye 73.5,51.5). This removes head tilt and
/// scale differences, which is what MobileFaceNet was trained on.
///
/// Done manually with a similarity transform + bilinear sampling, so there is
/// no rotation-direction guesswork.
Float32List? _alignFace(
    img.Image image,
    double x1,
    double y1,
    double x2,
    double y2,
    bool mirror,
    ) {
  // make sure (x1,y1) is the eye on the LEFT side of the picture
  if (x1 > x2) {
    final double tx = x1, ty = y1;
    x1 = x2;
    y1 = y2;
    x2 = tx;
    y2 = ty;
  }

  final double dx = x2 - x1;
  final double dy = y2 - y1;
  final double dist = math.sqrt(dx * dx + dy * dy);

  if (dist < 8) return null; // eyes too close = unreliable

  const double outEyeDist = 35.24; // 73.53 - 38.29
  const double outCx = 55.91;
  const double outCy = 51.60;

  final double s = dist / outEyeDist; // input pixels per output pixel
  final double theta = math.atan2(dy, dx);
  final double cosT = math.cos(theta);
  final double sinT = math.sin(theta);

  final double inCx = (x1 + x2) / 2;
  final double inCy = (y1 + y2) / 2;

  final int n = FacePipeline.inputSize;

  final Float32List out = Float32List(n * n * 3);

  final int maxX = image.width - 1;
  final int maxY = image.height - 1;

  int idx = 0;

  for (int v = 0; v < n; v++) {
    for (int u = 0; u < n; u++) {
      final int uu = mirror ? (n - 1 - u) : u;

      final double ox = (uu - outCx) * s;
      final double oy = (v - outCy) * s;

      final double sx = inCx + cosT * ox - sinT * oy;
      final double sy = inCy + sinT * ox + cosT * oy;

      final double fx = sx.clamp(0.0, maxX.toDouble()).toDouble();
      final double fy = sy.clamp(0.0, maxY.toDouble()).toDouble();

      final int x0 = fx.floor();
      final int y0 = fy.floor();
      final int x1i = math.min(x0 + 1, maxX);
      final int y1i = math.min(y0 + 1, maxY);

      final double wx = fx - x0;
      final double wy = fy - y0;

      final img.Pixel p00 = image.getPixel(x0, y0);
      final img.Pixel p10 = image.getPixel(x1i, y0);
      final img.Pixel p01 = image.getPixel(x0, y1i);
      final img.Pixel p11 = image.getPixel(x1i, y1i);

      double mix(num a, num b, num c, num d) {
        final double top = a * (1 - wx) + b * wx;
        final double bottom = c * (1 - wx) + d * wx;

        return top * (1 - wy) + bottom * wy;
      }

      out[idx++] = (mix(p00.r, p10.r, p01.r, p11.r) - 127.5) / 128.0;
      out[idx++] = (mix(p00.g, p10.g, p01.g, p11.g) - 127.5) / 128.0;
      out[idx++] = (mix(p00.b, p10.b, p01.b, p11.b) - 127.5) / 128.0;
    }
  }

  return out;
}
