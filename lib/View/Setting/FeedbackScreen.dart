import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Setting/Controller/FeedbackController.dart';
import 'package:get/get.dart';

const String _font = 'Plus Jakarta Sans';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late final FeedbackController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(FeedbackController());
  }

  @override
  void dispose() {
    Get.delete<FeedbackController>();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await controller.submit();
    if (result == null || !mounted) return;
    await Get.to(
      () => ThankYouScreen(category: result.category, rating: result.rating),
    );
    controller.resetForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InnerChrome.page,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const _CircleBackButton(),
        title: Text(
          'Feedback & Suggestions',
          style: TextStyle(
            fontFamily: _font,
            color: InnerChrome.ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help us make it better',
                    style: TextStyle(
                      fontFamily: _font,
                      color: InnerChrome.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tell us what you love, what feels off, or what you wish the app could do.',
                    style: TextStyle(
                      fontFamily: _font,
                      color: InnerChrome.muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('HOW IS YOUR EXPERIENCE?'),
                  const SizedBox(height: 10),
                  _stars(),
                  const SizedBox(height: 22),
                  const _SectionLabel('WHAT IS THIS ABOUT?'),
                  const SizedBox(height: 10),
                  _chips(),
                  const SizedBox(height: 22),
                  const _SectionLabel('YOUR MESSAGE'),
                  const SizedBox(height: 10),
                  _messageField(),
                  const SizedBox(height: 16),
                  _attachButton(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Obx(
              () => _ActionButton(
                label: 'Send feedback',
                icon: Icons.send_rounded,
                busy: controller.sending.value,
                onTap: controller.sending.value ? null : _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stars() {
    return Obx(() {
      final int rating = controller.rating.value;
      return Row(
        children: List.generate(5, (int i) {
          final bool on = i < rating;
          return Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : 10),
            child: Material(
              color: InnerChrome.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: InnerChrome.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => controller.setRating(i + 1),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    on ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 26,
                    color: on ? InnerChrome.accent : InnerChrome.faint,
                    semanticLabel: FeedbackController.ratingLabels[i],
                  ),
                ),
              ),
            ),
          );
        }),
      );
    });
  }

  Widget _chips() {
    return Obx(() {
      final String selected = controller.category.value;
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double gap = 10;
          const int maxPerRow = 3;
          final List<List<Widget>> rows = <List<Widget>>[];
          final List<Widget> current = <Widget>[];
          double used = 0;

          for (final String name in FeedbackController.categories) {
            final double chipWidth = _chipWidth(name, context);
            final double next = current.isEmpty ? chipWidth : used + gap + chipWidth;
            final bool rowFull = current.length >= maxPerRow;
            final bool noRoom = next > constraints.maxWidth - 2;
            if (current.isNotEmpty && (rowFull || noRoom)) {
              rows.add(List<Widget>.from(current));
              current.clear();
              used = 0;
            }
            current.add(_chip(name, selected == name));
            used = current.length == 1 ? chipWidth : used + gap + chipWidth;
          }
          if (current.isNotEmpty) {
            rows.add(List<Widget>.from(current));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var j = 0; j < rows[i].length; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      rows[i][j],
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      );
    });
  }

  double _chipWidth(String name, BuildContext context) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width + 26;
  }

  Widget _chip(String name, bool on) {
    return GestureDetector(
      onTap: () => controller.setCategory(name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? InnerChrome.accent : InnerChrome.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: on ? InnerChrome.accent : InnerChrome.line,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontFamily: _font,
            color: on ? Colors.white : InnerChrome.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _messageField() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );

    return Obx(
      () => TextField(
        controller: controller.messageController,
        minLines: 5,
        maxLines: 5,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontFamily: _font,
          color: InnerChrome.ink,
          fontSize: 15,
          height: 1.5,
        ),
        cursorColor: InnerChrome.accent,
        onChanged: (_) => controller.clearError(),
        decoration: InputDecoration(
          hintText: 'Write your feedback or suggestion here...',
          hintStyle: TextStyle(fontFamily: _font, color: InnerChrome.muted),
          errorText: controller.showError.value
              ? 'Please write a message first'
              : null,
          errorStyle: const TextStyle(fontFamily: _font),
          counterStyle: TextStyle(fontFamily: _font, color: InnerChrome.muted),
          filled: true,
          fillColor: InnerChrome.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: border(InnerChrome.line),
          focusedBorder: border(InnerChrome.accent),
          errorBorder: border(InnerChrome.danger),
          focusedErrorBorder: border(InnerChrome.danger),
        ),
      ),
    );
  }

  Widget _attachButton() {
    return Obx(() {
      final file = controller.screenshot.value;
      final bool hasFile = file != null;
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: controller.pickScreenshot,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: InnerChrome.line),
          ),
          child: Row(
            mainAxisAlignment: hasFile
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (hasFile) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(file.path),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _font,
                      color: InnerChrome.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove screenshot',
                  onPressed: controller.removeScreenshot,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: InnerChrome.muted,
                  ),
                ),
              ] else ...[
                Icon(Icons.image_outlined, size: 20, color: InnerChrome.muted),
                const SizedBox(width: 10),
                Text(
                  'Attach a screenshot (optional)',
                  style: TextStyle(
                    fontFamily: _font,
                    color: InnerChrome.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: GestureDetector(
        onTap: Get.back,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: InnerChrome.light ? Colors.white : InnerChrome.alt,
            shape: BoxShape.circle,
            border: Border.all(color: InnerChrome.line),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: InnerChrome.ink,
          ),
        ),
      ),
    );
  }
}

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({
    super.key,
    required this.category,
    required this.rating,
  });

  final String category;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const _CircleBackButton(),
        title: Text(
          'Feedback & Suggestions',
          style: TextStyle(
            fontFamily: _font,
            color: InnerChrome.ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: InnerChrome.card,
                  border: Border.all(color: InnerChrome.line),
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: InnerChrome.actionGradient,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Thank you!',
                style: TextStyle(
                  fontFamily: _font,
                  color: InnerChrome.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your feedback has been sent. We read every message and use it to improve the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _font,
                  color: InnerChrome.muted,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InnerChrome.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: InnerChrome.line),
                ),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Type', value: category),
                    const _SummaryDivider(),
                    _SummaryRow(label: 'Rating', value: '$rating / 5'),
                    const _SummaryDivider(),
                    const _SummaryRow(label: 'Status', value: 'Received'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _ActionButton(
                label: 'Back to app',
                onTap: () => Get.close(2),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: Get.back,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: InnerChrome.muted,
                ),
                child: const Text(
                  'Send another feedback',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: InnerChrome.actionGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: busy ? null : InnerChrome.actionShadow,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: busy ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 10),
                      Icon(icon, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: _font,
        color: InnerChrome.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: _font,
            color: InnerChrome.muted,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: _font,
            color: InnerChrome.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, thickness: 1, color: InnerChrome.line),
    );
  }
}
