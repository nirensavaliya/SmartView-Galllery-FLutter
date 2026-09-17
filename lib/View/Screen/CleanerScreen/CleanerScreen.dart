import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CleanerScreen extends StatefulWidget {
  const CleanerScreen({super.key});

  @override
  State<CleanerScreen> createState() => _CleanerScreenState();
}

class _CleanerScreenState extends State<CleanerScreen> {
  double progress = 0.0;

  @override
  void initState() {
    super.initState();

    // Demo scanning progress
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() {
        progress = 0.15;
      });
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        progress = 0.35;
      });
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;

      setState(() {
        progress = 0.60;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final int percentage = (progress * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          // ============================================================
          // TOP BLUE SECTION
          // ============================================================

          Container(
            height: 148,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4A90F5),
                  Color(0xFF315FEA),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Back button
                  Positioned(
                    top: 4,
                    left: 8,
                    child: IconButton(
                      onPressed: () {
                        Get.back();
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 48,
                      left: 38,
                      right: 24,
                    ),
                    child: Row(
                      children: [
                        // Progress circle
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                backgroundColor:
                                Colors.white.withOpacity(0.25),
                                valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$percentage%',
                                    style: const TextStyle(
                                      color: Color(0xFF3570ED),
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 34),

                        // Scanning text
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Scanning',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Clear photos and videos\nfor extra phone space',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom small progress dot
                  Positioned(
                    bottom: 13,
                    right: 20,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ============================================================
          // SCANNING ITEMS
          // ============================================================

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _CleanerItem(
                  icon: Icons.photo_library_rounded,
                  iconColor: const Color(0xFF45B77A),
                  backgroundColor: const Color(0xFFE1F5E9),
                  title: 'Duplicate Photos',
                  subtitle: 'Scanning',
                  onTap: () {},
                ),

                _CleanerItem(
                  icon: Icons.video_library_rounded,
                  iconColor: const Color(0xFF42B9E8),
                  backgroundColor: const Color(0xFFE1F5FC),
                  title: 'Large Media',
                  subtitle: 'Scanning',
                  onTap: () {},
                ),

                _CleanerItem(
                  icon: Icons.photo_camera_rounded,
                  iconColor: const Color(0xFFF05B6B),
                  backgroundColor: const Color(0xFFFFE4E7),
                  title: 'Screenshots',
                  subtitle: 'Scanning',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CLEANER ITEM
// ============================================================

class _CleanerItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CleanerItem({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 21,
                ),
              ),

              const SizedBox(width: 10),

              // Text
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF202124),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(
                Icons.keyboard_arrow_right_rounded,
                color: Colors.grey,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}