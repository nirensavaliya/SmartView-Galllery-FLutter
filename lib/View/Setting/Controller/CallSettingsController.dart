import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/AppToast.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class CallSettingsController extends GetxController {
  static const MethodChannel _channel = MethodChannel('native_camera');

  final RxBool phoneGranted = false.obs;
  final RxBool callLogGranted = false.obs;
  final RxBool contactsGranted = false.obs;
  final RxBool overlayGranted = false.obs;
  final RxBool enabled = false.obs;
  final RxBool busy = false.obs;

  bool get ready =>
      enabled.value &&
      phoneGranted.value &&
      overlayGranted.value;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final dynamic status = await _channel.invokeMethod('callOverlayStatus');
      if (status is Map) {
        phoneGranted.value = status['phone'] == true;
        callLogGranted.value = status['callLog'] == true;
        contactsGranted.value = status['contacts'] == true;
        overlayGranted.value = status['overlay'] == true;
        enabled.value = status['enabled'] == true;
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    if (!Platform.isAndroid) {
      AppToast.show('Call settings are available on Android');
      return;
    }
    if (busy.value) {
      return;
    }
    busy.value = true;
    try {
      if (!value) {
        await _channel.invokeMethod('setCallOverlayEnabled', {
          'enabled': false,
        });
        enabled.value = false;
        return;
      }

      final PermissionStatus phone = await Permission.phone.request();
      final PermissionStatus contacts = await Permission.contacts.request();
      phoneGranted.value = phone.isGranted;
      contactsGranted.value = contacts.isGranted;
      if (!callLogGranted.value) {
        await _channel.invokeMethod('requestCallLog');
      }
      await refreshStatus();

      if (!phoneGranted.value) {
        AppToast.show('Allow Phone permission to see incoming calls');
        enabled.value = false;
        return;
      }

      if (!callLogGranted.value) {
        await _channel.invokeMethod('requestCallLog');
        return;
      }

      if (!overlayGranted.value) {
        await _channel.invokeMethod('openOverlaySettings');
        AppToast.show('Allow display over other apps, then turn this on again');
        return;
      }

      await _channel.invokeMethod('setCallOverlayEnabled', {'enabled': true});
      enabled.value = true;
      AppToast.show('Incoming calls will show the caller and recent photos');
    } catch (_) {
      AppToast.show('Unable to update call settings');
    } finally {
      busy.value = false;
      await refreshStatus();
    }
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod('openOverlaySettings');
  }
}
