import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Setting/Controller/CallSettingsController.dart';
import 'package:get/get.dart';

class CallSettingsScreen extends StatefulWidget {
  const CallSettingsScreen({super.key});

  @override
  State<CallSettingsScreen> createState() => _CallSettingsScreenState();
}

class _CallSettingsScreenState extends State<CallSettingsScreen> with WidgetsBindingObserver {
  late final CallSettingsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(CallSettingsController());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Get.isRegistered<CallSettingsController>()) {
      Get.delete<CallSettingsController>();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InnerChrome.page,
      appBar: AppBar(
        backgroundColor: InnerChrome.page,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
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
              onPressed: Get.back,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: InnerChrome.ink,
                size: 18,
              ),
            ),
          ),
        ),
        title: Text(
          'Call Settings',
          style: TextStyle(
            color: InnerChrome.ink,
            fontSize: 19,
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: Obx(() {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'When someone calls, a card shows who it is and your latest photos. Saved contacts show a name. Other numbers are marked unknown.',
              style: TextStyle(
                color: InnerChrome.muted,
                fontSize: 14,
                height: 1.35,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: InnerChrome.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: InnerChrome.line),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Show on incoming calls',
                  style: TextStyle(
                    color: InnerChrome.ink,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  controller.ready
                      ? 'On. A quiet notification keeps this running.'
                      : 'Needs Phone and display over other apps.',
                  style: TextStyle(
                    color: InnerChrome.muted,
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                  ),
                ),
                value: controller.enabled.value && controller.overlayGranted.value,
                activeThumbColor: InnerChrome.accent,
                onChanged: controller.busy.value ? null : controller.setEnabled,
              ),
            ),
            const SizedBox(height: 12),
            _statusTile(
              icon: Icons.phone_in_talk_outlined,
              title: 'Phone',
              granted: controller.phoneGranted.value,
              detail: 'Needed to know a call is ringing',
            ),
            _statusTile(
              icon: Icons.contacts_outlined,
              title: 'Contacts',
              granted: controller.contactsGranted.value,
              detail: 'Shows the saved name for the caller',
            ),
            _statusTile(
              icon: Icons.history_rounded,
              title: 'Call log',
              granted: controller.callLogGranted.value,
              detail: 'Shows the incoming number',
            ),
            _statusTile(
              icon: Icons.layers_outlined,
              title: 'Display over other apps',
              granted: controller.overlayGranted.value,
              detail: 'Puts the card on top of the call screen',
              onTap: controller.overlayGranted.value
                  ? null
                  : controller.openOverlaySettings,
            ),
          ],
        );
      }),
    );
  }

  Widget _statusTile({
    required IconData icon,
    required String title,
    required bool granted,
    required String detail,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: InnerChrome.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: InnerChrome.line),
            ),
            child: Row(
              children: [
                Icon(icon, color: InnerChrome.ink, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: InnerChrome.ink,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          color: InnerChrome.muted,
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  granted ? 'Allowed' : 'Needed',
                  style: TextStyle(
                    color: granted ? InnerChrome.accent : InnerChrome.danger,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
