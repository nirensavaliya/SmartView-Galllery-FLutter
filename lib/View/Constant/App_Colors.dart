import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Setting/Controller/SettingsController.dart';
import 'package:get/get.dart';

class AppColors {
  AppColors._();

  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurface2 = Color(0xFF262626);
  static const Color darkBorder = Color(0xFF2E2E2E);
  static const Color darkText = Color(0xFFEDEDED);

  static bool get isDark {
    if (Get.isRegistered<SettingsController>()) {
      return Get.find<SettingsController>().darkMode.value;
    }
    return false;
  }

static double _chroma(Color c) {
    final double r = c.r, g = c.g, b = c.b;
    final double mx = [r, g, b].reduce((a, b) => a > b ? a : b);
    final double mn = [r, g, b].reduce((a, b) => a < b ? a : b);
    return mx - mn;
  }

  static double _light(Color c) => HSLColor.fromColor(c).lightness;

  static Color _tinted(Color c, double lightness) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 0.45))
        .withLightness(lightness)
        .toColor()
        .withValues(alpha: c.a);
  }

  static Color bg(Color c) {
    if (!isDark) return c;
    if (c.a < 0.9) return c;

    final double l = _light(c);
    if (l < 0.35) return c;

    if (_chroma(c) < 0.06) {
      if (l > 0.9) return darkScaffold;
      return darkSurface2;
    }

    if (l > 0.8) return _tinted(c, 0.13);
    return c;
  }

  static Color surface(Color c) {
    if (!isDark) return c;
    if (c.a < 0.9) return c;

    final double l = _light(c);
    if (l < 0.35) return c;

    if (_chroma(c) < 0.06) {
      if (l >= 0.985) return darkSurface;
      if (l > 0.9) return darkSurface2;
      if (l > 0.6) {
        final double nl = 0.30 - ((l - 0.6) / 0.4) * 0.14;
        return HSLColor.fromAHSL(1, 0, 0, nl).toColor();
      }
      return c;
    }

    if (l > 0.8) return _tinted(c, 0.20);
    return c;
  }

  static Color fg(Color c) {
    if (!isDark) return c;
    if (c.a == 0) return c;

    final double l = _light(c);
    if (l >= 0.8) return c;

    final double chroma = _chroma(c);

    if (chroma < 0.1) {
      final double nl = (0.93 - l * 0.6).clamp(0.45, 0.95);
      return HSLColor.fromAHSL(c.a, 0, 0, nl).toColor();
    }

    if (l < 0.45) {
      return HSLColor.fromColor(c)
          .withLightness((l + 0.25).clamp(0.0, 0.75))
          .toColor()
          .withValues(alpha: c.a);
    }

    return c;
  }

  static Color border(Color c) {
    if (!isDark) return c;
    if (c.a < 0.78) return c;

    final double l = _light(c);
    if (l >= 0.995) return c;
    if (l > 0.75 && _chroma(c) < 0.1) return darkBorder;
    if (l > 0.8) return _tinted(c, 0.22);
    return c;
  }
}
