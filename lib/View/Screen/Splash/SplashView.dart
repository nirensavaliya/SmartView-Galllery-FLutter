import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/RequestAppPermissions.dart';
import 'package:gallery_photos/View/Screen/BottomBar/DashBoard.dart';
import 'package:gallery_photos/View/Screen/Splash/Controller/SplashController.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLogo.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashWaveBanner.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  final SplashController controller = Get.put(SplashController());
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final AnimationController _spin;
  late final Animation<double> _angle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _angle = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _spin, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareApp();
    });
  }

  Future<void> _prepareApp() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    await RequestAppPermissions();
    if (!mounted) return;

    controller.startLoading();
    Get.offAll(() => Dashboard());
  }

  @override
  void dispose() {
    _controller.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double logoSize = size.width * 0.45;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(child: SplashWaveBanner()),
            Align(
              alignment: const Alignment(0, -0.45),
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _angle,
                        builder: (context, _) {
                          return SplashLogo(
                            size: logoSize,
                            angle: _angle.value,
                          );
                        },
                      ),
                      SizedBox(height: size.height * 0.0),
                      ShaderMask(
                        shaderCallback: (Rect rect) {
                          return const LinearGradient(
                            colors: [Color(0xFFCBD5E1), Color(0xFF818CF8)],
                          ).createShader(rect);
                        },
                        child: Text(
                          'Photos',
                          style: TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            color: Colors.white,
                            fontSize: size.width * 0.105,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'GALLERY',
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          color: const Color(0xFF3F8EF0),
                          fontSize: size.width * 0.028,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
