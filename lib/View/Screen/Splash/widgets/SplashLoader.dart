import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLogo.dart';

class SplashLoader extends StatefulWidget {
  const SplashLoader({super.key, this.size = 68});

  final double size;

  @override
  State<SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<SplashLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AbsorbPointer(
        child: Stack(
          children: [
            const ColoredBox(color: Color(0x80000000)),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E000000),
                      blurRadius: 22,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) {
                    return SplashLogo(
                      size: widget.size,
                      angle: _spin.value * 2 * math.pi,
                      glow: false,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
