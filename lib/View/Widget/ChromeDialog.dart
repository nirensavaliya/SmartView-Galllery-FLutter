import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';

class ChromeDialog extends StatelessWidget {
  const ChromeDialog({
    super.key,
    required this.title,
    this.message,
    this.child,
    this.actions,
  });

  final String title;
  final String? message;
  final Widget? child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: InnerChrome.dialogBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ChromeText.title),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: ChromeText.body),
            ],
            if (child != null) ...[
              const SizedBox(height: 10),
              child!,
            ],
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  for (int i = 0; i < actions!.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: actions![i]),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChromeText {
  static TextStyle get title => TextStyle(
    color: InnerChrome.dialogInk,
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get body => TextStyle(
    color: InnerChrome.muted,
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 14,
    height: 1.35,
  );

  static TextStyle get row => TextStyle(
    color: InnerChrome.dialogInk,
    fontFamily: 'Plus Jakarta Sans',
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}

class ChromeButton extends StatelessWidget {
  const ChromeButton.cancel({
    super.key,
    required this.onPressed,
    this.label = 'Cancel',
  }) : danger = false,
       primary = false;

  const ChromeButton.ok({
    super.key,
    required this.onPressed,
    this.label = 'OK',
  }) : danger = false,
       primary = true;

  const ChromeButton.danger({
    super.key,
    required this.onPressed,
    required this.label,
  }) : danger = true,
       primary = false;

  final VoidCallback onPressed;
  final String label;
  final bool danger;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    if (!primary && !danger) {
      return SizedBox(
        height: 46,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: InnerChrome.dialogInk,
            side: BorderSide(color: InnerChrome.line, width: 1.4),
            shape: shape,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: danger
              ? InnerChrome.danger
              : InnerChrome.dialogPrimaryBg,
          foregroundColor: danger ? Colors.white : InnerChrome.dialogPrimaryFg,
          shape: shape,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
