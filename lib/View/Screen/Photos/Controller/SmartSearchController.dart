import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:photo_manager/photo_manager.dart';

class SmartSearchController extends GetxController {
  late final ImageLabeler _imageLabeler;

  final Map<String, List<String>> imageLabels = {};
  final Map<String, Future<List<String>>> _pendingAnalysis = {};
  final RxBool isAnalyzing = false.obs;

  @override
  void onInit() {
    super.onInit();

    _imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(
        confidenceThreshold: 0.50,
      ),
    );
  }

  Future<List<String>> analyzeImage(AssetEntity asset) async {
    if (imageLabels.containsKey(asset.id)) {
      return imageLabels[asset.id]!;
    }

    if (_pendingAnalysis.containsKey(asset.id)) {
      return _pendingAnalysis[asset.id]!;
    }

    final future = _analyzeImageInternal(asset);

    _pendingAnalysis[asset.id] = future;

    try {
      return await future;
    } finally {
      _pendingAnalysis.remove(asset.id);
    }
  }

  Future<List<String>> _analyzeImageInternal(
      AssetEntity asset,
      ) async {
    try {
      final File? file = await asset.file;

      if (file == null || !await file.exists()) {
        imageLabels[asset.id] = [];
        return [];
      }

      final inputImage = InputImage.fromFilePath(file.path);

      final labels = await _imageLabeler.processImage(inputImage);

      final detectedLabels = labels
          .where((label) => label.confidence >= 0.50)
          .map((label) => label.label.toLowerCase())
          .toSet()
          .toList();

      imageLabels[asset.id] = detectedLabels;

      debugPrint(
        "SMART SEARCH ${asset.id} => $detectedLabels",
      );

      return detectedLabels;
    } catch (e) {
      debugPrint(
        "Smart Search Error ${asset.id}: $e",
      );

      imageLabels[asset.id] = [];
      return [];
    }
  }
  Future<List<AssetEntity>> searchByImageContent(
      List<AssetEntity> assets,
      String query,
      ) async {
    final searchText = query.trim().toLowerCase();

    if (searchText.isEmpty) {
      return assets;
    }

    final imageAssets = assets
        .where((asset) => asset.type != AssetType.video)
        .toList();

    final results = <AssetEntity>[];

    for (final asset in imageAssets) {
      final labels = imageLabels[asset.id];

      if (labels == null) {
        continue;
      }

      if (_isMatch(labels, searchText)) {
        results.add(asset);
      }
    }

    final pendingAssets = imageAssets
        .where((asset) => !imageLabels.containsKey(asset.id))
        .toList();

    const batchSize = 5;

    for (int i = 0; i < pendingAssets.length; i += batchSize) {
      if (isAnalyzing.value == false) {
        return results;
      }

      final batch = pendingAssets.sublist(
        i,
        (i + batchSize > pendingAssets.length)
            ? pendingAssets.length
            : i + batchSize,
      );

      final batchResults = await Future.wait(
        batch.map((asset) async {
          final labels = await analyzeImage(asset);

          return MapEntry(asset, labels);
        }),
      );

      for (final entry in batchResults) {
        if (_isMatch(entry.value, searchText)) {
          results.add(entry.key);
        }
      }
    }

    return results;
  }

  bool _isMatch(List<String> labels, String searchText) {
    return labels.any(
          (label) =>
      label == searchText ||
          label.contains(searchText) ||
          searchText.contains(label),
    );
  }

  /// Analyze all images in background
  Future<void> analyzeAllImages(
      List<AssetEntity> assets,
      ) async {
    if (isAnalyzing.value) {
      return;
    }

    isAnalyzing.value = true;

    try {
      for (final asset in assets) {
        if (asset.type == AssetType.video) {
          continue;
        }

        if (imageLabels.containsKey(asset.id)) {
          continue;
        }

        await analyzeImage(asset);
      }
    } finally {
      isAnalyzing.value = false;
    }
  }

  @override
  void onClose() {
    _imageLabeler.close();
    super.onClose();
  }
}