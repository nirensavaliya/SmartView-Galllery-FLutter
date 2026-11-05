import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class FeedbackController extends GetxController {
  static const List<String> categories = [
    'Bug report',
    'Suggestion',
    'New feature',
    'Other',
  ];

  static const List<String> ratingLabels = [
    'Very bad',
    'Bad',
    'Okay',
    'Good',
    'Great',
  ];

  final TextEditingController messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final RxInt rating = 4.obs;
  final RxString category = 'Suggestion'.obs;
  final Rxn<XFile> screenshot = Rxn<XFile>();
  final RxBool showError = false.obs;
  final RxBool sending = false.obs;

  @override
  void onClose() {
    messageController.dispose();
    super.onClose();
  }

  void setRating(int value) {
    rating.value = value;
  }

  void setCategory(String value) {
    category.value = value;
  }

  void clearError() {
    if (showError.value) showError.value = false;
  }

  Future<void> pickScreenshot() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) screenshot.value = file;
  }

  void removeScreenshot() {
    screenshot.value = null;
  }

  /// Returns the sent rating when the message is valid.
  Future<({String category, int rating})?> submit() async {
    if (messageController.text.trim().isEmpty) {
      showError.value = true;
      return null;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    showError.value = false;
    sending.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    sending.value = false;
    return (category: category.value, rating: rating.value);
  }

  void resetForm() {
    messageController.clear();
    screenshot.value = null;
    rating.value = 4;
    category.value = 'Suggestion';
    showError.value = false;
  }
}
