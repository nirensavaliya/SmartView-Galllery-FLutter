import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/BottomBar/DashBoard.dart';
import 'package:gallery_photos/View/Screen/Splash/Controller/SplashController.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SplashController controller=Get.put(SplashController());

  double progress = 0.0;
  String loadingText = "Preparing gallery...";

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareApp();
    });
  }

  Future<void> _prepareApp() async {
    try {
      setState(() {
        progress = 0.15;
        loadingText = "Loading your photos...";
      });

      // Yahan saare photos/videos load honge
      await controller.loadPhotos();

      if (!mounted) return;

      setState(() {
        progress = 1.0;
        loadingText = "Gallery ready";
      });

      await Future.delayed(
        const Duration(milliseconds: 250),
      );

      if (!mounted) return;

      // Aapka existing Dashboard
      Get.offAll(
            () => Dashboard(),
      );
    } catch (e) {
      debugPrint("Splash Error: $e");

      if (!mounted) return;

      Get.offAll(
            () => Dashboard(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF1F3F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 70,
                color: Color(0xff292929),
              ),

              const SizedBox(height: 20),

              const Text(
                "Gallery",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 30),

              LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: Colors.grey.shade300,
              ),

              const SizedBox(height: 12),

              Text(
                loadingText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}