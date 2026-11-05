import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodCall;
import 'package:gallery_photos/View/Screen/For%20You/service/FacePipline.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';


class FacePerson {
  final String id;

  String name;
  List<double> embedding;
  int faceCount;
  final List<String> assetIds;
  String coverAssetId;
  String coverFaceBase64;
  double coverQuality;
  List<List<double>> exemplars;

  FacePerson({
    required this.id,
    required this.name,
    required this.embedding,
    required this.assetIds,
    required this.coverAssetId,
    this.coverFaceBase64 = '',
    this.faceCount = 1,
    this.coverQuality = 0,
    List<List<double>>? exemplars,
  }) : exemplars = exemplars ?? <List<double>>[List<double>.from(embedding)];

  bool get hasCustomName => !name.startsWith('Person ');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'embedding': embedding
          .map((e) => double.parse(e.toStringAsFixed(4)))
          .toList(),
      'faceCount': faceCount,
      'assetIds': assetIds,
      'coverAssetId': coverAssetId,
      'coverFaceBase64': coverFaceBase64,
      'coverQuality': coverQuality,
      'exemplars': exemplars
          .map(
            (e) => e.map((x) => double.parse(x.toStringAsFixed(3))).toList(),
      )
          .toList(),
    };
  }

  factory FacePerson.fromJson(Map<String, dynamic> json) {
    final List<String> ids =
        (json['assetIds'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];

    return FacePerson(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Person',
      embedding:
      (json['embedding'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList() ??
          <double>[],
      faceCount: (json['faceCount'] as num?)?.toInt() ?? ids.length,
      assetIds: ids,
      coverAssetId: json['coverAssetId']?.toString() ?? '',
      coverFaceBase64: json['coverFaceBase64']?.toString() ?? '',
      coverQuality: (json['coverQuality'] as num?)?.toDouble() ?? 0,
      exemplars: (json['exemplars'] as List?)
          ?.map(
            (e) => (e as List).map((x) => (x as num).toDouble()).toList(),
      )
          .toList(),
    );
  }
}

class FaceGroupController extends GetxController {
  final bool background;

  FaceGroupController({this.background = false});

  final RxList<FacePerson> people = <FacePerson>[].obs;

  final FacePipeline facePipeline = FacePipeline();

  final RxBool isScanning = false.obs;
  final RxBool hasScanned = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString status = ''.obs;

  final Map<String, AssetEntity> _assetCache = <String, AssetEntity>{};
  
  final Set<String> _processedIds = <String>{};

  Future<void>? _ready;

  Future<void> get ready => _ready ?? Future<void>.value();
  
  final Map<String, Uint8List> _coverCache = <String, Uint8List>{};

  int _lastScannedLength = -1;
  bool _disposed = false;

  static const String _peopleKey = 'face_people_groups_v3';
  static const String _processedKey = 'face_processed_assets_v3';
  static const List<String> _oldKeys = <String>[
    'face_people_groups',
    'face_people_groups_v2',
    'face_processed_assets_v2',
  ];
  
  static const double matchDistance = 0.48;
  static const double centroidUpdateRatio = 0.80;
  static const double exemplarBonus = 0.06;
  static const double maxCentroidDistance = 0.60;
  static const double mergeDistance = 0.44;

  /// Two boxes of the same face in one photo. Different people in a group
  /// photo sit farther apart than this.
  static const double duplicateFaceDistance = 0.50;
  static const int maxExemplars = 6;
  static const int minPhotosToShow = 1;
  static const int _saveEvery = 60;
  static const int _uiRefreshEvery = 4;
  static const int _parallelPhotos = 3;
  static const int _foregroundParallelPhotos = 2;
  static const Duration _foregroundPause = Duration(milliseconds: 40);
  static const Duration _startDelay = Duration(seconds: 8);
  
  static const String _lockKey = 'face_scan_lock_v1';
  static const String _stampKey = 'face_saved_at_v1';
  static const int _lockTimeoutMs = 90000;

  final String _owner =
      '${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(Object())}';

  Timer? _lockTimer;
  bool _lockBusy = false;
  int? _myStamp;
  DateTime? _deadline;

  bool _rescanPending = false;
  Timer? _changeDebounce;
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _watching = false;

  @override
  void onInit() {
    super.onInit();

    _ready = loadSavedPeople().whenComplete(() => _readyDone = true);
  }
  

  Future<void> loadSavedPeople() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      _myStamp = prefs.getInt(_stampKey);

      for (final String k in _oldKeys) {
        if (prefs.containsKey(k)) await prefs.remove(k);
      }

      final String? raw = prefs.getString(_peopleKey);

      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> data = jsonDecode(raw);

        people.assignAll(
          data
              .whereType<Map>()
              .map(
                (item) => FacePerson.fromJson(Map<String, dynamic>.from(item)),
          )
              .where((p) => p.embedding.isNotEmpty)
              .toList(),
        );

        final int beforeMerge = people.length;
        _mergeSimilarPeople();
        if (people.length != beforeMerge) {
          people.refresh();
          await _save();
        }
      }

      _processedIds
        ..clear()
        ..addAll(prefs.getStringList(_processedKey) ?? const <String>[]);

      hasScanned.value = people.isNotEmpty;

      debugPrint(
        'FACE RESTORED people=${people.length} '
            'processed=${_processedIds.length}',
      );
    } catch (e) {
      debugPrint('FACE RESTORE ERROR = $e');
    }
  }

  Future<void> _save() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _peopleKey,
        jsonEncode(people.map((p) => p.toJson()).toList()),
      );

      await prefs.setStringList(_processedKey, _processedIds.toList());

      final int stamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setInt(_stampKey, stamp);

      _myStamp = stamp;
    } catch (e) {
      debugPrint('FACE SAVE ERROR = $e');
    }
  }
  
  bool shouldScan(List<AssetEntity> assets) {
    if (isScanning.value || assets.isEmpty) return false;

    return assets.length != _lastScannedLength;
  }

  List<FacePerson> get visiblePeople {
    final List<FacePerson> list = people
        .where((p) => p.assetIds.length >= minPhotosToShow)
        .toList();

    list.sort((a, b) => b.assetIds.length.compareTo(a.assetIds.length));

    return list;
  }

  bool _wholeScanStarted = false;

  bool get needsWholeScan => !_wholeScanStarted && !isScanning.value;

  Future<List<AssetEntity>>? _assetsLoading;
  
  Future<void> get assetsReady {
    _assetsLoading ??= _loadAllAssets();

    return _assetsLoading!.then((_) {});
  }

  Future<List<AssetEntity>> _loadAllAssets() async {
    final List<AssetEntity> assets = <AssetEntity>[];

    try {
      await _ready;

      final PermissionState permission = background
          ? await PhotoManager.getPermissionState(
              requestOption: const PermissionRequestOption(),
            )
          : await PhotoManager.requestPermissionExtend();

      if (!permission.hasAccess) {
        status.value = 'Photo permission needed';
        _assetsLoading = null; 
        return assets;
      }

      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (paths.isEmpty) return assets;

      final AssetPathEntity all = paths.first;

      final int total = await all.assetCountAsync;

      const int page = 1000;

      for (int start = 0; start < total; start += page) {
        final List<AssetEntity> chunk = await all.getAssetListRange(
          start: start,
          end: math.min(start + page, total),
        );

        assets.addAll(chunk);

        for (final AssetEntity a in chunk) {
          _assetCache[a.id] = a;
        }

        if (start == 0) people.refresh();
      }

      people.refresh();
    } catch (e) {
      _assetsLoading = null;
      debugPrint('FACE ASSET LOAD ERROR = $e');
    }

    return assets;
  }
  
  Future<void> startBackgroundScan() async {
    if (!background) {
      await Future<void>.delayed(_startDelay);

      if (_disposed) return;

      startWatchingGallery();
    }

    if (_disposed) return;

    facePipeline.warmUp();

    if (_wholeScanStarted || isScanning.value) return;

    await scanWholeGallery();
  }

  Future<void> runBackgroundJob({required Duration maxDuration}) async {
    facePipeline.warmUp();
    _deadline = DateTime.now().add(maxDuration);
    await _ready;
    await scanWholeGallery();
  }


  Future<void> scanWholeGallery() async {
    if (isScanning.value || _wholeScanStarted) return;
    _wholeScanStarted = true;
    await _ready;
    if (_disposed) return;

    try {
      _assetsLoading ??= _loadAllAssets();
      final List<AssetEntity> assets = await _assetsLoading!;
      if (assets.isEmpty) {
        _wholeScanStarted = false;
        return;
      }

      await scanGallery(assets);

      if (_lockBusy) {
        _scheduleRetry();
        return;
      }

      _retryCount = 0;

      if (_rescanPending) {
        _rescanPending = false;
        await scanRecent();
      }
    } catch (e) {
      _wholeScanStarted = false;
      debugPrint('FACE WHOLE SCAN ERROR = $e');
    }
  }

  void _scheduleRetry() {
    if (background || _disposed || _retryCount >= 30) {
      _wholeScanStarted = false;
      return;
    }

    _retryCount++;

    _retryTimer?.cancel();

    _retryTimer = Timer(const Duration(seconds: 20), () async {
      if (_disposed) return;
      _wholeScanStarted = false;
      await _syncFromDisk();
      _assetsLoading = null;
      await scanWholeGallery();
    });
  }

  void startWatchingGallery() {
    if (_watching || _disposed) return;

    _watching = true;

    try {
      PhotoManager.addChangeCallback(_onGalleryChanged);
      PhotoManager.startChangeNotify();
    } catch (e) {
      debugPrint('FACE WATCH ERROR = $e');
    }
  }

  void _onGalleryChanged(MethodCall call) {
    if (_disposed) return;

    
    _changeDebounce?.cancel();

    _changeDebounce = Timer(const Duration(seconds: 3), scanRecent);
  }

  Future<void> scanRecent() async {
    if (_disposed) return;

    if (isScanning.value || _scanBusy || !_readyDone) {
      _rescanPending = true;
      return;
    }

    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (paths.isEmpty) return;

      final List<AssetEntity> recent = await paths.first.getAssetListRange(
        start: 0,
        end: 200,
      );
      await scanGallery(recent);
      if (_lockBusy) return;
      if (_rescanPending) {
        _rescanPending = false;
        await scanRecent();
      }
    } catch (e) {
      debugPrint('FACE RECENT SCAN ERROR = $e');
    }
  }

  bool _readyDone = false;

  Future<bool> _acquireLock() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      final String? raw = prefs.getString(_lockKey);

      if (raw != null && raw.contains('|')) {
        final List<String> parts = raw.split('|');
        final int at = int.tryParse(parts.last) ?? 0;

        final bool fresh =
            DateTime.now().millisecondsSinceEpoch - at < _lockTimeoutMs;

        if (fresh && parts.first != _owner) return false;
      }

      await _touchLock();

      _lockTimer?.cancel();
      _lockTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _touchLock(),
      );

      return true;
    } catch (e) {
      debugPrint('FACE LOCK ERROR = $e');
      return true; 
    }
  }

  Future<void> _touchLock() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _lockKey,
        '$_owner|${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {}
  }

  Future<void> _releaseLock() async {
    _lockTimer?.cancel();
    _lockTimer = null;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String? raw = prefs.getString(_lockKey);

      if (raw != null && raw.startsWith('$_owner|')) {
        await prefs.remove(_lockKey);
      }
    } catch (_) {}
  }
  
  Future<void> _syncFromDisk() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      final int? diskStamp = prefs.getInt(_stampKey);

      if (diskStamp != null && diskStamp != _myStamp) {
        await loadSavedPeople();
        people.refresh();
      }
    } catch (e) {
      debugPrint('FACE SYNC ERROR = $e');
    }
  }
  
  Future<void> refreshFromBackgroundJob() async {
    if (_disposed || background || isScanning.value || !_readyDone) return;
    await _syncFromDisk();
    await scanRecent();
  }

  bool _scanBusy = false;

  Future<void> scanGallery(List<AssetEntity> assets) async {
    if (isScanning.value || _scanBusy || assets.isEmpty) return;

    _scanBusy = true;

    try {
      await _ready;
      if (_disposed) return;
      _lockBusy = !(await _acquireLock());
      if (_lockBusy) return;

      try {
        await _syncFromDisk();

        await _scanGalleryLocked(assets);
      } finally {
        await _releaseLock();
      }
    } finally {
      _scanBusy = false;
    }
  }

  Future<void> _scanGalleryLocked(List<AssetEntity> assets) async {
    if (isScanning.value || assets.isEmpty) return;
    if (_disposed) return;
    _lastScannedLength = assets.length;
    
    for (final AssetEntity a in assets) {
      _assetCache[a.id] = a;
    }

    final List<AssetEntity> todo = assets
        .where(
          (a) => a.type == AssetType.image && !_processedIds.contains(a.id),
    )
        .toList();

    if (todo.isEmpty) {
      final int before = people.length;

      _mergeSimilarPeople();

      if (people.length != before) {
        people.sort((a, b) => b.assetIds.length.compareTo(a.assetIds.length));

        await _save();
      }

      hasScanned.value = true;
      status.value = '${people.length} people found';
      people.refresh();
      return;
    }

    isScanning.value = true;
    progress.value = 0;
    status.value = 'Scanning 0 / ${todo.length}';

    try {
      int done = 0;
      int sinceSave = 0;
      int cursor = 0;

      Future<void> worker(int slot) async {
        while (!_disposed) {
          final DateTime? stopAt = _deadline;
          
          if (stopAt != null && DateTime.now().isAfter(stopAt)) break;

          final int index = cursor++;

          if (index >= todo.length) break;

          final AssetEntity asset = todo[index];

          try {
            final List<FaceResult> faces = await facePipeline.analyzeAsset(asset, slot: slot);

            _applyFaces(asset, faces);

            _processedIds.add(asset.id);
          } catch (e) {
            debugPrint('FACE ASSET ERROR ${asset.id} = $e');
          }

          done++;
          sinceSave++;

          if (done % 100 == 0) _mergeSimilarPeople();

          if (done % _uiRefreshEvery == 0 || done == todo.length) {
            progress.value = done / todo.length;
            status.value = 'Scanning $done / ${todo.length}';

            people.refresh();
          }

          if (sinceSave >= _saveEvery) {
            sinceSave = 0;
            await _save(); 
          }
          
          await Future<void>.delayed(
            background ? Duration.zero : _foregroundPause,
          );
        }
      }

      await Future.wait<void>(
        List<Future<void>>.generate(
          background ? _parallelPhotos : _foregroundParallelPhotos,
          worker,
        ),
      );

      _mergeSimilarPeople();

      people.sort((a, b) => b.assetIds.length.compareTo(a.assetIds.length));

      await _save();

      hasScanned.value = true;
      status.value = '${people.length} people found';
      people.refresh();

      debugPrint('FACE SCAN COMPLETE people=${people.length}');
    } catch (e, stack) {
      debugPrint('FACE SCAN ERROR = $e');
      debugPrint(stack.toString());
    } finally {
      isScanning.value = false;
    }
  }
  

  void _applyFaces(AssetEntity asset, List<FaceResult> faces) {
    if (faces.isEmpty) return;

    faces.sort((a, b) => b.quality.compareTo(a.quality));
    
    final Set<String> usedInThisPhoto = <String>{};

    for (final FaceResult face in faces) {
      if (_isDuplicateFaceBox(face, usedInThisPhoto)) continue;

      final FacePerson person = _assignFace(asset, face, usedInThisPhoto);

      usedInThisPhoto.add(person.id);
    }
  }

  /// A second box of a face already taken from this photo.
  bool _isDuplicateFaceBox(FaceResult face, Set<String> usedIds) {
    for (final FacePerson person in people) {
      if (!usedIds.contains(person.id)) continue;

      final double distance = _cosineDistance(face.embedding, person.embedding);

      if (distance <= duplicateFaceDistance) return true;
    }

    return false;
  }



  FacePerson _assignFace(
      AssetEntity asset,
      FaceResult face,
      Set<String> excludedPersonIds,
      ) {
    FacePerson? best;
    double bestScore = double.infinity;
    double bestCentroid = double.infinity;

    for (final FacePerson person in people) {
      if (excludedPersonIds.contains(person.id)) continue;

      final double dCentroid = _cosineDistance(face.embedding, person.embedding);

      if (dCentroid > maxCentroidDistance) continue;

      final double dLook =
          _nearestExemplarDistance(face.embedding, person) + exemplarBonus;

      final double score = math.min(dCentroid, dLook);

      if (score < bestScore) {
        bestScore = score;
        bestCentroid = dCentroid;
        best = person;
      }
    }

    debugPrint(
      'FACE MATCH score=${bestScore.toStringAsFixed(3)} '
          '${bestScore <= matchDistance ? "-> ${best?.name}" : "-> NEW"}',
    );

    if (best != null && bestScore <= matchDistance) {
      if (!best.assetIds.contains(asset.id)) {
        best.assetIds.add(asset.id);
      }

      if (bestCentroid <= matchDistance * centroidUpdateRatio) {
        _addToCentroid(best, face.embedding);
      }

      _addExemplar(best, face.embedding);

      if (face.quality > best.coverQuality || best.coverFaceBase64.isEmpty) {
        best.coverFaceBase64 = base64Encode(face.faceCrop);
        best.coverAssetId = asset.id;
        best.coverQuality = face.quality;
      }

      return best;
    }

    final FacePerson created = FacePerson(
      id: '${DateTime.now().microsecondsSinceEpoch}_${people.length}',
      name: 'Person ${_nextPersonNumber()}',
      embedding: List<double>.from(face.embedding),
      faceCount: 1,
      assetIds: <String>[asset.id],
      coverAssetId: asset.id,
      coverFaceBase64: base64Encode(face.faceCrop),
      coverQuality: face.quality,
    );

    people.add(created);

    return created;
  }

  double _nearestExemplarDistance(List<double> e, FacePerson p) {
    double best = double.infinity;

    for (final List<double> x in p.exemplars) {
      final double d = _cosineDistance(e, x);

      if (d < best) best = d;
    }

    return best;
  }

  double _nearestPairDistance(FacePerson a, FacePerson b) {
    double best = double.infinity;

    for (final List<double> x in a.exemplars) {
      final double d = _nearestExemplarDistance(x, b);

      if (d < best) best = d;
    }

    return best;
  }

  void _addExemplar(FacePerson p, List<double> e) {
    if (e.length != p.embedding.length) return;

    final double nearest = _nearestExemplarDistance(e, p);

    if (nearest < 0.10) return;

    if (p.exemplars.length < maxExemplars) {
      p.exemplars.add(List<double>.from(e));
      return;
    }

    int dropIndex = 0;
    double dropDistance = double.infinity;

    for (int i = 0; i < p.exemplars.length; i++) {
      for (int j = 0; j < p.exemplars.length; j++) {
        if (i == j) continue;

        final double d = _cosineDistance(p.exemplars[i], p.exemplars[j]);

        if (d < dropDistance) {
          dropDistance = d;
          dropIndex = i;
        }
      }
    }

    if (nearest > dropDistance) {
      p.exemplars[dropIndex] = List<double>.from(e);
    }
  }

  int _nextPersonNumber() {
    int max = 0;

    for (final FacePerson p in people) {
      if (p.name.startsWith('Person ')) {
        final int? n = int.tryParse(p.name.substring(7));

        if (n != null && n > max) max = n;
      }
    }

    return max + 1;
  }
  
  void _addToCentroid(FacePerson person, List<double> embedding) {
    if (person.embedding.length != embedding.length) return;

    final int n = person.faceCount;

    final List<double> merged = List<double>.filled(embedding.length, 0);

    for (int i = 0; i < merged.length; i++) {
      merged[i] = (person.embedding[i] * n + embedding[i]) / (n + 1);
    }

    person.embedding = _normalize(merged);
    person.faceCount = n + 1;
  }
  
  void _mergeSimilarPeople() {
    for (int pass = 0; pass < 3; pass++) {
      bool changed = false;

      int i = 0;

      while (i < people.length) {
        final FacePerson a = people[i];

        int j = i + 1;

        while (j < people.length) {
          final FacePerson b = people[j];

          if (_canMerge(a, b)) {
            _mergeInto(a, b);

            people.removeAt(j);

            changed = true;
          } else {
            j++;
          }
        }

        i++;
      }

      if (!changed) break;
    }
  }

  bool _canMerge(FacePerson a, FacePerson b) {
    if (a.hasCustomName && b.hasCustomName && a.name != b.name) {
      return false;
    }

    final double dCentroid = _cosineDistance(a.embedding, b.embedding);

    if (dCentroid > maxCentroidDistance) return false;

    final double score = math.min(
      dCentroid,
      _nearestPairDistance(a, b) + exemplarBonus,
    );

    final bool sharePhoto = b.assetIds.any(a.assetIds.contains);

    if (sharePhoto) {
      return score <= duplicateFaceDistance;
    }

    return score <= mergeDistance;
  }

  void _mergeInto(FacePerson a, FacePerson b) {
    for (final String id in b.assetIds) {
      if (!a.assetIds.contains(id)) a.assetIds.add(id);
    }

    final int total = a.faceCount + b.faceCount;

    final List<double> merged = List<double>.filled(a.embedding.length, 0);

    for (int k = 0; k < merged.length; k++) {
      merged[k] =
          (a.embedding[k] * a.faceCount + b.embedding[k] * b.faceCount) / total;
    }

    a.embedding = _normalize(merged);
    a.faceCount = total;

    for (final List<double> e in b.exemplars) {
      _addExemplar(a, e);
    }

    if (!a.hasCustomName && b.hasCustomName) {
      a.name = b.name;
    }

    if (b.coverQuality > a.coverQuality) {
      a.coverFaceBase64 = b.coverFaceBase64;
      a.coverAssetId = b.coverAssetId;
      a.coverQuality = b.coverQuality;
    }
  }

  Future<void> mergePeople(FacePerson keep, FacePerson remove) async {
    if (identical(keep, remove) || keep.id == remove.id) return;
    _mergeInto(keep, remove);
    people.removeWhere((p) => p.id == remove.id);
    people.refresh();
    await _save();
  }
  

  double _cosineDistance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return double.infinity;

    double dot = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return double.infinity;
    return 1 - dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  List<double> _normalize(List<double> v) {
    double sum = 0;

    for (final double x in v) {
      sum += x * x;
    }

    final double mag = math.sqrt(sum);

    if (mag == 0) return v;

    return v.map((x) => x / mag).toList();
  }
  

  Future<void> renamePerson(FacePerson person, String name) async {
    final String clean = name.trim();
    if (clean.isEmpty) return;
    person.name = clean;
    people.refresh();
    await _save();
  }

  List<AssetEntity> getAssetsForPerson(FacePerson person) {
    final List<AssetEntity> result = <AssetEntity>[];

    for (final String id in person.assetIds) {
      final AssetEntity? asset = _assetCache[id];

      if (asset != null) result.add(asset);
    }

    result.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    return result;
  }
  
  Future<List<AssetEntity>> loadAssetsForPerson(FacePerson person) async {
    final List<AssetEntity> result = <AssetEntity>[];
    final List<String> missing = <String>[];

    for (final String id in List<String>.from(person.assetIds)) {
      final AssetEntity? cached = _assetCache[id];

      if (cached != null) {
        result.add(cached);
      } else {
        missing.add(id);
      }
    }

    const int batch = 40;

    for (int i = 0; i < missing.length; i += batch) {
      final List<String> part = missing.sublist(
        i,
        math.min(i + batch, missing.length),
      );

      final List<AssetEntity?> found = await Future.wait(
        part.map((id) async {
          try {
            return await AssetEntity.fromId(id);
          } catch (_) {
            return null;
          }
        }),
      );

      for (final AssetEntity? asset in found) {
        if (asset != null) {
          _assetCache[asset.id] = asset;
          result.add(asset);
        }
      }
    }

    result.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    return result;
  }

  Future<Uint8List?> getCover(FacePerson person) {
    if (person.coverFaceBase64.isNotEmpty) {
      final String key = '${person.id}_${person.coverFaceBase64.length}';

      final Uint8List? cached = _coverCache[key];

      if (cached != null) return SynchronousFuture<Uint8List?>(cached);

      try {
        final Uint8List bytes = base64Decode(person.coverFaceBase64);

        if (_coverCache.length > 300) _coverCache.clear();

        _coverCache[key] = bytes;

        return SynchronousFuture<Uint8List?>(bytes);
      } catch (e) {
        debugPrint('FACE COVER DECODE ERROR = $e');
      }
    }

    return _coverFromAsset(person);
  }

  Future<Uint8List?> _coverFromAsset(FacePerson person) async {
    AssetEntity? asset = _assetCache[person.coverAssetId];

    if (asset == null) {
      for (final String id in person.assetIds) {
        asset = _assetCache[id];

        if (asset != null) break;
      }
    }

    if (asset == null) return null;

    return asset.thumbnailDataWithSize(const ThumbnailSize(400, 400));
  }


  Future<void> removeAssetIds(Iterable<String> ids) async {
    final Set<String> remove = ids.toSet();

    if (remove.isEmpty) return;

    for (final FacePerson p in people) {
      p.assetIds.removeWhere(remove.contains);
    }

    people.removeWhere((p) => p.assetIds.isEmpty);

    _assetCache.removeWhere((key, _) => remove.contains(key));

    people.refresh();

    await _save();
  }

  Future<void> clearPeople() async {
    people.clear();
    _processedIds.clear();
    _assetCache.clear();
    _coverCache.clear();

    _lastScannedLength = -1; 

    hasScanned.value = false;
    progress.value = 0;
    status.value = '';

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove(_peopleKey);
    await prefs.remove(_processedKey);
  }

  @override
  void onClose() {
    _disposed = true;

    _changeDebounce?.cancel();
    _retryTimer?.cancel();
    _lockTimer?.cancel();

    if (_watching) {
      try {
        PhotoManager.removeChangeCallback(_onGalleryChanged);
        PhotoManager.stopChangeNotify();
      } catch (_) {}
    }

    facePipeline.dispose();

    super.onClose();
  }
}
