import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isAdmin;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  static const Color _activeColor = Colors.black;
  static const Color _inactiveColor = Colors.grey;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: 10, bottom: bottomPad > 0 ? 6 : 10),
          child: Row(
            children: [
              _BottomNavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.photo,
                label: "Photos",
                onTap: () => onTap(0),
              ),
              _BottomNavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.photo_album_rounded,
                label: "Albums",
                onTap: () => onTap(1),
              ),
              _BottomNavItem(
                index: 2,
                currentIndex: currentIndex,
                icon: Icons.dashboard_outlined,
                label: "For You",
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  bool get isActive => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? CustomBottomBar._activeColor
        : CustomBottomBar._inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: FontFamily.robotoMedium,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
