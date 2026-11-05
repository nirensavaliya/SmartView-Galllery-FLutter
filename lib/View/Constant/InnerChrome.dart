import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class InnerChrome {
  InnerChrome._();

  static bool get light => !AppColors.isDark;

  static Color get page => light ? const Color(0xFFF6F7F9) : const Color(0xFF05070B);
  static Color get ink => light ? const Color(0xFF111827) : const Color(0xFFF4F6FA);
  static Color get muted => light ? const Color(0xFF6B7280) : const Color(0xFF8A94A8);
  static Color get card => light ? Colors.white : const Color(0xFF0E131B);
  static Color get alt => light ? const Color(0xFFE8EDF2) : const Color(0xFF121925);
  static Color get sheet => light ? Colors.white : const Color(0xFF111826);
  static Color get panel => light ? Colors.white : const Color(0xFF141C28);
  static Color get line => light ? const Color(0xFFE6EAEF) : const Color(0xFF1E2633);
  static Color get accent => light ? const Color(0xFF2970FF) : const Color(0xFF4C9BFF);
  static Color get danger => light ? const Color(0xFFE11D48) : const Color(0xFFFF6B7A);
  static Color get dangerBg => light ? const Color(0xFFFFE6EC) : const Color(0xFF1A1F2B);
  static Color get pick => light ? const Color(0xFF2970FF) : const Color(0xFFC9D2FF);
  static Color get pickInk => light ? Colors.white : const Color(0xFF1B2A6B);
  static Color get disabled => light ? const Color(0xFFD5DCE6) : const Color(0xFF1A3358);
  static Color get snack => light ? Colors.white : const Color(0xFF1A2633);
  static Color get faint => light ? const Color(0xFFD0D5DD) : const Color(0xFF3A4658);
  static Color get mapBlock => light ? const Color(0xFFE8EDF2) : const Color(0xFF1A2433);
  static Color get dialogBg => light ? Colors.white : const Color(0xFF151515);
  static Color get dialogMenu => light ? Colors.white : const Color(0xFF202020);
  static Color get dialogField => light ? const Color(0xFFF3F5F8) : const Color(0xFF222222);
  static Color get dialogDrop => light ? Colors.white : const Color(0xFF242424);
  static Color get dialogInk => light ? const Color(0xFF111827) : Colors.white;
  static Color get dialogHint => light ? const Color(0xFF9CA3AF) : const Color(0x61FFFFFF);
  static Color get dialogIcon => light ? const Color(0xFF6B7280) : const Color(0xB3FFFFFF);
  static Color get dialogPrimaryBg => light ? const Color(0xFF2970FF) : Colors.white;
  static Color get dialogPrimaryFg => light ? Colors.white : Colors.black;
  static Color get dialogSecondaryBg => light ? const Color(0xFFE8EDF2) : const Color(0xFF3D3D3D);
  static Color get dialogSecondaryFg => light ? const Color(0xFF111827) : Colors.white;

  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF60A5FA), Color(0xFF2970FF)],
  );

  /// #2563EB at 38 percent. X 0, Y 10, blur 25, spread 0.
  static const List<BoxShadow> actionShadow = [
    BoxShadow(
      color: Color(0x612563EB),
      offset: Offset(0, 10),
      blurRadius: 25,
    ),
  ];

  static List<BoxShadow> get lift => light
      ? const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ]
      : const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];
}
