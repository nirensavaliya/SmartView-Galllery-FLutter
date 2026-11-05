import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Language/Controller/LanguageController.dart';
import 'package:gallery_photos/View/Setting/Controller/SettingsController.dart';
import 'package:get/get.dart';

import '../Constant/InnerChrome.dart';
import 'Controller/AdvancedSettingsController.dart';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key}) {
    controller.loadCacheSize();
  }

  final SettingsController controller = Get.find<SettingsController>();
  final AdvancedSettingsController advancedSettingsController = Get.put(AdvancedSettingsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading:   Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
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
        ),
        title:  Text(
            "Setting",
            style: TextStyle(
              color: InnerChrome.ink,
              fontSize: 19,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
      ),
      body: SafeArea(
        child: Column(
          children: [

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 20,top: 10),
                child: Column(
                  children: [
                    _buildFirstSection(),

                    const SizedBox(height: 8),

                    _buildFileSettingsSection(),

                    const SizedBox(height: 8),

                    _buildCallSettings(),

                    const SizedBox(height: 8),

                    _buildSimpleSettings(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 62,
      width: double.infinity,
      color: Theme.of(Get.context!).scaffoldBackgroundColor,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Get.back();
            },
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 21,
              color: Theme.of(Get.context!).colorScheme.onSurface,
            ),
          ),

          Text(
            "Settings",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(Get.context!).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildFirstSection() {
    return _settingsCard(
      children: [
        Obx(
          () => _switchTile(
            icon: Icons.nightlight_outlined,
            title: "Dark Mode",
            value: controller.darkMode.value,
            onChanged: controller.toggleDarkMode,
          ),
        ),

        // _settingsTile(
        //   icon: Icons.folder_outlined,
        //   title: "Manage excluded folders",
        //   onTap: controller.manageExcludedFolders,
        // ),
      ],
    );
  }

  Widget _buildFileSettingsSection() {
    return _settingsCard(
      children: [
        Obx(
          () => _switchTile(
            icon: Icons.folder_outlined,
            title:
                "Delete empty folders after deleting\n"
                "their content",
            value: controller.deleteEmptyFolders.value,
            onChanged: controller.toggleDeleteEmptyFolders,
          ),
        ),

        Obx(
          () => _switchTile(
            icon: Icons.folder_outlined,
            title:
                "Keep old last-modified value at file\n"
                "operations",
            value: controller.keepLastModified.value,
            onChanged: controller.toggleKeepLastModified,
          ),
        ),

        _settingsTile(
          icon: Icons.description_outlined,
          title: "Edited-file saving behavior",
          onTap: controller.editedFileSavingBehavior,
        ),
      ],
    );
  }

  Widget _buildCallSettings() {
    return _settingsCard(
      children: [
        InkWell(
          onTap: controller.callSettings,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.phone_in_talk_outlined,
                          size: 23,
                          color: Theme.of(Get.context!).colorScheme.onSurface,
                        ),

                        Positioned(
                          top: -3,
                          left: -2,
                          child: Obx(() {
                            if (controller.callOverlayReady.value) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(width: 17),

                    Text(
                      "Call Settings",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: FontFamily.robotoBold,
                        color: Theme.of(Get.context!).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),

                Obx(() {
                  if (controller.callPermissionsGranted.value) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 13),
                      Text(
                        "The Phone permission & Display over other apps\n"
                        "gives you instant access about who is calling you. It\n"
                        "helps to avoid spam calls and give instant access of\n"
                        "recently added photos and videos.",
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.12,
                          color: Theme.of(Get.context!).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSettings() {
    return Column(
      children: [
        // _settingsCard(
        //   children: [
        //     _settingsTileWithSubtitle(
        //       icon: Icons.settings_outlined,
        //       title: "Advanced Settings",
        //       subtitle: "Security, Video, Fullscreen media.",
        //       onTap: controller.advancedSettings,
        //     ),
        //   ],
        // ),
        //
        // const SizedBox(height: 8),

_settingsCard(
          children: [
            Obx(
                  () => _switchTile(
                icon: Icons.delete_outline_rounded,
                title: "Delete photos after 30 days",
                value: controller.deletePhotosAfter30Days.value,
                onChanged:
                controller.toggleDeletePhotosAfter30Days,
              ),
            ),

            _settingsTile(
              icon: Icons.delete_sweep_outlined,
              title: "Empty Recycle Bin",
              onTap: controller.emptyRecycleBin,
            ),
          ],
        ),

        const SizedBox(height: 8),

// Obx(
//               () {
//             final languageController =
//             Get.find<LanguageController>();
//
//             return _settingsTileWithSubtitle(
//               icon: Icons.language_outlined,
//               title: "Language",
//               subtitle:
//               languageController.selectedLanguageName,
//               onTap: controller.language,
//             );
//           },
//         ),

        const SizedBox(height: 8),

_settingsCard(
          children: [
            Obx(
              () => _settingsTileWithSubtitle(
                icon: Icons.cleaning_services_outlined,
                title: "Clear cache",
                subtitle: controller.cacheSizeLabel.value,
                onTap: controller.clearCache,
              ),
            ),

            _settingsTile(
              icon: Icons.star_border_rounded,
              title: "Rate Us",
              onTap: controller.rateUs,
            ),

            _settingsTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: "Feedback Or Suggestions",
              onTap: controller.feedback,
            ),

            _settingsTile(
              icon: Icons.share_outlined,
              title: "Share with friends",
              onTap: controller.shareWithFriends,
            ),

            _settingsTile(
              icon: Icons.description_outlined,
              title: "Privacy Policy",
              onTap: controller.privacyPolicy,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _settingsTileWithSubtitle(
          // context: context,
          icon: Icons.more_horiz_rounded,
          title: "Change Password",
          subtitle: "Change password for vault",
          onTap: advancedSettingsController.changePassword,
        ),
        const SizedBox(height: 8),

        Obx(
              () => _switchTile(
            // context: context,
            icon: Icons.fingerprint,
            title: "Fingerprint",
            value: advancedSettingsController.fingerprint.value,
            onChanged: advancedSettingsController.toggleFingerprint,
          ),
        ),
      ],
    );
  }


  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).cardColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: 10),

            Icon(
              icon,
              size: 22,
              color: Theme.of(Get.context!).colorScheme.onSurface,
            ),

            const SizedBox(width: 17),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: FontFamily.robotoBold,
                  color: Theme.of(Get.context!).colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _settingsTileWithSubtitle({
    // required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 55,
        child: Row(
          children: [
            const SizedBox(width: 10),

            Icon(
              icon,
              size: 22,
              color: Theme.of(Get.context!).colorScheme.onSurface,
            ),

            const SizedBox(width: 17),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: FontFamily.robotoBold,
                      color: Theme.of(Get.context!).colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 1),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: FontFamily.robotoRegular,
                      color: Theme.of(Get.context!).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;

    return SizedBox(
      height: title.contains("\n") ? 67 : 54,
      child: Row(
        children: [
          const SizedBox(width: 10),

          Icon(
            icon,
            size: 22,
            color: Theme.of(Get.context!).colorScheme.onSurface,
          ),

          const SizedBox(width: 17),

          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontFamily: FontFamily.robotoBold,
                color: Theme.of(Get.context!).colorScheme.onSurface,
              ),
            ),
          ),

          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: value,
              onChanged: onChanged,

              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((
                states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.transparent;
                }

                return isDark
                    ? const Color(0xFF555555)
                    : const Color(0xFFBDBDBD);
              }),
              trackColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) {
                  if (states.contains(WidgetState.selected)) {
                    return isDark
                        ? const Color(0xFF292929)
                        : const Color(0xFF292929);
                  }

                  return isDark
                      ? const Color(0xFF353535)
                      : const Color(0xFFF7F7F7);
                },
              ),
              thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white; // ON
                }

                return Colors.black; // OFF
              }),
            ),
          ),

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
