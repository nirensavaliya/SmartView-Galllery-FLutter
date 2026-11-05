import 'dart:math' as math;

import 'package:flutter/material.dart';

class SplashLogo extends StatelessWidget {
  const SplashLogo({
    super.key,
    required this.size,
    this.angle = 0,
    this.glow = true,
  });

  final double size;
  final double angle;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: glow
            ? const [
                BoxShadow(
                  color: Color(0x40C03A9A),
                  blurRadius: 45,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: Color(0x302A6AF0),
                  blurRadius: 60,
                  offset: Offset(-10, -6),
                ),
              ]
            : null,
      ),
      child:  Transform.rotate(
        angle: angle,
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.angle);

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double scale = size.width / 2;
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final Path petal = Path()
      ..moveTo(0.04, -0.14)
      ..cubicTo(0.02, -0.65, 0.35, -1.0, 0.98, -0.72)
      ..cubicTo(0.95, -0.38, 0.62, -0.08, 0.14, -0.04)
      ..close();

    const List<List<Color>> gradients = <List<Color>>[
      [Color(0xFF2A86F0), Color(0xFF0B3C9C)],
      [Color(0xFFFF5FA2), Color(0xFFC72E86)],
      [Color(0xFF7A4BD6), Color(0xFF3A2A9A)],
      [Color(0xFF1E78E6), Color(0xFF0A4DB0)],
    ];

    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(angle + i * math.pi / 2);
      final Paint paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: gradients[i],
        ).createShader(const Rect.fromLTRB(0, -1, 1, 0))
        ..isAntiAlias = true;
      canvas.drawPath(petal, paint);
      canvas.restore();
    }

    canvas.drawArc(
      const Rect.fromLTRB(-0.98, -0.98, 0.98, 0.98),
      -math.pi * 0.9,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.012
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    canvas.save();
    canvas.rotate(math.pi / 4);
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 0.5, height: 0.5),
      const Radius.circular(0.13),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.38),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.restore();

    canvas.drawCircle(
      Offset.zero,
      0.1,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
