import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Splash/widgets/SplashLoader.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Lock/ChangeLockScreen.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/PrivatePhotoController.dart';
import 'package:gallery_photos/View/Screen/Lock/Controller/lock_setup_controller.dart';
import 'package:gallery_photos/View/Screen/Lock/IntruderSelfiesScreen.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';

class PrivateScreen extends StatelessWidget {
  PrivateScreen({super.key});

  final PrivateLockController controller = Get.put(
    PrivateLockController(),
    permanent: false,
  );

  final LockSetupController lockController =
      Get.isRegistered<LockSetupController>()
      ? Get.find<LockSetupController>()
      : Get.put(LockSetupController());
  List<String> get questions => [
    'Who is your favorite actor ?',
    'What is your mobile NO?',
    'What is your favorite movie?',
    'In which city were you born?',
    'What is your favorite game ?',
    'What was your childhood nickname?',
  ];

  void showChangeSecurityQuestionDialog() {
    if (Get.isDialogOpen == true) {
      return;
    }

    String selectedQuestion =
        lockController.savedSecurityQuestion ?? questions.first;

    final TextEditingController answerController = TextEditingController(
      text: lockController.controllerAnswerForEdit,
    );

    final RxString selected = selectedQuestion.obs;

    Get.dialog(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change security question',
                style: TextStyle(
                  color: InnerChrome.dialogInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 22),

              Obx(
                () => DropdownButtonFormField<String>(
                  value: selected.value,
                  isExpanded: true,
                  dropdownColor: InnerChrome.dialogDrop,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: InnerChrome.dialogIcon,
                  ),
                  decoration: InputDecoration(
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
                  items: questions
                      .map(
                        (question) => DropdownMenuItem<String>(
                          value: question,
                          child: Text(
                            question,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: InnerChrome.dialogInk,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selected.value = value;
                    }
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
                    final String answer = answerController.text.trim();

                    if (answer.isEmpty) {
                      AppToast.show('Please enter your answer');
                      return;
                    }

                    await lockController.saveSecurityQuestion(
                      question: selected.value,
                      answer: answer,
                    );

                    Get.back();

                    AppToast.show('Security question updated');
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(height: 11),

              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton(
                  onPressed: Get.back,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InnerChrome.dialogSecondaryBg,
                    foregroundColor: InnerChrome.dialogSecondaryFg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showChangeLockStyleDialog() {
    if (Get.isDialogOpen == true) {
      return;
    }

    final Rx<LockMode> selectedMode = lockController.mode.value.obs;

    Get.dialog(
      Dialog(
        backgroundColor: InnerChrome.dialogMenu,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change lock style',
                  style: TextStyle(
                    color: InnerChrome.dialogInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 22),

                GestureDetector(
                  onTap: () {
                    selectedMode.value = LockMode.pin;
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PIN',
                          style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
                        ),
                      ),
                      _RadioCircle(
                        selected: selectedMode.value == LockMode.pin,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                GestureDetector(
                  onTap: () {
                    selectedMode.value = LockMode.pattern;
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pattern',
                          style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
                        ),
                      ),
                      _RadioCircle(
                        selected: selectedMode.value == LockMode.pattern,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: Get.back,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InnerChrome.dialogPrimaryBg,
                          foregroundColor: InnerChrome.dialogPrimaryFg,
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

                    const SizedBox(width: 14),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final LockMode mode = selectedMode.value;

                          Get.back();

                          Future.delayed(const Duration(milliseconds: 150), () {
                            Get.to(
                              () => ChangeLockScreen(
                                targetMode: mode,
                                title: 'Change lock style',
                              ),
                            );
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InnerChrome.dialogSecondaryBg,
                          foregroundColor: InnerChrome.dialogSecondaryFg,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text('OK', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showDecoyPinDialog() {
    if (Get.isDialogOpen == true) {
      return;
    }

    final TextEditingController pinController = TextEditingController();

    final TextEditingController confirmController = TextEditingController();

    Get.dialog(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Set Decoy PIN',
                style: TextStyle(
                  color: InnerChrome.dialogInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'This PIN will open an empty private vault.',
                style: TextStyle(color: InnerChrome.dialogHint, fontSize: 11),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: pinController,

                keyboardType: TextInputType.number,

                maxLength: 4,

                obscureText: true,

                style: TextStyle(color: InnerChrome.dialogInk),

                decoration: InputDecoration(
                  hintText: 'Enter 4 digit Decoy PIN',
                  hintStyle: TextStyle(color: InnerChrome.dialogHint, fontSize: 12),
                  counterText: '',
                  filled: true,
                  fillColor: InnerChrome.dialogField,
                  border: InputBorder.none,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: confirmController,

                keyboardType: TextInputType.number,

                maxLength: 4,

                obscureText: true,

                style: TextStyle(color: InnerChrome.dialogInk),

                decoration: InputDecoration(
                  hintText: 'Confirm Decoy PIN',
                  hintStyle: TextStyle(color: InnerChrome.dialogHint, fontSize: 12),
                  counterText: '',
                  filled: true,
                  fillColor: InnerChrome.dialogField,
                  border: InputBorder.none,
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 38,

                child: ElevatedButton(
                  onPressed: () async {
                    final String pin = pinController.text.trim();

                    final String confirm = confirmController.text.trim();

                    if (pin.length != 4 || confirm.length != 4) {
                      AppToast.show('PIN must contain 4 digits');

                      return;
                    }
                    if (pin != confirm) {
                      AppToast.show('PIN does not match');
                      return;
                    }

                    final bool saved = await lockController.saveDecoyPin(pin);
                    if (!saved) {
                      return;
                    }

                    Get.back();

                    AppToast.show('Decoy PIN enabled successfully');
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 38,

                child: TextButton(
                  onPressed: () {
                    Get.back();
                  },

                  child: Text(
                    'Cancel',
                    style: TextStyle(color: InnerChrome.dialogIcon, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openChangePassword() {
    Get.to(
      () => ChangeLockScreen(
        targetMode: LockMode.pin,
        title: 'Change Password',
        replaceWithPin: true,
      ),
    );
  }

  void showMoreMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset position = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    showMenu<String>(
      context: context,
      color: InnerChrome.dialogMenu,
      position: RelativeRect.fromLTRB(
        position.dx - 135,
        position.dy + 40,
        overlay.size.width - position.dx - button.size.width,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'password',
          child: Text(
            'Change Password',
            style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
          ),
        ),
        PopupMenuItem<String>(
          value: 'question',
          child: Text(
            'Change security question',
            style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
          ),
        ),
        PopupMenuItem<String>(
          value: 'style',
          child: Text(
            'Change lock style',
            style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
          ),
        ),
        PopupMenuItem<String>(
          value: 'decoy',
          child: Text(
            'Set decoy PIN',
            style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
          ),
        ),
        PopupMenuItem<String>(
          value: 'recycle',
          child: Text(
            'Recycle bin',
            style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Text(
            'Settings',
            style: TextStyle(color: InnerChrome.dialogInk, fontSize: 12),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'password') {
        openChangePassword();
      }

      if (value == 'question') {
        showChangeSecurityQuestionDialog();
      }

      if (value == 'style') {
        showChangeLockStyleDialog();
      }

      if (value == 'decoy') {
        showDecoyPinDialog();
      }

      if (value == 'recycle') {
        AppToast.show('Recycle bin screen connect here');
      }

      if (value == 'settings') {
        AppToast.show('Settings screen connect here');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
        ),

        title: Text(
          'Private',
          style: TextStyle(
            fontFamily: FontFamily.robotoBold,
            fontSize: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                onPressed: () {
                  showMoreMenu(context);
                },
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          const IntruderSelfiesFolderTile(),
          Expanded(child: _buildPrivateFiles()),
        ],
      ),
    );
  }

  Widget _buildPrivateFiles() {
    return Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: SplashLoader());
        }

        if (controller.privateFiles.isEmpty) {
          return _EmptyPrivateView(controller: controller);
        }

        return RefreshIndicator(
          onRefresh: controller.refreshPrivateFiles,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(2),
            itemCount: controller.privateFiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              final File file = controller.privateFiles[index];

              return _PrivateMediaItem(file: file, controller: controller);
            },
          ),
        );
      });
  }
}

class _RadioCircle extends StatelessWidget {
  const _RadioCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? InnerChrome.accent : InnerChrome.muted,
          width: 1.2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: InnerChrome.accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _PrivateMediaItem extends StatelessWidget {
  const _PrivateMediaItem({required this.file, required this.controller});

  final File file;

  final PrivateLockController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        _showDeleteDialog(context, file);
      },
      child: Container(
        color: AppColors.surface(Colors.grey.shade200),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller.isImage(file))
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                      size: 35,
                    ),
                  );
                },
              ),

            if (controller.isVideo(file))
              Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),

            if (!controller.isImage(file) && !controller.isVideo(file))
              const Center(
                child: Icon(
                  Icons.insert_drive_file,
                  color: Colors.grey,
                  size: 35,
                ),
              ),

            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, File file) {
    Get.dialog(
      ChromeDialog(
        title: 'Delete Private File?',
        message: 'Do you want to permanently delete this file?',
        actions: [
          ChromeButton.cancel(onPressed: Get.back),
          ChromeButton.danger(
            label: 'Delete',
            onPressed: () async {
              Get.back();
              await controller.deletePrivateFile(file);
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyPrivateView extends StatelessWidget {
  const _EmptyPrivateView({required this.controller});

  final PrivateLockController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refreshPrivateFiles,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.32),
          Icon(
            Icons.lock_outline,
            size: 70,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
          ),
          SizedBox(height: 18),
          Center(
            child: Text(
              'No private photos',
              style: TextStyle(
                fontFamily: FontFamily.robotoMedium,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Photos you lock will appear here',
              style: TextStyle(
                fontFamily: FontFamily.robotoRegular,
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
