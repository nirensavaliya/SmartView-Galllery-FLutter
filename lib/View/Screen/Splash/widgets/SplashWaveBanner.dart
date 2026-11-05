import 'package:flutter/material.dart';

class SplashWaveBanner extends StatelessWidget {
  const SplashWaveBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _WavesPainter(),
      child: SizedBox.expand(),
    );
  }
}


class _WavesPainter extends CustomPainter {
  const _WavesPainter();

  static const double _designW = 375;
  static const double _regionH = 340;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _designW;
    canvas.save();
    canvas.translate(0, size.height - _regionH * scale);
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, _designW, _regionH + 200));

    canvas.drawCircle(
      const Offset(75, 185),
      170,
      Paint()..color = const Color(0xFF0A4A66),
    );

    final Path steel = Path()
      ..moveTo(0, 44)
      ..cubicTo(40, 38, 78, 42, 97, 54)
      ..cubicTo(130, 50, 170, 70, 193, 100)
      ..cubicTo(196, 140, 185, 172, 150, 172)
      ..lineTo(0, 172)
      ..close();
    canvas.drawPath(steel, Paint()..color = const Color(0xB32F7DB8));

    final Path back = Path()
      ..moveTo(97, 68)
      ..cubicTo(115, 48, 150, 36, 190, 34)
      ..cubicTo(240, 30, 300, 22, 340, 26)
      ..cubicTo(360, 28, 370, 34, 375, 38)
      ..lineTo(375, _regionH + 200)
      ..lineTo(97, _regionH + 200)
      ..close();
    canvas.drawPath(
      back,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1767E6), Color(0xFF0A4FCB)],
        ).createShader(const Rect.fromLTWH(97, 20, 278, 200)),
    );

    canvas.save();
    canvas.translate(0, 95);
    final Path front = Path()
      ..moveTo(0, 2)
      ..cubicTo(50, 2, 80, 8, 110, 30)
      ..cubicTo(150, 62, 190, 89, 235, 89)
      ..cubicTo(290, 89, 330, 40, 375, 28)
      ..lineTo(375, 245 + 200)
      ..lineTo(0, 245 + 200)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF0B0F17)],
          stops: [0.0, 0.40, 0.85],
        ).createShader(const Rect.fromLTWH(0, 0, 375, 245)),
    );
    canvas.restore();

    canvas.drawCircle(
      const Offset(181, 26),
      26.5,
      Paint()..color = const Color(0xFF0B4C9E),
    );
    canvas.drawCircle(
      const Offset(225, 22),
      10,
      Paint()..color = const Color(0xFF3F9BE8),
    );
    canvas.drawCircle(
      const Offset(125, 113),
      31,
      Paint()..color = const Color(0xFF162B5E),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
