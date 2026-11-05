import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class SmartSearchService {
  SmartSearchService._();

  static final SmartSearchService instance = SmartSearchService._();

  static const int _indexVersion = 3;
  static const String _versionKey = 'smartSearchIndexVersion';
  static const String _labelsKey = 'smartSearchLabels';
  static const String _ocrKey = 'smartSearchOcrText';
  static const double _confidenceThreshold = 0.5;
  final GetStorage _box = GetStorage();
  ImageLabeler? _labeler;
  TextRecognizer? _textRecognizer;

  final Map<String, List<String>> _labelsByAsset = {};
  final Map<String, String> _ocrByAsset = {};

  bool _indexing = false;
  bool _cancelRequested = false;
  bool _loaded = false;

  bool get isIndexing => _indexing;

  int get indexedCount => _labelsByAsset.length;

  Future<void> init() async {
    if (!_loaded) {
      _migrateIfNeeded();
      _loadCache();
      _loaded = true;
    }

    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(
        confidenceThreshold: _confidenceThreshold,
      ),
    );
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  void _migrateIfNeeded() {
    final storedVersion = _box.read(_versionKey);
    final version = storedVersion is int
        ? storedVersion
        : int.tryParse(storedVersion?.toString() ?? '') ?? 0;

    if (version >= _indexVersion) return;

    debugPrint(
      'SmartSearch: migrating index v$version → v$_indexVersion (OCR rebuild)',
    );
    _box.remove(_ocrKey);
    _box.write(_versionKey, _indexVersion);
  }

  void _loadCache() {
    final labelsData = _box.read(_labelsKey);
    if (labelsData is Map) {
      _labelsByAsset
        ..clear()
        ..addAll(
          labelsData.map(
            (key, value) => MapEntry(
              key.toString(),
              (value is List)
                  ? value.map((e) => e.toString().toLowerCase()).toList()
                  : <String>[],
            ),
          ),
        );
    }

    final ocrData = _box.read(_ocrKey);
    if (ocrData is Map) {
      _ocrByAsset
        ..clear()
        ..addAll(
          ocrData.map(
            (key, value) => MapEntry(
              key.toString(),
              value.toString().toLowerCase().trim(),
            ),
          ),
        );
    }
  }

  Future<void> _persist() async {
    await _box.write(_labelsKey, _labelsByAsset);
    await _box.write(_ocrKey, _ocrByAsset);
    await _box.write(_versionKey, _indexVersion);
  }

  bool _needsIndex(AssetEntity asset) {
    if (asset.type != AssetType.image) return false;

    final hasLabels = _labelsByAsset.containsKey(asset.id);
    final hasOcr = _ocrByAsset.containsKey(asset.id);
    return !hasLabels || !hasOcr;
  }

  Future<void> indexAssets(
    List<AssetEntity> assets, {
    void Function(int done, int total)? onProgress,
  }) async {
    await init();
    if (_indexing) return;

    final images = assets.where(_needsIndex).toList();

    if (images.isEmpty) {
      onProgress?.call(0, 0);
      return;
    }

    _indexing = true;
    _cancelRequested = false;

    try {
      final total = images.length;
      var done = 0;

      onProgress?.call(done, total);
      debugPrint('SmartSearch: indexing $total image(s)…');

      for (final asset in images) {
        if (_cancelRequested) break;

        try {
          final result = await _analyzeAsset(asset);
          _labelsByAsset[asset.id] = result.labels;
          _ocrByAsset[asset.id] = result.ocrText;

          if (result.ocrText.isNotEmpty) {
            debugPrint(
              'SmartSearch OCR [${asset.title}]: '
              '${result.ocrText.substring(0, result.ocrText.length.clamp(0, 80))}',
            );
          }
        } catch (e, st) {
          debugPrint('SmartSearch analyze error [${asset.id}]: $e\n$st');
          _labelsByAsset.putIfAbsent(asset.id, () => const []);
        }

        done++;

        if (done % 3 == 0 || done == total) {
          await _persist();
          onProgress?.call(done, total);
        }

        await Future<void>.delayed(Duration.zero);
      }

      await _persist();
      onProgress?.call(done, total);
      debugPrint('SmartSearch: indexing finished ($done / $total)');
    } finally {
      _indexing = false;
    }
  }

  void cancelIndexing() {
    _cancelRequested = true;
  }

  Future<({List<String> labels, String ocrText})> _analyzeAsset(
    AssetEntity asset,
  ) async {
    final labeler = _labeler;
    final recognizer = _textRecognizer;
    if (labeler == null || recognizer == null) {
      return (labels: const <String>[], ocrText: '');
    }

    final labels = await _labelFromThumbnail(asset, labeler);

    final ocrText = await _ocrFromBestSource(asset, recognizer);

    return (labels: labels, ocrText: ocrText);
  }

  Future<List<String>> _labelFromThumbnail(
    AssetEntity asset,
    ImageLabeler labeler,
  ) async {
    final bytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize(768, 768),
      quality: 85,
    );
    if (bytes == null || bytes.isEmpty) return const [];

    final temp = await _writeTempJpeg(asset.id, 'lbl', bytes);
    try {
      final inputImage = InputImage.fromFilePath(temp.path);
      final results = await labeler.processImage(inputImage);
      return results
          .map((label) => label.label.toLowerCase().trim())
          .where((label) => label.isNotEmpty)
          .toList();
    } finally {
      await _deleteQuietly(temp);
    }
  }

  Future<String> _ocrFromBestSource(
    AssetEntity asset,
    TextRecognizer recognizer,
  ) async {
    try {
      final origin = await asset.originFile;
      final file = origin ?? await asset.file;
      if (file != null && await file.exists()) {
        final inputImage = InputImage.fromFilePath(file.path);
        final recognized = await recognizer.processImage(inputImage);
        final text = _normalizeOcr(recognized.text);
        if (text.isNotEmpty) return text;
      }
    } catch (e) {
      debugPrint('SmartSearch OCR file path failed [${asset.id}]: $e');
    }

    try {
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(1600, 1600),
        quality: 95,
      );
      if (bytes == null || bytes.isEmpty) return '';

      final temp = await _writeTempJpeg(asset.id, 'ocr', bytes);
      try {
        final inputImage = InputImage.fromFilePath(temp.path);
        final recognized = await recognizer.processImage(inputImage);
        return _normalizeOcr(recognized.text);
      } finally {
        await _deleteQuietly(temp);
      }
    } catch (e) {
      debugPrint('SmartSearch OCR thumbnail failed [${asset.id}]: $e');
      return '';
    }
  }

  String _normalizeOcr(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<File> _writeTempJpeg(
    String assetId,
    String suffix,
    List<int> bytes,
  ) async {
    final dir = await getTemporaryDirectory();
    final safeId = assetId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/smart_search_${suffix}_$safeId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  bool assetMatchesQuery(AssetEntity asset, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final title = (asset.title ?? '').toLowerCase();
    if (title.contains(normalized)) return true;

    final terms = _expandQuery(normalized);
    return _matchesTerms(
      labels: _labelsByAsset[asset.id] ?? const [],
      ocrText: _ocrByAsset[asset.id] ?? '',
      terms: terms,
    );
  }

  bool _matchesTerms({
    required List<String> labels,
    required String ocrText,
    required List<String> terms,
  }) {
    for (final term in terms) {
      if (term.isEmpty) continue;

      if (ocrText.contains(term)) return true;

      for (final label in labels) {
        if (label.contains(term) || term.contains(label)) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> labelsFor(String assetId) {
    return List<String>.from(_labelsByAsset[assetId] ?? const []);
  }

  String ocrTextFor(String assetId) {
    return _ocrByAsset[assetId] ?? '';
  }

  List<String> _expandQuery(String query) {
    const synonyms = <String, List<String>>{
      'car': [
        'car',
        'vehicle',
        'automobile',
        'sedan',
        'suv',
        'truck',
        'van',
        'jeep',
        'motor vehicle',
        'land vehicle',
        'sports car',
      ],
      'cars': [
        'car',
        'vehicle',
        'automobile',
        'sedan',
        'suv',
        'truck',
        'van',
        'jeep',
      ],
      'beach': [
        'beach',
        'ocean',
        'sea',
        'coast',
        'shore',
        'sand',
        'seaside',
        'seashore',
      ],
      'document': [
        'document',
        'paper',
        'text',
        'screenshot',
        'book',
        'newspaper',
        'letter',
        'page',
        'receipt',
        'note',
        'notebook',
      ],
      'task': [
        'task',
        'tasks',
        'todo',
        'to-do',
        'to do',
        'checklist',
        'check list',
        'reminder',
        'planner',
        'assignment',
      ],
      'tasks': [
        'task',
        'tasks',
        'todo',
        'to-do',
        'to do',
        'checklist',
        'reminder',
        'planner',
        'assignment',
      ],
      'todo': [
        'todo',
        'to-do',
        'to do',
        'task',
        'tasks',
        'checklist',
        'reminder',
        'planner',
      ],
      'dog': ['dog', 'puppy', 'canine', 'pet'],
      'cat': ['cat', 'kitten', 'feline', 'pet'],
      'person': ['person', 'people', 'human', 'face', 'man', 'woman', 'child'],
      'people': ['person', 'people', 'human', 'crowd', 'group'],
      'food': ['food', 'meal', 'dish', 'cuisine', 'snack'],
      'flower': ['flower', 'plant', 'petal', 'rose', 'floral'],
      'mountain': ['mountain', 'hill', 'peak', 'cliff'],
      'building': ['building', 'architecture', 'house', 'skyscraper', 'tower'],
      'bike': ['bicycle', 'bike', 'cycling', 'motorcycle', 'scooter'],
      'bicycle': ['bicycle', 'bike', 'cycling'],
      'phone': ['mobile phone', 'smartphone', 'phone', 'cellphone'],
      'selfie': ['selfie', 'face', 'person', 'portrait'],
      'diamond': ['diamond', 'gem', 'jewel', 'jewelry', 'jewellery'],
    };

    return synonyms[query] ?? [query];
  }

  Future<void> dispose() async {
    cancelIndexing();
    await _labeler?.close();
    await _textRecognizer?.close();
    _labeler = null;
    _textRecognizer = null;
  }
}
