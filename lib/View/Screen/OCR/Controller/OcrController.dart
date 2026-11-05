import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrWord {
  final String text;
  final Rect boundingBox;

  OcrWord({
    required this.text,
    required this.boundingBox,
  });
}

class OcrController extends GetxController {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final RxBool isScanning = false.obs;

  final RxList<OcrWord> words = <OcrWord>[].obs;

  final RxString selectedText = ''.obs;

  double imageWidth = 1;
  double imageHeight = 1;

  Future<void> extractText(File file) async {
    try {
      isScanning.value = true;

      words.clear();
      selectedText.value = '';

      final inputImage = InputImage.fromFilePath(file.path);

      final RecognizedText recognizedText =
      await _textRecognizer.processImage(inputImage);

      final ui.Image image = await _getImageSize(file);

      imageWidth = image.width.toDouble();
      imageHeight = image.height.toDouble();

      final List<OcrWord> detectedWords = [];

      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          for (final TextElement element in line.elements) {
            final String text = element.text.trim();

            if (text.isEmpty) {
              continue;
            }

            detectedWords.add(
              OcrWord(
                text: text,
                boundingBox: element.boundingBox,
              ),
            );
          }
        }
      }
      
      detectedWords.sort((a, b) {
        final double topDifference =
            a.boundingBox.top - b.boundingBox.top;

        if (topDifference.abs() > 15) {
          return topDifference.compareTo(0);
        }

        return a.boundingBox.left.compareTo(
          b.boundingBox.left,
        );
      });

      words.assignAll(detectedWords);
    } catch (e) {
      Get.snackbar(
        'OCR Error',
        'Text detect nahi ho paya',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isScanning.value = false;
    }
  }

  Future<ui.Image> _getImageSize(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void setSelectedText(List<OcrWord> selectedWords) {
    selectedText.value = selectedWords
        .map((word) => word.text)
        .join(' ');
  }

  Future<void> copySelectedText() async {
    final String text = selectedText.value.trim();

    if (text.isEmpty) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: text),
    );

    Get.snackbar(
      'Copied',
      'Selected text copied',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void onClose() {
    _textRecognizer.close();
    super.onClose();
  }
}