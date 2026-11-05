import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class LanguageController extends GetxController {
  final GetStorage storage = GetStorage();

  static const String languageKey = 'app_language';

  final RxString selectedLanguage = 'en'.obs;

final List<Map<String, String>> languages = [
    {
      'name': 'Default',
      'nativeName': 'English',
      'code': 'default',
      'letter': 'D',
    },
    {
      'name': 'English',
      'nativeName': 'English',
      'code': 'en',
      'letter': 'E',
    },
    {
      'name': 'Spanish',
      'nativeName': 'Española',
      'code': 'es',
      'letter': 'E',
    },
    {
      'name': 'Philippians',
      'nativeName': 'Philippians',
      'code': 'fil',
      'letter': 'F',
    },
    {
      'name': 'Portuguese',
      'nativeName': 'Português',
      'code': 'pt',
      'letter': 'P',
    },
    {
      'name': 'Hindi',
      'nativeName': 'हिंदी',
      'code': 'hi',
      'letter': 'हिं',
    },
  ];

@override
  void onInit() {
    super.onInit();

    final savedLanguage =
    storage.read(languageKey);

    if (savedLanguage != null) {
      selectedLanguage.value = savedLanguage;
    }
  }

void selectLanguage(String code) {
    selectedLanguage.value = code;
  }

Locale getLocale(String code) {
    switch (code) {
      case 'default':
        return Get.deviceLocale ??
            const Locale('en', 'US');

      case 'es':
        return const Locale('es', 'ES');

      case 'fil':
        return const Locale('fil', 'PH');

      case 'pt':
        return const Locale('pt', 'PT');

      case 'hi':
        return const Locale('hi', 'IN');

      case 'en':
      default:
        return const Locale('en', 'US');
    }
  }

Future<void> applyLanguage() async {
    final code = selectedLanguage.value;

    await storage.write(
      languageKey,
      code,
    );

    Get.updateLocale(
      getLocale(code),
    );
  }

String get selectedLanguageName {
    switch (selectedLanguage.value) {
      case 'default':
        return 'English';

      case 'es':
        return 'Spanish';

      case 'fil':
        return 'Philippians';

      case 'pt':
        return 'Portuguese';

      case 'hi':
        return 'Hindi';

      case 'en':
      default:
        return 'English';
    }
  }
}