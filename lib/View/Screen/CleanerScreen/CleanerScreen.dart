import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/Controller/CleanerController.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/WhatsAppMediaCleanerScreen.dart';
import 'package:get/get.dart';

class CleanerScreen extends GetView<CleanerController> {
  const CleanerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: InnerChrome.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: InnerChrome.light
                  ? const [
                      Color(0xFFF7F9FC),
                      Color(0xFFEEF3FA),
                      Color(0xFFE7EEF8),
                    ]
                  : const [
                      Color(0xFF0A1018),
                      Color(0xFF070C14),
                      Color(0xFF05070B),
                    ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: InnerChrome.alt,
                          shape: BoxShape.circle,
                          border: Border.all(color: InnerChrome.line),
                        ),
                        child: IconButton(
                          onPressed: () => Get.back(),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: InnerChrome.ink,
                            size: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Cleaner',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: InnerChrome.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  flex: 11,
                  child: Obx(() {
                    final scanning = controller.scanning.value;
                    final parts = CleanerController.trashParts(
                      controller.totalJunkBytes.value,
                    );
                    final busy = scanning || controller.deleting.value;
                    final remaining = controller.totalJunkBytes.value > 0;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _BubbleStage(
                          generation: controller.scanGen.value,
                          cleanGen: controller.cleanGen.value,
                          busy: busy || remaining,
                          cleaning: controller.deleting.value,
                          done: !scanning &&
                              !controller.deleting.value &&
                              !remaining,
                          restoreAfterClean: remaining,
                        ),
                        Center(
                          child: _TrashHero(
                            value: parts.$1,
                            unit: parts.$2,
                            caption: scanning
                                ? controller.statusText.value
                                : 'Trash size',
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                Expanded(
                  flex: 12,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: 0),
                    duration: const Duration(milliseconds: 780),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) {
                      return Transform.translate(
                        offset: Offset(0, t * 90),
                        child: Opacity(opacity: 1 - t, child: child),
                      );
                    },
                    child: Obx(() {
                      final cats = controller.categories;
                      final scanning = controller.scanning.value;
                      final junk = controller.totalJunkBytes.value;
                      return _Sheet(
                        categories: cats,
                        scanning: scanning,
                        trashBytes: junk,
                        trashLabel: CleanerController.formatBytes(junk),
                        rowStatus: Map<CleanerCategoryType, CleanerRowStatus>.from(
                          controller.rowStatus,
                        ),
                        formatBytes: CleanerController.formatBytes,
                        onCategoryTap: (type) {
                          if (scanning) return;
                          final cat = controller.categoryOf(type);
                          final status = controller.rowStatus[type];
                          if (status == CleanerRowStatus.cleared ||
                              cat.count == 0) {
                            Get.snackbar(
                              cat.title,
                              'Nothing found in this category',
                              snackPosition: SnackPosition.BOTTOM,
                              margin: const EdgeInsets.all(12),
                              backgroundColor: InnerChrome.snack,
                              colorText: InnerChrome.ink,
                            );
                            return;
                          }
                          controller.openCategory(type);
                        },
                        onClean: controller.cleanAllJunkThenOpenMedia,
                        onScanAgain: controller.startScan,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrashHero extends StatelessWidget {
  const _TrashHero({
    required this.value,
    required this.unit,
    required this.caption,
  });

  final String value;
  final String unit;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: Text(
                value,
                key: ValueKey(value),
                style: TextStyle(
                  fontSize: 66,
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w300,
                  color: InnerChrome.accent,
                  height: 0.95,
                  letterSpacing: -1.8,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w500,
                  color: InnerChrome.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Plus Jakarta Sans',
            color: InnerChrome.accent.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.categories,
    required this.scanning,
    required this.trashBytes,
    required this.trashLabel,
    required this.rowStatus,
    required this.formatBytes,
    required this.onCategoryTap,
    required this.onClean,
    required this.onScanAgain,
  });

  final List<CleanerCategory> categories;
  final bool scanning;
  final int trashBytes;
  final String trashLabel;
  final Map<CleanerCategoryType, CleanerRowStatus> rowStatus;
  final String Function(int) formatBytes;
  final ValueChanged<CleanerCategoryType> onCategoryTap;
  final VoidCallback onClean;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(
        color: InnerChrome.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: categories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return const WhatsAppCleanerOption(
                      child: _WhatsAppMediaRow(),
                    );
                  }
                  final cat = categories[i - 1];
                  final status =
                      rowStatus[cat.type] ?? CleanerRowStatus.waiting;
                  final active = status != CleanerRowStatus.waiting;
                  final cleared = status == CleanerRowStatus.cleared;
                  final bytes = cat.type.isJunk
                      ? cat.junkBytes
                      : cat.type == CleanerCategoryType.duplicatePhotos
                          ? cat.duplicateGroups.fold<int>(
                              0,
                              (s, g) => s + g.reclaimableBytes,
                            )
                          : cat.totalBytes;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onCategoryTap(cat.type),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 280),
                        opacity: active || !scanning ? 1 : 0.42,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Plus Jakarta Sans',
                                    color: cleared
                                        ? InnerChrome.muted
                                        : InnerChrome.ink,
                                    decoration: cleared
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                              if (status == CleanerRowStatus.completed ||
                                  status == CleanerRowStatus.cleared ||
                                  (!scanning && (cat.count > 0 || bytes > 0)))
                                Text(
                                  cleared ? 'Cleared' : formatBytes(bytes),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Plus Jakarta Sans',
                                    color: cleared
                                        ? InnerChrome.accent
                                        : InnerChrome.muted,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: switch (status) {
                                  CleanerRowStatus.cleared => Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: InnerChrome.accent,
                                    ),
                                  CleanerRowStatus.completed => Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: InnerChrome.accent,
                                    ),
                                  CleanerRowStatus.progress => Padding(
                                      padding: EdgeInsets.all(2),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: InnerChrome.accent,
                                      ),
                                    ),
                                  CleanerRowStatus.waiting => Icon(
                                      Icons.circle_outlined,
                                      size: 20,
                                      color: InnerChrome.faint,
                                    ),
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: _CleanButton(
                enabled: !scanning && trashBytes > 0,
                label: scanning
                    ? 'Scanning…'
                    : trashBytes > 0
                        ? 'Clean Now $trashLabel'
                        : 'Scan again',
                onTap: scanning
                    ? null
                    : trashBytes > 0
                        ? onClean
                        : onScanAgain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CleanButton extends StatelessWidget {
  const _CleanButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = onTap != null;
    const radius = BorderRadius.all(Radius.circular(16));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: canTap
            ? [
                ...InnerChrome.actionShadow,
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: canTap ? null : InnerChrome.disabled,
              gradient: canTap
                  ? InnerChrome.actionGradient
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Orb {
  const _Orb({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.color,
    required this.delay,
    required this.speed,
    required this.phase,
    required this.amp,
  });

  final double nx;
  final double ny;
  final double radius;
  final Color color;
  final double delay;
  final double speed;
  final double phase;
  final double amp;
}

class _BubbleStage extends StatefulWidget {
  const _BubbleStage({
    required this.generation,
    required this.cleanGen,
    required this.busy,
    required this.cleaning,
    required this.done,
    required this.restoreAfterClean,
  });

  final int generation;
  final int cleanGen;
  final bool busy;
  final bool cleaning;
  final bool done;
  final bool restoreAfterClean;

  @override
  State<_BubbleStage> createState() => _BubbleStageState();
}

class _BubbleStageState extends State<_BubbleStage>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  double _t = 0;
  double? _cleanAt;

  static const _orbs = <_Orb>[
    _Orb(nx: -0.72, ny: -0.08, radius: 78, color: Color(0xF74C9BFF), delay: 0.00, speed: 1.15, phase: 0.2, amp: 26),
    _Orb(nx: -0.82, ny: -0.58, radius: 46, color: Color(0xF23B82F6), delay: 0.05, speed: 1.55, phase: 1.4, amp: 32),
    _Orb(nx: -0.22, ny: -0.78, radius: 30, color: Color(0xE860A5FA), delay: 0.10, speed: 1.80, phase: 2.1, amp: 28),
    _Orb(nx: 0.22, ny: -0.84, radius: 20, color: Color(0xE62563EB), delay: 0.14, speed: 2.10, phase: 0.7, amp: 24),
    _Orb(nx: 0.58, ny: -0.62, radius: 38, color: Color(0xF093C5FD), delay: 0.07, speed: 1.35, phase: 1.9, amp: 30),
    _Orb(nx: 0.84, ny: -0.18, radius: 58, color: Color(0xF51D4ED8), delay: 0.02, speed: 1.05, phase: 0.4, amp: 22),
    _Orb(nx: 0.86, ny: 0.28, radius: 68, color: Color(0xF54C9BFF), delay: 0.00, speed: 0.95, phase: 2.6, amp: 20),
    _Orb(nx: 0.62, ny: 0.62, radius: 48, color: Color(0xF03B82F6), delay: 0.09, speed: 1.42, phase: 1.1, amp: 28),
    _Orb(nx: 0.18, ny: 0.82, radius: 26, color: Color(0xE660A5FA), delay: 0.16, speed: 1.90, phase: 2.9, amp: 26),
    _Orb(nx: -0.36, ny: 0.70, radius: 24, color: Color(0xE393C5FD), delay: 0.12, speed: 1.70, phase: 0.5, amp: 30),
    _Orb(nx: -0.88, ny: 0.34, radius: 32, color: Color(0xEB4C9BFF), delay: 0.08, speed: 1.60, phase: 2.0, amp: 34),
    _Orb(nx: 0.92, ny: -0.72, radius: 16, color: Color(0xE02563EB), delay: 0.18, speed: 2.20, phase: 3.2, amp: 22),
    _Orb(nx: -0.08, ny: 0.90, radius: 14, color: Color(0xD93B82F6), delay: 0.20, speed: 2.00, phase: 1.6, amp: 18),
    _Orb(nx: 0.40, ny: 0.08, radius: 18, color: Color(0xCC60A5FA), delay: 0.11, speed: 1.75, phase: 0.9, amp: 36),
    _Orb(nx: -0.48, ny: 0.18, radius: 22, color: Color(0xD64C9BFF), delay: 0.13, speed: 1.48, phase: 2.4, amp: 28),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMicroseconds / 1e6);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ticker?.start();
    });
  }

  void _restartBubbles() {
    _cleanAt = null;
    _ticker
      ?..stop()
      ..start();
  }

  @override
  void didUpdateWidget(covariant _BubbleStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      _restartBubbles();
    }

    // Each clean action: suck bubbles in
    if (oldWidget.cleanGen != widget.cleanGen) {
      _cleanAt = _t;
    }

    // Partial clear done → bubbles should come back (full clear nahi hua)
    if (oldWidget.cleaning &&
        !widget.cleaning &&
        widget.restoreAfterClean &&
        !widget.done) {
      final token = _cleanAt;
      Future.delayed(const Duration(milliseconds: 850), () {
        if (!mounted) return;
        if (_cleanAt != token) return;
        if (widget.done || widget.cleaning) return;
        setState(_restartBubbles);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanP = widget.done
        ? 1.0
        : _cleanAt == null
            ? 0.0
            : ((_t - _cleanAt!) / 1.35).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _BubblePainter(
          t: _t,
          busy: widget.busy,
          clean: cleanP,
          orbs: _orbs,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.t,
    required this.busy,
    required this.clean,
    required this.orbs,
  });

  final double t;
  final bool busy;
  final double clean;
  final List<_Orb> orbs;

  Offset _spin(Offset p, Offset c, double a) {
    final dx = p.dx - c.dx;
    final dy = p.dy - c.dy;
    final cos = math.cos(a);
    final sin = math.sin(a);
    return Offset(c.dx + dx * cos - dy * sin, c.dy + dx * sin + dy * cos);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final spreadX = size.width * 0.42;
    final spreadY = size.height * 0.40;
    final vacuum = Curves.easeInCubic.transform((clean / 0.72).clamp(0.0, 1.0));
    final burst = clean <= 0.68 ? 0.0 : ((clean - 0.68) / 0.32).clamp(0.0, 1.0);

    if (busy && clean == 0) {
      for (var i = 0; i < 3; i++) {
        final p = (t * 0.55 + i / 3) % 1.0;
        final r = 28 + p * math.min(size.width, size.height) * 0.38;
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = const Color(0xFF4C9BFF).withValues(alpha: (1 - p) * 0.38),
        );
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 92),
        t * 3.4,
        1.15,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = const Color(0xFF4C9BFF).withValues(alpha: 0.55),
      );
    }

    if (clean > 0 && clean < 0.82) {
      canvas.drawCircle(
        center,
        118 * (1 - vacuum) + 10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF4C9BFF).withValues(alpha: 0.5 * (1 - vacuum)),
      );
      for (var i = 0; i < 22; i++) {
        final ang = i * 0.92 + t * (4.2 + vacuum * 7);
        final dist = (1 - vacuum) * (48 + (i % 8) * 16);
        canvas.drawCircle(
          Offset(cx + math.cos(ang) * dist, cy + math.sin(ang) * dist),
          3.2 + (i % 3),
          Paint()
            ..color =
                const Color(0xFF4C9BFF).withValues(alpha: 0.75 * (1 - vacuum * 0.35)),
        );
      }
    }

    if (burst > 0 && burst < 0.98) {
      for (var i = 0; i < 3; i++) {
        final p = ((burst + i * 0.18) % 1.0);
        canvas.drawCircle(
          center,
          18 + p * 130,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = const Color(0xFF4C9BFF).withValues(alpha: (1 - p) * 0.45),
        );
      }
    }

    for (final orb in orbs) {
      final local = t - orb.delay;
      if (local < 0) continue;

      final appear = Curves.easeOutBack.transform(
        (local / 0.75).clamp(0.0, 1.0),
      );
      final restX = cx + orb.nx * spreadX;
      final restY = cy + orb.ny * spreadY;
      var pos = Offset(
        ui.lerpDouble(cx, restX, appear)!,
        ui.lerpDouble(cy, restY, appear)!,
      );

      final amp =
          orb.amp * (busy && clean == 0 ? 1.35 : 0.85) * appear.clamp(0.0, 1.0);
      final speed = orb.speed * (busy && clean == 0 ? 1.55 : 0.85);
      pos += Offset(
        math.sin(t * speed + orb.phase) * amp,
        math.cos(t * speed * 0.82 + orb.phase) * amp * 0.72,
      );

      var scale = appear.clamp(0.0, 1.25);
      scale *=
          1 + math.sin(t * speed * 1.6 + orb.phase) * (busy ? 0.07 : 0.03);

      if (clean > 0) {
        pos = _spin(pos, center, vacuum * math.pi * 5.2 + orb.phase);
        pos = Offset(
          ui.lerpDouble(pos.dx, cx, vacuum)!,
          ui.lerpDouble(pos.dy, cy, vacuum)!,
        );
        scale *= (1 - vacuum) * (1 - burst);
      }

      if (scale <= 0.02) continue;
      _drawOrb(canvas, pos, orb.radius * scale, orb.color);
    }
  }

  void _drawOrb(Canvas canvas, Offset c, double r, Color color) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.32, -0.38),
          radius: 0.95,
          colors: [
            const Color(0xFFB9D4FF).withValues(alpha: 0.7),
            color,
            color.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c.translate(-r * 0.28, -r * 0.32),
      r * 0.18,
      Paint()..color = const Color(0xFFB9D4FF).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.t != t || old.busy != busy || old.clean != clean;
}

class _WhatsAppMediaRow extends StatelessWidget {
  const _WhatsAppMediaRow();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.to(
          () => const WhatsAppMediaCleanerScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp cleaner',
                      style: TextStyle(
                        fontSize: 16,
                        color: InnerChrome.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Clear WhatsApp attachments',
                      style: TextStyle(
                        fontSize: 12,
                        color: InnerChrome.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: InnerChrome.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
