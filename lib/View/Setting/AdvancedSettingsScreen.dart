import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Setting/Controller/AdvancedSettingsController.dart';
import 'package:get/get.dart';

class AdvancedSettingsScreen extends StatelessWidget {
  AdvancedSettingsScreen({super.key});

  final AdvancedSettingsController controller = Get.put(AdvancedSettingsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.only(left: 8, right: 8, bottom: 20),
                child: Column(
                  children: [
                    _buildVideoSettings(context),

                    const SizedBox(height: 8),

                    _buildFullscreenMedia(context),

                    const SizedBox(height: 8),

                    _buildSecurity(context),

                    const SizedBox(height: 8),

                    _buildRecycleBin(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 62,
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Get.back();
            },
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 21,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          Text(
            "Advanced Settings",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSettings(BuildContext context) {
    return _settingsCard(
      context,
      title: "Video settings",
      children: [
        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.history_toggle_off_outlined,
            title: "Remember last video playback position",
            value: controller.rememberLastVideoPosition.value,
            onChanged: controller.toggleRememberLastVideoPosition,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.loop_rounded,
            title: "Loop videos",
            value: controller.loopVideos.value,
            onChanged: controller.toggleLoopVideos,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.touch_app_outlined,
            title:
                "Controlling video volume & brightness\n"
                "with vertical gestures",
            value: controller.videoVolumeBrightnessGestures.value,
            onChanged: controller.toggleVideoVolumeBrightnessGestures,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.smartphone_outlined,
            title: "Seek gesture",
            value: controller.seekGesture.value,
            onChanged: controller.toggleSeekGesture,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.zoom_in_outlined,
            title: "Pinch to zoom the video",
            value: controller.pinchToZoomVideo.value,
            onChanged: controller.togglePinchToZoomVideo,
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenMedia(BuildContext context) {
    return _settingsCard(
      context,
      title: "Fullscreen media",
      children: [
        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.wb_sunny_outlined,
            title:
                "Max brightness when viewing\n"
                "fullscreen media",
            value: controller.maxBrightnessFullscreen.value,
            onChanged: controller.toggleMaxBrightnessFullscreen,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.format_color_fill_outlined,
            title: "Black Background at fullscreen media",
            value: controller.blackBackgroundFullscreen.value,
            onChanged: controller.toggleBlackBackgroundFullscreen,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.fullscreen_outlined,
            title:
                "Automatically hide system ui at\n"
                "fullscreen Media",
            value: controller.hideSystemUiFullscreen.value,
            onChanged: controller.toggleHideSystemUiFullscreen,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.auto_awesome_outlined,
            title:
                "Allow instantly changing media by\n"
                "clicking on screen sides",
            value: controller.instantMediaChange.value,
            onChanged: controller.toggleInstantMediaChange,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.touch_app_outlined,
            title:
                "Allow Controlling photo brightness\n"
                "with vertical gestures",
            value: controller.photoBrightnessGestures.value,
            onChanged: controller.togglePhotoBrightnessGestures,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.swipe_down_outlined,
            title:
                "Allow Closing the fullscreen view with a\n"
                "down gesture",
            value: controller.closeFullscreenWithDownGesture.value,
            onChanged: controller.toggleCloseFullscreenWithDownGesture,
          ),
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.web_asset_outlined,
            title: "Show a notch if available",
            value: controller.showNotch.value,
            onChanged: controller.toggleShowNotch,
          ),
        ),

        _settingsTileWithSubtitle(
          context: context,
          icon: Icons.screen_rotation_outlined,
          title: "Rotate fullscreen media by",
          subtitle: "System setting",
          onTap: controller.rotateFullscreenMedia,
        ),
      ],
    );
  }

  Widget _buildSecurity(BuildContext context) {
    return _settingsCard(
      context,
      title: "Security",
      children: [
        _settingsTileWithSubtitle(
          context: context,
          icon: Icons.more_horiz_rounded,
          title: "Change Password",
          subtitle: "Change password for vault",
          onTap: controller.changePassword,
        ),

        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.fingerprint,
            title: "Fingerprint",
            value: controller.fingerprint.value,
            onChanged: controller.toggleFingerprint,
          ),
        ),

        _settingsTileWithSubtitle(
          context: context,
          icon: Icons.lock_outline_rounded,
          title: "Change unlock method",
          subtitle: "Change unlock method for vault",
          onTap: controller.changeUnlockMethod,
        ),
      ],
    );
  }

  Widget _buildRecycleBin(BuildContext context) {
    return _settingsCard(
      context,
      title: "Recycle bin",
      children: [
        Obx(
          () => _switchTile(
            context: context,
            icon: Icons.delete_outline_rounded,
            title: "Delete photos after 30 days",
            value: controller.deletePhotosAfter30Days.value,
            onChanged: controller.toggleDeletePhotosAfter30Days,
          ),
        ),

        _settingsTile(
          context: context,
          icon: Icons.delete_outline_rounded,
          title: "Empty recycle bin",
          onTap: controller.emptyRecycleBin,
        ),
      ],
    );
  }

  Widget _settingsCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontFamily: FontFamily.robotoBold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          ...children,
        ],
      ),
    );
  }

  Widget _settingsTile({
    required BuildContext context,
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
              color: Theme.of(context).colorScheme.onSurface,
            ),

            const SizedBox(width: 17),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: FontFamily.robotoBold,
                  color: Theme.of(context).colorScheme.onSurface,
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
    required BuildContext context,
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
              color: Theme.of(context).colorScheme.onSurface,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 1),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: FontFamily.robotoRegular,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: title.contains("\n") ? 67 : 54,
      child: Row(
        children: [
          const SizedBox(width: 10),

          Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),

          const SizedBox(width: 17),

          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontFamily: FontFamily.robotoBold,
                color: Theme.of(context).colorScheme.onSurface,
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
                    : const Color(0xFFB8B8B8);
              }),

              trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (isDark) {
                  return const Color(0xFF555555);
                }

                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF292929);
                }

                return const Color(0xFFF5F5F5);
              }),

              thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                return Colors.white;
              }),
            ),
          ),

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
