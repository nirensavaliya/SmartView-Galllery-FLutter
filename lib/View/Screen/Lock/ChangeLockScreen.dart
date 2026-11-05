import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/BiometricController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/PrivatePhotoController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/lock_setup_controller.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/Common/AppToast.dart';

class ChangeLockScreen
    extends StatelessWidget {
  ChangeLockScreen({
    super.key,
    required this.targetMode,
    required this.title,
    this.replaceWithPin = false,
  });

  final LockMode targetMode;

  final String title;

  final bool replaceWithPin;

  final ChangeLockController controller =
  Get.put(
    ChangeLockController(),
  );

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark
          ? Colors.black
          : Colors.white,

      appBar: AppBar(
        backgroundColor:
        isDark
            ? Colors.black
            : Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(
            Icons.arrow_back_ios_new,
            color:
            isDark
                ? Colors.white
                : Colors.black,
            size: 19,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color:
            isDark
                ? Colors.white
                : Colors.black,
            fontSize: 17,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ),

      body: Obx(
            () {
          if (replaceWithPin) {
            controller.promptFingerprintOnce();
          }

          final LockMode nextMode = replaceWithPin
              ? LockMode.pin
              : targetMode;

          if (controller.step.value ==
              0) {
            return _CurrentLockView(
              controller:
              controller,
              isDark: isDark,
              replaceWithPin: replaceWithPin,
            );
          }

          if (controller.step.value ==
              1) {
            return _NewLockView(
              controller:
              controller,
              isDark: isDark,
              mode: nextMode,
              confirm: false,
            );
          }

          return _NewLockView(
            controller:
            controller,
            isDark: isDark,
            mode: nextMode,
            confirm: true,
          );
        },
      ),
    );
  }
}

class ChangeLockController
    extends GetxController {
  final PrivateLockController
  privateController =
  Get.find<PrivateLockController>();

  final RxInt step = 0.obs;

  final RxString pin = ''.obs;

  final RxList<int> pattern =
      <int>[].obs;

  final Rx<Offset?> fingerPosition =
  Rx<Offset?>(null);

  final List<GlobalKey> patternKeys =
  List.generate(
    9,
        (_) => GlobalKey(),
  );

  final RxString firstPin = ''.obs;

  final RxList<int> firstPattern =
      <int>[].obs;

  bool fingerprintPrompted = false;

  void promptFingerprintOnce() {
    if (fingerprintPrompted) {
      return;
    }

    fingerprintPrompted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unlockCurrentWithFingerprint(silent: true);
    });
  }

  Future<void> unlockCurrentWithFingerprint({
    bool silent = false,
  }) async {
    if (step.value != 0) {
      return;
    }

    if (!Get.isRegistered<BiometricController>()) {
      if (!silent) {
        AppToast.show('Turn on Fingerprint in Advanced Settings');
      }
      return;
    }

    final BiometricController biometric =
        Get.find<BiometricController>();
    biometric.loadBiometricSetting();

    if (!biometric.isEnabled.value) {
      if (!silent) {
        AppToast.show('Turn on Fingerprint in Advanced Settings');
      }
      return;
    }

    final bool verified = await biometric.authenticate();

    if (!verified || isClosed || step.value != 0) {
      if (!verified && !silent) {
        AppToast.show('Fingerprint not recognized');
      }
      return;
    }

    pin.value = '';
    pattern.clear();
    fingerPosition.value = null;
    step.value = 1;
  }

  @override
  void onInit() {
    super.onInit();

    reset();
  }

void reset() {
    step.value = 0;

    pin.value = '';

    pattern.clear();

    firstPin.value = '';

    firstPattern.clear();

    fingerPosition.value = null;
  }

void addPin(String value) {
    if (pin.value.length >= 4) {
      return;
    }

    pin.value += value;
  }

  void removePin() {
    if (pin.value.isEmpty) {
      return;
    }

    pin.value =
        pin.value.substring(
          0,
          pin.value.length - 1,
        );
  }

  bool verifyCurrentPin() {
    final bool valid = privateController.verifyPinValue(pin.value);

    pin.value = '';

    if (!valid) {
      AppToast.show('Incorrect PIN');
      return false;
    }

    step.value = 1;
    return true;
  }

void startCurrentPattern(
      Offset position,
      ) {
    pattern.clear();

    fingerPosition.value =
        position;

    final int? index =
    getPoint(position);

    if (index != null) {
      pattern.add(index);
    }
  }

  void updateCurrentPattern(
      Offset position,
      ) {
    fingerPosition.value =
        position;

    final int? index =
    getPoint(position);

    if (index != null &&
        !pattern.contains(index)) {
      pattern.add(index);
    }
  }

  void finishCurrentPattern() {
    fingerPosition.value = null;

    if (pattern.length < 4) {
      pattern.clear();

      AppToast.show('Pattern must contain at least 4 points');

      return;
    }

    final bool valid =
    privateController
        .verifyPatternValue(
      List<int>.from(pattern),
    );

    pattern.clear();

    if (!valid) {
      AppToast.show('Incorrect pattern');

      return;
    }

    step.value = 1;
  }

void saveFirstPin() {
    if (pin.value.length != 4) {
      return;
    }

    firstPin.value =
        pin.value;

    pin.value = '';

    step.value = 2;
  }

  Future<void> saveNewPin() async {
    if (pin.value.length != 4) {
      return;
    }

    if (pin.value != firstPin.value) {
      pin.value = '';

      step.value = 1;

      AppToast.show('PIN does not match');

      return;
    }

    final bool saved =
    await privateController
        .savePinValue(
      pin.value,
    );

    if (!saved) {
      AppToast.show('Unable to save PIN');

      return;
    }

    pin.value = '';

    if (Get.isRegistered<LockSetupController>()) {
      final LockSetupController lock =
          Get.find<LockSetupController>();
      lock.loadSavedLockMode();
      lock.loadConfiguredLock();
    }

    Get.back();

    AppToast.show('PIN changed successfully');
  }

void startNewPattern(
      Offset position,
      ) {
    pattern.clear();

    fingerPosition.value =
        position;

    final int? index =
    getPoint(position);

    if (index != null) {
      pattern.add(index);
    }
  }

  void updateNewPattern(
      Offset position,
      ) {
    fingerPosition.value =
        position;

    final int? index =
    getPoint(position);

    if (index != null &&
        !pattern.contains(index)) {
      pattern.add(index);
    }
  }

  void finishFirstPattern() {
    fingerPosition.value = null;

    if (pattern.length < 4) {
      pattern.clear();

      AppToast.show('Pattern must contain at least 4 points');

      return;
    }

    firstPattern.assignAll(
      pattern,
    );

    pattern.clear();

    step.value = 2;
  }

  Future<void> saveNewPattern() async {
    fingerPosition.value = null;

    if (pattern.length < 4) {
      pattern.clear();

      AppToast.show('Pattern must contain at least 4 points');

      return;
    }

    if (!_listEquals(
      pattern,
      firstPattern,
    )) {
      pattern.clear();

      step.value = 1;

      AppToast.show('Pattern does not match');

      return;
    }

    final bool saved =
    await privateController
        .savePatternValue(
      List<int>.from(pattern),
    );

    if (!saved) {
      AppToast.show('Unable to save pattern');

      return;
    }

    pattern.clear();

    Get.back();

    AppToast.show('Lock style changed successfully');
  }

  int? getPoint(Offset localPosition) {
    const double hitRadius = 36;

    for (int i = 0; i < 9; i++) {
      final int row = i ~/ 3;
      final int column = i % 3;
      final Offset center = Offset(
        column * 75.0 + 38,
        row * 75.0 + 23,
      );

      if ((localPosition - center).distance <= hitRadius) {
        return i;
      }
    }

    return null;
  }

  bool _listEquals(
      List<int> a,
      List<int> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0;
    i < a.length;
    i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }
}

class _CurrentLockView
    extends StatelessWidget {
  const _CurrentLockView({
    required this.controller,
    required this.isDark,
    required this.replaceWithPin,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  final bool replaceWithPin;

  @override
  Widget build(
      BuildContext context,
      ) {
    final PrivateLockController
    privateController =
        controller.privateController;

    final bool askPattern = privateController.isPattern &&
        !(replaceWithPin && privateController.hasSavedPin);

    if (askPattern) {
      return _CurrentPattern(
        controller: controller,
        isDark: isDark,
      );
    }

    return _CurrentPin(
      controller: controller,
      isDark: isDark,
    );
  }
}

class _CurrentPin
    extends StatelessWidget {
  const _CurrentPin({
    required this.controller,
    required this.isDark,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        const SizedBox(height: 45),

        const Icon(
          Icons.lock_outline,
          size: 55,
          color: Colors.blue,
        ),

        const SizedBox(height: 18),

        Text(
          'Enter current PIN',
          style: TextStyle(
            color:
            isDark
                ? Colors.white
                : Colors.black,
            fontSize: 16,
            fontWeight:
            FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Enter your current PIN to continue',
          style: TextStyle(
            color:
            isDark
                ? Colors.white54
                : Colors.black54,
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 25),

        Obx(
              () => Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children:
            List.generate(
              4,
                  (index) {
                return Container(
                  margin:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 6,
                  ),
                  width: 11,
                  height: 11,
                  decoration:
                  BoxDecoration(
                    color: index <
                        controller
                            .pin
                            .value
                            .length
                        ? Colors.blue
                        : Colors.grey,
                    shape:
                    BoxShape.circle,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 25),

        _FingerprintShortcut(controller: controller),

        Expanded(
          child:
          _ChangePinKeyboard(
            controller:
            controller,
            isDark: isDark,
            onComplete:
            controller
                .verifyCurrentPin,
          ),
        ),
      ],
    );
  }
}

class _NewLockView
    extends StatelessWidget {
  const _NewLockView({
    required this.controller,
    required this.isDark,
    required this.mode,
    required this.confirm,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  final LockMode mode;

  final bool confirm;

  @override
  Widget build(
      BuildContext context,
      ) {
    if (mode == LockMode.pin) {
      return _NewPinView(
        controller:
        controller,
        isDark: isDark,
        confirm: confirm,
      );
    }

    return _NewPatternView(
      controller:
      controller,
      isDark: isDark,
      confirm: confirm,
    );
  }
}

class _NewPinView
    extends StatelessWidget {
  const _NewPinView({
    required this.controller,
    required this.isDark,
    required this.confirm,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  final bool confirm;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        const SizedBox(height: 45),

        const Icon(
          Icons.lock_outline,
          size: 55,
          color: Colors.blue,
        ),

        const SizedBox(height: 18),

        Text(
          confirm
              ? 'Confirm new PIN'
              : 'Enter new PIN',
          style: TextStyle(
            color:
            isDark
                ? Colors.white
                : Colors.black,
            fontSize: 16,
            fontWeight:
            FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Enter a 4-digit PIN',
          style: TextStyle(
            color:
            isDark
                ? Colors.white54
                : Colors.black54,
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 25),

        Obx(
              () => Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children:
            List.generate(
              4,
                  (index) {
                return Container(
                  margin:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 6,
                  ),
                  width: 11,
                  height: 11,
                  decoration:
                  BoxDecoration(
                    color: index <
                        controller
                            .pin
                            .value
                            .length
                        ? Colors.blue
                        : Colors.grey,
                    shape:
                    BoxShape.circle,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 25),

        Expanded(
          child:
          _ChangePinKeyboard(
            controller:
            controller,
            isDark: isDark,
            onComplete: confirm
                ? controller
                .saveNewPin
                : controller
                .saveFirstPin,
          ),
        ),
      ],
    );
  }
}

class _ChangePinKeyboard
    extends StatelessWidget {
  const _ChangePinKeyboard({
    required this.controller,
    required this.isDark,
    required this.onComplete,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  final dynamic Function()
  onComplete;

  @override
  Widget build(
      BuildContext context,
      ) {
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
        physics:
        const NeverScrollableScrollPhysics(),
        itemCount:
        numbers.length,
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.25,
          crossAxisSpacing: 18,
          mainAxisSpacing: 6,
        ),
        itemBuilder:
            (context, index) {
          final String value =
          numbers[index];

          if (value.isEmpty) {
            return const SizedBox();
          }

          if (value == 'back') {
            return GestureDetector(
              onTap: controller
                  .removePin,
              child: const Center(
                child: Icon(
                  Icons
                      .backspace_outlined,
                  size: 19,
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () {
              if (controller
                  .pin
                  .value
                  .length >=
                  4) {
                return;
              }

              controller.addPin(
                value,
              );

              if (controller
                  .pin
                  .value
                  .length ==
                  4) {
                Future.delayed(
                  const Duration(
                    milliseconds: 150,
                  ),
                      () {
                    onComplete();
                  },
                );
              }
            },
            child: Center(
              child: Container(
                width: 68,
                height: 58,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors
                        .white12
                        : Colors
                        .black12,
                  ),
                ),
                child: Center(
                  child: Text(
                    value,
                    style:
                    TextStyle(
                      color: isDark
                          ? Colors
                          .white
                          : Colors
                          .black,
                      fontSize: 18,
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurrentPattern
    extends StatelessWidget {
  const _CurrentPattern({
    required this.controller,
    required this.isDark,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        const SizedBox(height: 45),

        const Icon(
          Icons.lock_outline,
          size: 55,
          color: Colors.blue,
        ),

        const SizedBox(height: 18),

        Text(
          'Draw current pattern',
          style: TextStyle(
            color:
            isDark
                ? Colors.white
                : Colors.black,
            fontSize: 16,
            fontWeight:
            FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Draw your current pattern to continue',
          style: TextStyle(
            color:
            isDark
                ? Colors.white54
                : Colors.black54,
            fontSize: 11,
          ),
        ),

        Expanded(
          child: Center(
            child: _PatternInput(
              controller:
              controller,
              isDark: isDark,
              firstStep: true,
            ),
          ),
        ),

        _FingerprintShortcut(controller: controller),

        const SizedBox(height: 18),
      ],
    );
  }
}

class _NewPatternView
    extends StatelessWidget {
  const _NewPatternView({
    required this.controller,
    required this.isDark,
    required this.confirm,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  final bool confirm;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        const SizedBox(height: 45),

        const Icon(
          Icons.lock_outline,
          size: 55,
          color: Colors.blue,
        ),

        const SizedBox(height: 18),

        Text(
          confirm
              ? 'Confirm new pattern'
              : 'Draw new pattern',
          style: TextStyle(
            color:
            isDark
                ? Colors.white
                : Colors.black,
            fontSize: 16,
            fontWeight:
            FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Use at least 4 points',
          style: TextStyle(
            color:
            isDark
                ? Colors.white54
                : Colors.black54,
            fontSize: 11,
          ),
        ),

        Expanded(
          child: Center(
            child: _PatternInput(
              controller:
              controller,
              isDark: isDark,
              firstStep: !confirm,
            ),
          ),
        ),
      ],
    );
  }
}

class _PatternInput
    extends StatelessWidget {
  const _PatternInput({
    required this.controller,
    required this.isDark,
    required this.firstStep,
  });

  final ChangeLockController
  controller;

  final bool isDark;

  final bool firstStep;

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      behavior:
      HitTestBehavior.opaque,

      onPanStart: (details) {
        final Offset local = details.localPosition;

        if (firstStep) {
          if (controller.step.value ==
              0) {
            controller
                .startCurrentPattern(
              local,
            );
          } else {
            controller
                .startNewPattern(
              local,
            );
          }
        } else {
          controller
              .startNewPattern(
            local,
          );
        }
      },

      onPanUpdate: (details) {
        final Offset local = details.localPosition;

        if (controller.step.value ==
            0) {
          controller
              .updateCurrentPattern(
            local,
          );
        } else {
          controller
              .updateNewPattern(
            local,
          );
        }
      },

      onPanEnd: (_) {
        if (controller.step.value ==
            0) {
          controller
              .finishCurrentPattern();
        } else if (controller.step.value ==
            1) {
          controller
              .finishFirstPattern();
        } else {
          controller
              .saveNewPattern();
        }
      },

      child: SizedBox(
        width: 230,
        height: 230,
        child: Obx(() {
          final List<int> points =
              controller.pattern.toList();

          return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter:
                _ChangePatternPainter(
                  points: points,
                  finger: controller.fingerPosition.value,
                  isDark: isDark,
                ),
              ),
            ),

            ...List.generate(
              9,
                  (index) {
                final int row =
                    index ~/ 3;

                final int column =
                    index % 3;

                final bool selected =
                    points.contains(index);

                return Positioned(
                  left:
                  column * 75.0 +
                      27,
                  top:
                  row * 75.0 +
                      12,
                  child: Container(
                    key: controller
                        .patternKeys[index],
                    width: 22,
                    height: 22,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      color: isDark
                          ? Colors
                          .black
                          : Colors.white,
                      border:
                      Border.all(
                        color:
                        selected
                            ? Colors
                            .blue
                            : Colors
                            .grey,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: selected
                            ? 10
                            : 7,
                        height: selected
                            ? 10
                            : 7,
                        decoration:
                        BoxDecoration(
                          color: selected
                              ? Colors
                              .blue
                              : Colors
                              .grey,
                          shape:
                          BoxShape
                              .circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
        }),
      ),
    );
  }
}

class _ChangePatternPainter
    extends CustomPainter {
  _ChangePatternPainter({
    required this.points,
    required this.finger,
    required this.isDark,
  });

  final List<int> points;

  final Offset? finger;

  final bool isDark;

  Offset _center(int index) {
    return Offset(
      (index % 3) * 75.0 + 38,
      (index ~/ 3) * 75.0 + 23,
    );
  }

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    if (points.isEmpty) {
      return;
    }

    final Paint paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..strokeCap =
          StrokeCap.round;

    for (int i = 0;
    i < points.length - 1;
    i++) {
      canvas.drawLine(
        _center(points[i]),
        _center(points[i + 1]),
        paint,
      );
    }

    if (finger != null) {
      canvas.drawLine(
        _center(points.last),
        finger!,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant _ChangePatternPainter
      oldDelegate,
      ) {
    return true;
  }
}

class _FingerprintShortcut extends StatelessWidget {
  const _FingerprintShortcut({
    required this.controller,
  });

  final ChangeLockController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.unlockCurrentWithFingerprint,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Icon(
          Icons.fingerprint,
          color: Colors.blue,
          size: 34,
        ),
      ),
    );
  }
}