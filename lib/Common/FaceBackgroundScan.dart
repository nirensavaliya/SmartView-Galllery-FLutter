import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/FaceGroupController.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';


const String _taskName = 'faceScanTask';
const String _periodicName = 'face_scan_periodic';
const String _oneOffName = 'face_scan_continue';

const Duration _maxJobTime = Duration(minutes: 8);

@pragma('vm:entry-point')
void faceScanCallbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();


      if (Get.isRegistered<FaceGroupController>()) {
        await Get.find<FaceGroupController>().refreshFromBackgroundJob();
      } else {
        final FaceGroupController controller = Get.put(
          FaceGroupController(background: true),
        );
        await controller.runBackgroundJob(maxDuration: _maxJobTime);
        await Get.delete<FaceGroupController>(force: true);
      }
    } catch (e) {
      debugPrint('FACE BG JOB ERROR = $e');
    }

    return true;
  });
}

class FaceBackgroundScan {
  FaceBackgroundScan._();

  static final Constraints _constraints = Constraints(
    networkType: NetworkType.notRequired,
    requiresBatteryNotLow: true,
  );

  static Future<void> init() async {
    if (!Platform.isAndroid) return;

    try {
      await Workmanager().initialize(faceScanCallbackDispatcher);

      await Workmanager().registerPeriodicTask(
        _periodicName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: _constraints,
      );
    } catch (e) {
      debugPrint('FACE BG INIT ERROR = $e');
    }
  }

  static Future<void> continueInBackground() async {
    if (!Platform.isAndroid) return;

    try {
      await Workmanager().registerOneOffTask(
        _oneOffName,
        _taskName,
        initialDelay: const Duration(minutes: 2),
        constraints: _constraints,
      );
    } catch (e) {
      debugPrint('FACE BG ONE-OFF ERROR = $e');
    }
  }
}
