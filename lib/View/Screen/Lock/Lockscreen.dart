import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/lock_setup_controller.dart';
import 'package:gallery_photos/View/Screen/Lock/PrivateScreen.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/Common/AppToast.dart';

const Color primaryBlue = Color(0xFF3978FF);

const Color lightBackground = Color(0xFFFFFFFF);
const Color darkBackground = Color(0xFF000000);

const Color lightText = Color(0xFF27334A);
const Color darkText = Color(0xFFF4F7FF);

const Color lightSecondaryText = Color(0xFF71809A);
const Color darkSecondaryText = Color(0xFF858FA3);

const Color lightInactive = Color(0xFF9AA8BC);
const Color darkInactive = Color(0xFF4F5B70);

const Color darkButton = Color(0xFF10182B);
const Color darkButtonBorder = Color(0xFF27344D);

class LockSetupScreen extends StatelessWidget {
  LockSetupScreen({super.key});

  final LockSetupController controller = Get.put(LockSetupController());
  void showResetSecurityQuestionDialog() {
    if (Get.isDialogOpen == true) {
      return;
    }

    final LockSetupController controller = this.controller;

    final Rxn<String> selectedQuestion = Rxn<String>();

    final TextEditingController answerController =
    TextEditingController();

    final List<String> questions = [
      'Who is your favorite actor ?',
      'What is your mobile NO?',
      'What is your favorite movie?',
      'In which city were you born?',
      'What is your favorite game ?',
      'What was your childhood nickname?',
    ];

    final String? savedQuestion =
        controller.savedSecurityQuestion;

    if (savedQuestion == null) {
      AppToast.show('Security question is not configured');

      return;
    }

    selectedQuestion.value = savedQuestion;

    Get.dialog(
      Builder(
        builder: (context) {
          return Dialog(
            backgroundColor: InnerChrome.dialogBg,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),

            child: Padding(
              padding: const EdgeInsets.all(14),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    'Reset Private Lock',
                    style: TextStyle(
                      color: InnerChrome.dialogInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Obx(
                    () => DropdownButtonFormField<String>(
                      value: selectedQuestion.value,

                      isExpanded: true,

                      dropdownColor:
                      InnerChrome.dialogDrop,

                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: InnerChrome.dialogIcon,
                      ),

                      decoration: InputDecoration(
                        hintText: 'Select Question',

                        hintStyle: TextStyle(
                          color: InnerChrome.dialogHint,
                          fontSize: 12,
                        ),

                        filled: true,

                        fillColor:
                        InnerChrome.dialogField,

                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(7),

                          borderSide: BorderSide.none,
                        ),

                        contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),

                      style: TextStyle(
                        color: InnerChrome.dialogInk,
                        fontSize: 12,
                      ),

                      items: questions.map((question) {
                        return DropdownMenuItem<String>(
                          value: question,

                          child: Text(
                            question,

                            overflow:
                            TextOverflow.ellipsis,

                            style: TextStyle(
                              color: InnerChrome.dialogInk,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),

                      onChanged: (value) {
                        selectedQuestion.value = value;
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: answerController,

                    style: TextStyle(
                      color: InnerChrome.dialogInk,
                      fontSize: 12,
                    ),

                    decoration: InputDecoration(
                      hintText:
                      'Enter your answer',

                      hintStyle: TextStyle(
                        color: InnerChrome.dialogHint,
                        fontSize: 12,
                      ),

                      filled: true,

                      fillColor:
                      InnerChrome.dialogField,

                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(7),

                        borderSide: BorderSide.none,
                      ),

                      contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 34,

                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedQuestion.value == null) {
                          AppToast.show('Please select a question');
                          return;
                        }

                        if (answerController.text.trim().isEmpty) {
                          AppToast.show('Please enter your answer');
                          return;
                        }

                        final bool correct =
                        controller.verifySecurityAnswer(
                          question: selectedQuestion.value!,
                          answer: answerController.text,
                        );

                        if (!correct) {
                          AppToast.show('Incorrect answer');
                          return;
                        }

await controller.resetConfiguredLock();

                        Get.back();
                      },

style: ElevatedButton.styleFrom(
                        backgroundColor: InnerChrome.dialogPrimaryBg,
                        foregroundColor: InnerChrome.dialogPrimaryFg,
                        elevation: 0,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(9),
                        ),
                      ),

                      child: const Text(
                        'RESET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 11),

                  SizedBox(
                    width: double.infinity,
                    height: 34,

                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                      },

                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        InnerChrome.dialogSecondaryBg,

                        foregroundColor: InnerChrome.dialogSecondaryFg,

                        elevation: 0,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(9),
                        ),
                      ),

                      child: const Text(
                        'Cancel',
                        style:
                        TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void showSecurityQuestionDialog() {
    if (Get.isDialogOpen == true) {
      return;
    }

    final Rxn<String> selectedQuestion = Rxn<String>();

    final TextEditingController answerController = TextEditingController();

    final List<String> questions = [
      'Who is your favorite actor ?',
      'What is your mobile NO?',
      'What is your favorite movie?',
      'In which city were you born?',
      'What is your favorite game ?',
      'What was your childhood nickname?',
    ];

    Get.dialog(
      Builder(
        builder: (context) {
          return Dialog(
            backgroundColor: InnerChrome.dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Security Question',
                    style: TextStyle(
                      color: InnerChrome.dialogInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Obx(
                    () => DropdownButtonFormField<String>(
                      value: selectedQuestion.value,
                      isExpanded: true,
                      dropdownColor: InnerChrome.dialogDrop,

                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: InnerChrome.dialogIcon,
                      ),

                      decoration: InputDecoration(
                        hintText: 'Select Question',

                        hintStyle: TextStyle(
                          color: InnerChrome.dialogHint,
                          fontSize: 12,
                        ),

                        filled: true,
                        fillColor: InnerChrome.dialogField,

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7),
                          borderSide: BorderSide.none,
                        ),

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),

                      style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),

                      items: questions.map((question) {
                        return DropdownMenuItem<String>(
                          value: question,
                          child: Text(
                            question,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: InnerChrome.dialogInk,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),

                      onChanged: (value) {
                        selectedQuestion.value = value;
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: answerController,

                    style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),

                    decoration: InputDecoration(
                      hintText: 'Enter your answer',

                      hintStyle: TextStyle(
                        color: InnerChrome.dialogHint,
                        fontSize: 12,
                      ),

                      filled: true,
                      fillColor: InnerChrome.dialogField,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide.none,
                      ),

                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedQuestion.value == null) {
                          AppToast.show('Please select a question');
                          return;
                        }

                        if (answerController.text.trim().isEmpty) {
                          AppToast.show('Please enter your answer');
                          return;
                        }

                        final String question = selectedQuestion.value!;
                        final String answer = answerController.text.trim();

                        await controller.saveSecurityQuestion(
                          question: question,
                          answer: answer,
                        );

                        Get.back();

                        Future.delayed(
                          const Duration(milliseconds: 250),
                          showDecoyPinOffer,
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: InnerChrome.dialogPrimaryBg,
                        foregroundColor: InnerChrome.dialogPrimaryFg,
                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),

                      child: const Text(
                        'SAVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 11),

                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: InnerChrome.dialogSecondaryBg,
                        foregroundColor: InnerChrome.dialogSecondaryFg,
                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),

                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void showDecoyPinOffer() {
    if (Get.isDialogOpen == true) {
      return;
    }

    final TextEditingController decoyController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    Get.dialog(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a decoy PIN',
                style: TextStyle(
                  color: InnerChrome.dialogInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Optional. This PIN opens an empty gallery. Your real PIN still opens private files.',
                style: TextStyle(color: InnerChrome.dialogIcon, fontSize: 11),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: decoyController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Enter 4 digit decoy PIN',
                  hintStyle: TextStyle(
                    color: InnerChrome.dialogHint,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: InnerChrome.dialogField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Confirm decoy PIN',
                  hintStyle: TextStyle(
                    color: InnerChrome.dialogHint,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: InnerChrome.dialogField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton(
                  onPressed: () async {
                    final String pin = decoyController.text.trim();
                    final String confirm = confirmController.text.trim();

                    if (pin.length != 4 || confirm.length != 4) {
                      AppToast.show('Enter a 4 digit decoy PIN');
                      return;
                    }

                    if (pin != confirm) {
                      AppToast.show('Decoy PIN does not match');
                      return;
                    }

                    final bool saved = await controller.saveDecoyPin(pin);
                    if (!saved) {
                      return;
                    }

                    AppToast.show('Decoy PIN enabled');
                    Get.back();
                    Get.to(() => PrivateScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InnerChrome.dialogPrimaryBg,
                    foregroundColor: InnerChrome.dialogPrimaryFg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'SAVE DECOY PIN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.to(() => PrivateScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InnerChrome.dialogSecondaryBg,
                    foregroundColor: InnerChrome.dialogSecondaryFg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Obx(() {

      if (controller.hasConfiguredLock.value) {
        return _UnlockExistingLockScreen(
          controller: controller,
          isDark: isDark,
          onReset: showResetSecurityQuestionDialog,
        );
      }

return Scaffold(
        backgroundColor:
        isDark ? darkBackground : lightBackground,

        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,

            onHorizontalDragEnd: (details) {
              final double velocity =
                  details.primaryVelocity ?? 0;

              if (velocity.abs() < 200) {
                return;
              }

              controller.handleHorizontalSwipe(velocity);
            },

            child: Obx(() {
              if (controller.isPatternMode) {
                return _PatternView(
                  controller: controller,
                  isDark: isDark,
                  onPatternComplete:
                  showSecurityQuestionDialog,
                );
              }

              return _PinView(
                controller: controller,
                isDark: isDark,
                onPinComplete:
                showSecurityQuestionDialog,
              );
            }),
          ),
        ),
      );
    });
  }

}
class _UnlockExistingLockScreen extends StatefulWidget {
  const _UnlockExistingLockScreen({
    required this.controller,
    required this.isDark,
    required this.onReset,
  });

  final LockSetupController controller;
  final bool isDark;
  final VoidCallback onReset;

  @override
  State<_UnlockExistingLockScreen> createState() =>
      _UnlockExistingLockScreenState();
}

class _UnlockExistingLockScreenState extends State<_UnlockExistingLockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.unlockWithFingerprint();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LockSetupController controller = widget.controller;
    final bool isDark = widget.isDark;
    final VoidCallback onReset = widget.onReset;

    return Scaffold(
      backgroundColor: isDark ? darkBackground : lightBackground,
      body: SafeArea(
        child: Obx(() {
          if (controller.isPatternMode) {
            return _ExistingPatternUnlockView(
              controller: controller,
              isDark: isDark,
              onReset: onReset,
            );
          }

          return _ExistingPinUnlockView(
            controller: controller,
            isDark: isDark,
            onReset: onReset,
          );
        }),
      ),
    );
  }
}

class _ExistingPinUnlockView extends StatelessWidget {
  const _ExistingPinUnlockView({
    required this.controller,
    required this.isDark,
    required this.onReset,
  });

  final LockSetupController controller;
  final bool isDark;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 55),

        _LockIcon(isDark: isDark),

        const SizedBox(height: 13),

        Text(
          'Enter your PIN',
          style: TextStyle(
            color: isDark ? darkText : lightText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Enter your 4-digit PIN to access Private',
          style: TextStyle(
            color: isDark ? darkSecondaryText : lightSecondaryText,
            fontSize: 10,
          ),
        ),

        const SizedBox(height: 25),

        Obx(() {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              LockSetupController.pinLength,
                  (index) {
                final bool filled =
                    index < controller.pin.value.length;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? primaryBlue
                        : isDark
                        ? const Color(0xFF394456)
                        : const Color(0xFFD0D7E2),
                    boxShadow: filled
                        ? const [
                      BoxShadow(
                        color: Color(0x663978FF),
                        blurRadius: 9,
                      ),
                    ]
                        : null,
                  ),
                );
              },
            ),
          );
        }),

        const SizedBox(height: 25),

        _FingerprintUnlockButton(controller: controller),

        Expanded(
          child: Center(
            child: _ExistingPinKeyboard(
              controller: controller,
              isDark: isDark,
            ),
          ),
        ),

        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onReset,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Reset',
              style: TextStyle(
                color: primaryBlue,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 5),
      ],
    );
  }
}

class _ExistingPinKeyboard extends StatelessWidget {
  const _ExistingPinKeyboard({required this.controller, required this.isDark});

  final LockSetupController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const List<String> numbers = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '',
      '0',
      'back',
    ];

    return SizedBox(
      width: 260,
      height: 330,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),

        itemCount: numbers.length,

        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.25,
          crossAxisSpacing: 18,
          mainAxisSpacing: 6,
        ),

        itemBuilder: (context, index) {
          final String value = numbers[index];

          if (value.isEmpty) {
            return const SizedBox();
          }

          if (value == 'back') {
            return _KeyboardButton(
              isDark: isDark,
              onTap: controller.removePinDigit,
              child: Icon(
                Icons.backspace_outlined,
                color: isDark
                    ? const Color(0xFFDCE3F0)
                    : const Color(0xFF43516A),
                size: 18,
              ),
            );
          }

          return _KeyboardButton(
            isDark: isDark,

            onTap: () {
              if (controller.pin.value.length >=
                  LockSetupController.pinLength) {
                return;
              }

              controller.addPinDigit(value);

              if (controller.pin.value.length ==
                  LockSetupController.pinLength) {
                Future.delayed(const Duration(milliseconds: 150), () {
                  controller.verifyUnlockPin(
                    onSuccess: () {
                      Get.off(() => PrivateScreen());
                    },
                  );
                });
              }
            },

            child: Text(
              value,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFF2F5FA)
                    : const Color(0xFF29354A),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExistingPatternUnlockView extends StatelessWidget {
  const _ExistingPatternUnlockView({
    required this.controller,
    required this.isDark,
    required this.onReset,
  });

  final LockSetupController controller;
  final bool isDark;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 35),

        Center(
          child: _LockIcon(isDark: isDark),
        ),

        const SizedBox(height: 13),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: Text(
            'Draw your security pattern to access Private',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? darkSecondaryText
                  : lightSecondaryText,
              fontSize: 10,
              height: 1.55,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: Center(
            child: SizedBox(
              width: 230,
              height: 260,
              child: _ExistingPatternGrid(
                controller: controller,
                isDark: isDark,
              ),
            ),
          ),
        ),

        _FingerprintUnlockButton(controller: controller),

        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onReset,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Reset',
              style: TextStyle(
                color: primaryBlue,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 5),
      ],
    );
  }
}

class _FingerprintUnlockButton extends StatelessWidget {
  const _FingerprintUnlockButton({required this.controller});

  final LockSetupController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.biometricController.isEnabled.value) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.unlockWithFingerprint,
        child: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Icon(
            Icons.fingerprint,
            color: primaryBlue,
            size: 36,
          ),
        ),
      );
    });
  }
}

class _ExistingPatternGrid extends StatelessWidget {
  const _ExistingPatternGrid({required this.controller, required this.isDark});

  final LockSetupController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onPanStart: (details) {
        controller.startPattern(details.localPosition);
      },

      onPanUpdate: (details) {
        controller.updatePattern(details.localPosition);
      },

      onPanEnd: (_) {
        controller.finishUnlockPattern(
          onSuccess: () {
            Get.off(() => PrivateScreen());
          },
        );
      },

      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Obx(() {
                final List<int> pattern = controller.selectedPattern.toList();
                final Offset? finger = controller.currentFingerPosition.value;

                return CustomPaint(
                  painter: _UnlockPatternPainter(
                    pattern: pattern,
                    finger: finger,
                  ),
                );
              }),
            ),
          ),

          ...List.generate(9, (index) {
            final int row = index ~/ 3;
            final int column = index % 3;

            return Positioned(
              left: column * 75.0 + 27,
              top: row * 75.0 + 12,

              child: Container(
                key: controller.patternKeys[index],
                width: 22,
                height: 22,

                child: Obx(() {
                  final bool selected = controller.selectedPattern.contains(
                    index,
                  );

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 140),

                    width: 22,
                    height: 22,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      color: isDark ? const Color(0xFF050A12) : Colors.white,

                      border: Border.all(
                        color: selected
                            ? primaryBlue
                            : isDark
                            ? const Color(0xFF243044)
                            : const Color(0xFFE0E7F0),
                        width: selected ? 1.5 : 1,
                      ),

                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: Color(0x663978FF),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),

                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),

                        width: selected ? 11 : 7,
                        height: selected ? 11 : 7,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: selected
                              ? primaryBlue
                              : isDark
                              ? darkInactive
                              : lightInactive,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _UnlockPatternPainter extends CustomPainter {
  _UnlockPatternPainter({
    required this.pattern,
    required this.finger,
  });

  final List<int> pattern;
  final Offset? finger;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern.isEmpty) {
      return;
    }

    final List<Offset> points = [];

    for (final int index in pattern) {
      final int row = index ~/ 3;
      final int column = index % 3;

      points.add(Offset(column * 75.0 + 38, row * 75.0 + 23));
    }

    final Paint glowPaint = Paint()
      ..color = const Color(0x553978FF)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint linePaint = Paint()
      ..color = primaryBlue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], glowPaint);
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    if (finger != null && points.isNotEmpty) {
      canvas.drawLine(points.last, finger!, glowPaint);
      canvas.drawLine(points.last, finger!, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UnlockPatternPainter oldDelegate) {
    return oldDelegate.finger != finger || oldDelegate.pattern != pattern;
  }
}

class _PatternView extends StatelessWidget {
  const _PatternView({
    required this.controller,
    required this.isDark,
    required this.onPatternComplete,
  });

  final LockSetupController controller;
  final bool isDark;

  final VoidCallback onPatternComplete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight;

        return Column(
          children: [
            const SizedBox(height: 35),

            Center(child: _LockIcon(isDark: isDark)),

            const SizedBox(height: 13),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 38),

              child: Text(
                'Draw your security pattern or authenticate\n'
                'with biometric sensor',

                textAlign: TextAlign.center,

                style: TextStyle(
                  color: isDark ? darkSecondaryText : lightSecondaryText,

                  fontSize: 10,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 9),

            const _SecurityStatus(),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: 230,
                  height: height < 700 ? 235 : 260,

                  child: _PatternGrid(
                    controller: controller,
                    isDark: isDark,
                    onPatternComplete: onPatternComplete,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),

              child: _FaceIdButton(isDark: isDark),
            ),

            const SizedBox(height: 13),

            _BottomActions(
              controller: controller,
              isDark: isDark,
              isPatternMode: true,
            ),

            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _SecurityStatus extends StatelessWidget {
  const _SecurityStatus();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 24,

      padding: const EdgeInsets.symmetric(horizontal: 10),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080D18) : const Color(0xFFFAFBFE),

        borderRadius: BorderRadius.circular(30),

        border: Border.all(
          color: isDark ? const Color(0xFF1D2A40) : const Color(0xFFE1E7F0),
        ),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            width: 6,
            height: 6,

            decoration: const BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 6),

          Text(
            '5 attempts left',

            style: TextStyle(
              color: isDark ? const Color(0xFF8A95A9) : const Color(0xFF627089),

              fontSize: 8.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),

            child: Text(
              '•',

              style: TextStyle(
                color: isDark
                    ? const Color(0xFF4B566A)
                    : const Color(0xFFB8C1CF),

                fontSize: 9,
              ),
            ),
          ),

          Text(
            'Auto-wipe active',

            style: TextStyle(
              color: isDark ? const Color(0xFF8A95A9) : const Color(0xFF627089),

              fontSize: 8.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternGrid extends StatelessWidget {
  const _PatternGrid({
    required this.controller,
    required this.isDark,
    required this.onPatternComplete,
  });

  final LockSetupController controller;
  final bool isDark;

  final VoidCallback onPatternComplete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onPanStart: (details) {
        controller.startPattern(details.localPosition);
      },

      onPanUpdate: (details) {
        controller.updatePattern(details.localPosition);
      },

      onPanEnd: (_) async {
        final bool saved = await controller.finishPattern();

        if (saved) {
          await Future.delayed(const Duration(milliseconds: 150));

          onPatternComplete();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,

        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Obx(() {
                final List<int> pattern = controller.selectedPattern.toList();
                final Offset? finger = controller.currentFingerPosition.value;

                return CustomPaint(
                  painter: _PatternPainter(
                    pattern: pattern,
                    finger: finger,
                  ),
                );
              }),
            ),
          ),

          ...List.generate(9, (index) {
            final int row = index ~/ 3;

            final int column = index % 3;

            return Positioned(
              left: column * 75.0 + 27,
              top: row * 75.0 + 12,

              child: Container(
                key: controller.patternKeys[index],

                width: 22,
                height: 22,

                child: Obx(() {
                  final bool selected = controller.selectedPattern.contains(
                    index,
                  );

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 140),

                    width: 22,
                    height: 22,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      color: isDark ? const Color(0xFF050A12) : Colors.white,

                      border: Border.all(
                        color: selected
                            ? primaryBlue
                            : isDark
                            ? const Color(0xFF243044)
                            : const Color(0xFFE0E7F0),

                        width: selected ? 1.5 : 1,
                      ),

                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: Color(0x663978FF),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),

                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),

                        width: selected ? 11 : 7,

                        height: selected ? 11 : 7,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: selected
                              ? primaryBlue
                              : isDark
                              ? darkInactive
                              : lightInactive,

                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x883978FF),
                                    blurRadius: 9,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.pattern,
    required this.finger,
  });

  final List<int> pattern;
  final Offset? finger;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern.isEmpty) {
      return;
    }

    final List<Offset> points = [];

    for (final int index in pattern) {
      final int row = index ~/ 3;
      final int column = index % 3;

      points.add(Offset(column * 75.0 + 38, row * 75.0 + 23));
    }

    final Paint glowPaint = Paint()
      ..color = const Color(0x553978FF)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint linePaint = Paint()
      ..color = primaryBlue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], glowPaint);
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    if (finger != null && points.isNotEmpty) {
      canvas.drawLine(points.last, finger!, glowPaint);
      canvas.drawLine(points.last, finger!, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.finger != finger || oldDelegate.pattern != pattern;
  }
}

class _LockIcon extends StatelessWidget {
  const _LockIcon({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),

      child: SizedBox(
        width: 68,
        height: 64,

        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,

          children: [
            Container(
              width: 50,
              height: 50,

              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF080E18)
                    : const Color(0xFFF9FBFF),

                borderRadius: BorderRadius.circular(13),

                border: Border.all(
                  color: isDark
                      ? const Color(0xFF263653)
                      : const Color(0xFFD9E3F5),
                ),

                boxShadow: [
                  BoxShadow(
                    color: const Color(0x553978FF),

                    blurRadius: isDark ? 22 : 20,

                    spreadRadius: isDark ? 1 : 3,
                  ),
                ],
              ),
            ),

            Icon(
              Icons.lock_outline_rounded,

              color: isDark ? const Color(0xFFE5EBF7) : primaryBlue,

              size: 25,
            ),

            Positioned(
              right: 3,
              bottom: 8,

              child: Container(
                width: 15,
                height: 15,

                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A1424) : Colors.white,

                  shape: BoxShape.circle,

                  border: Border.all(color: primaryBlue, width: 1.4),

                  boxShadow: const [
                    BoxShadow(color: Color(0x443978FF), blurRadius: 7),
                  ],
                ),

                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    color: primaryBlue,
                    size: 9,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceIdButton extends StatelessWidget {
  const _FaceIdButton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,

      decoration: BoxDecoration(
        color: isDark ? darkButton : const Color(0xFF11182B),

        borderRadius: BorderRadius.circular(13),

        border: Border.all(
          color: isDark ? darkButtonBorder : const Color(0xFF11182B),
        ),

        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x44000000) : const Color(0x28000000),

            blurRadius: 14,

            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            width: 24,
            height: 24,

            decoration: BoxDecoration(
              color: const Color(0x202F6FFF),

              borderRadius: BorderRadius.circular(6),

              border: Border.all(color: const Color(0x556A8EFF)),
            ),

            child: const Icon(
              Icons.face_retouching_natural_outlined,

              color: Color(0xFFDCE5FF),

              size: 14,
            ),
          ),

          const SizedBox(width: 10),

          const Text(
            'Unlock with Face ID',

            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 8),

          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF8290A9),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.controller,
    required this.isDark,
    required this.isPatternMode,
  });

  final LockSetupController controller;
  final bool isDark;
  final bool isPatternMode;

  @override
  Widget build(BuildContext context) {
    final Color label = isDark
        ? const Color(0xFFC5D0DE)
        : const Color(0xFF5C6E82);

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isPatternMode) {
              controller.switchToPin();
            } else {
              controller.switchToPattern();
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121925) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF243044)
                    : const Color(0xFFE3E8EF),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPatternMode
                      ? Icons.dialpad_outlined
                      : Icons.gesture_rounded,
                  color: label,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isPatternMode ? 'Use Custom PIN' : 'Use Pattern',
                  style: TextStyle(
                    color: label,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Forgot Pattern?',
              style: TextStyle(
                color: primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinView extends StatelessWidget {
  const _PinView({
    required this.controller,
    required this.isDark,
    required this.onPinComplete,
  });

  final LockSetupController controller;
  final bool isDark;

  final VoidCallback onPinComplete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight;

        return Column(
          children: [
            SizedBox(height: height < 700 ? 30 : 39),

            _LockIcon(isDark: isDark),

            const SizedBox(height: 13),

            Obx(
              () => Text(
                controller.isConfirmingPin.value
                    ? 'Confirm your PIN'
                    : 'Create your secure PIN',

                style: TextStyle(
                  color: isDark ? darkText : lightText,

                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Obx(
              () => Text(
                controller.isConfirmingPin.value
                    ? 'Enter the same 4-digit PIN again'
                    : 'Enter a 4-digit PIN to secure your gallery',

                style: TextStyle(
                  color: isDark ? darkSecondaryText : lightSecondaryText,

                  fontSize: 10,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Obx(() {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: List.generate(LockSetupController.pinLength, (index) {
                  final bool filled = index < controller.pin.value.length;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),

                    margin: const EdgeInsets.symmetric(horizontal: 6),

                    width: 11,
                    height: 11,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      color: filled
                          ? primaryBlue
                          : isDark
                          ? const Color(0xFF394456)
                          : const Color(0xFFD0D7E2),

                      boxShadow: filled
                          ? const [
                              BoxShadow(
                                color: Color(0x663978FF),
                                blurRadius: 9,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              );
            }),

            const SizedBox(height: 18),

            Expanded(
              child: Center(
                child: _PinKeyboard(
                  controller: controller,

                  isDark: isDark,

                  onPinComplete: onPinComplete,
                ),
              ),
            ),

            _BottomActions(
              controller: controller,

              isDark: isDark,

              isPatternMode: false,
            ),

            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _PinKeyboard extends StatelessWidget {
  const _PinKeyboard({
    required this.controller,
    required this.isDark,
    required this.onPinComplete,
  });

  final LockSetupController controller;
  final bool isDark;

  final VoidCallback onPinComplete;

  @override
  Widget build(BuildContext context) {
    const List<String> numbers = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '',
      '0',
      'back',
    ];

    return SizedBox(
      width: 260,
      height: 330,

      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),

        itemCount: numbers.length,

        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,

          childAspectRatio: 1.25,

          crossAxisSpacing: 18,

          mainAxisSpacing: 6,
        ),

        itemBuilder: (context, index) {
          final String value = numbers[index];

          if (value.isEmpty) {
            return const SizedBox();
          }

if (value == 'back') {
            return _KeyboardButton(
              isDark: isDark,

              onTap: controller.removePinDigit,

              child: Icon(
                Icons.backspace_outlined,

                color: isDark
                    ? const Color(0xFFDCE3F0)
                    : const Color(0xFF43516A),

                size: 18,
              ),
            );
          }

return _KeyboardButton(
            isDark: isDark,

            onTap: () {

              if (controller.pin.value.length >= 4) {
                return;
              }

controller.addPinDigit(value);

              if (controller.pin.value.length == 4) {
                Future.delayed(const Duration(milliseconds: 150), () async {
                  final bool saved = await controller.submitSetupPin();

                  if (saved) {
                    onPinComplete();
                  }
                });
              }
            },

            child: Text(
              value,

              style: TextStyle(
                color: isDark
                    ? const Color(0xFFF2F5FA)
                    : const Color(0xFF29354A),

                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: onTap,

      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),

          width: 68,
          height: 58,

          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF050A12) : const Color(0xFFFAFBFD),

            shape: BoxShape.circle,

            border: Border.all(
              color: isDark ? const Color(0xFF151E2E) : const Color(0xFFE8ECF2),
            ),

            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x55000000)
                    : const Color(0x10000000),

                blurRadius: 8,

                offset: const Offset(0, 2),
              ),
            ],
          ),

          child: Center(child: child),
        ),
      ),
    );
  }
}
