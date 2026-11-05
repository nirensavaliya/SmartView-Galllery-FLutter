import 'package:flutter/material.dart';
import 'package:gallery_photos/Common/FaceBackgroundScan.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/FaceGroupController.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Screen/Language/AppTranslations.dart';
import 'package:gallery_photos/View/Screen/Language/Controller/LanguageController.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Splash/SplashView.dart';
import 'package:gallery_photos/View/Setting/Controller/SettingsController.dart';
import 'package:gallery_photos/View/Utils/App_Pages.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put(
    SettingsController(),
    permanent: true,
  );
  Get.put(
    LanguageController(),
    permanent: true,
  );
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 250;
  final bool startDark = Get.find<SettingsController>().darkMode.value;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: startDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: startDark ? Brightness.dark : Brightness.light,
    ),
  );

  runApp(const MyApp());
  FaceBackgroundScan.init();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    AppMemory.releaseMemory(hard: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AppMemory.releaseMemory(hard: false);

      if (Get.isRegistered<FaceGroupController>() &&
          Get.find<FaceGroupController>().isScanning.value) {
        FaceBackgroundScan.continueInBackground();
      }
    }

    if (state == AppLifecycleState.resumed &&
        Get.isRegistered<FaceGroupController>()) {
      Get.find<FaceGroupController>().refreshFromBackgroundJob();
    }

    if (state == AppLifecycleState.resumed &&
        Get.isRegistered<PhotosController>()) {
      final PhotosController photos = Get.find<PhotosController>();
      photos.pullNewPhotosIfNeeded();
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        photos.pullNewPhotosIfNeeded();
      });
      Future<void>.delayed(const Duration(milliseconds: 1000), () {
        photos.pullNewPhotosIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isDark = Get.find<SettingsController>().darkMode.value;

      return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: AppTranslations(),
        locale: Get.find<LanguageController>().getLocale(
          Get.find<LanguageController>().selectedLanguage.value,
        ),
        fallbackLocale: const Locale('en', 'US'),
        getPages: AppPages.routes,
        home: const SplashScreen(),
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF0F4F5),
          cardColor: Colors.white,
          useMaterial3: true,
        ),
        darkTheme: _buildDarkTheme(),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      ),
      );
    });
  }
}

ThemeData _buildDarkTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.dark,
  ).copyWith(
    surface: AppColors.darkScaffold,
    onSurface: AppColors.darkText,
    surfaceContainerLowest: AppColors.darkScaffold,
    surfaceContainerLow: AppColors.darkSurface,
    surfaceContainer: AppColors.darkSurface,
    surfaceContainerHigh: AppColors.darkSurface2,
    surfaceContainerHighest: AppColors.darkSurface2,
    outline: const Color(0xFF6B6B6B),
    outlineVariant: AppColors.darkBorder,
  );

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.darkScaffold,
    canvasColor: AppColors.darkScaffold,
    cardColor: AppColors.darkSurface,
    dividerColor: AppColors.darkBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkScaffold,
      foregroundColor: AppColors.darkText,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.darkSurface2,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkBorder),
  );
}

class AppMemory {
  static void releaseMemory({bool hard = false}) {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      if (hard) {
        cache.clearLiveImages();
      }
    } catch (_) {}

    try {
      if (Get.isRegistered<PhotosController>()) {
        Get.find<PhotosController>().trimThumbnailCache(
          keep: hard ? 40 : 150,
        );
      }
    } catch (_) {}
  }
}
