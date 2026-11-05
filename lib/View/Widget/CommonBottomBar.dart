import 'package:flutter/material.dart';

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

  static const Color _barColor = Color(0xFF1E2938);
  static const Color _barBorder = Color(0xFF2E3B4C);
  static const Color _tileColor = Color(0xFF212E3E);
  static const Color _iconColor = Color(0xFFB8C5D8);
  static const Color _selectedColor = Color(0xFFCBD5E1);
  static const Color _selectedContent = Color(0xFF1E232F);
  static const Color _forYouAccent = Color(0xFFFF4D7E);

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.image_outlined, label: 'Photos'),
    _NavItem(icon: Icons.grid_view_outlined, label: 'Albums'),
    _NavItem(icon: Icons.favorite, label: 'For You', accent: true),
  ];

  @override
  Widget build(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: light ? Colors.white : _barColor,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: light ? const Color(0xFFE6EAEF) : _barBorder,
                  width: 1.5,
                ),
                boxShadow: light
                    ? const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    if (i != 0) const SizedBox(width: 8),
                    _BarButton(
                      item: _items[i],
                      selected: i == currentIndex,
                      light: light,
                      onTap: () => onTap(i),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final bool accent;
  const _NavItem({
    required this.icon,
    required this.label,
    this.accent = false,
  });
}

class _BarButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool light;
  final VoidCallback onTap;

  const _BarButton({
    required this.item,
    required this.selected,
    required this.light,
    required this.onTap,
  });

  Color get _lightChip {
    if (item.accent) return const Color(0xFFF8E0E8);
    if (item.label == 'Albums') return const Color(0xFFE0E8F8);
    return const Color(0xFFD0F0E8);
  }

  Color get _lightContent {
    if (item.accent) return const Color(0xFFE82868);
    if (item.label == 'Albums') return const Color(0xFF4058C8);
    return const Color(0xFF009688);
  }

  IconData get _icon {
    if (!light) return item.icon;
    if (item.accent) {
      return selected ? Icons.favorite : Icons.favorite_border;
    }
    if (item.label == 'Albums') {
      return selected ? Icons.grid_view_rounded : Icons.grid_view_outlined;
    }
    return selected ? Icons.image : Icons.image_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final bool pink = selected && item.accent && !light;
    final Color background = light
        ? (selected ? _lightChip : Colors.transparent)
        : (selected
            ? CustomBottomBar._selectedColor
            : CustomBottomBar._tileColor);
    final Color content = light
        ? (selected ? _lightContent : const Color(0xFF708090))
        : (selected
            ? CustomBottomBar._selectedContent
            : CustomBottomBar._iconColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 48,
        decoration: pink
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A1F33), Color(0xFF2B1624)],
                ),
                border: Border.all(
                  color: CustomBottomBar._forYouAccent.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CustomBottomBar._forYouAccent.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(selected ? 28 : 18),
              ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: selected ? 20 : 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icon,
                  size: pink ? 22 : 24,
                  color: pink ? CustomBottomBar._forYouAccent : content,
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: pink ? Colors.white : content,
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: pink ? 14 : 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: pink ? 0 : -0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
