import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_photos/View/Constant/Get_Storage.dart';

const String _permissionsAlreadyAskedKey = "permissions_already_asked";

Future<void> RequestAppPermissions() async {
  final bool alreadyAsked = GetStorageData.readBoolean(
    _permissionsAlreadyAskedKey,
    defaultValue: false,
  );

  if (alreadyAsked) {
    if (!await Permission.camera.isGranted) {
      await Permission.camera.request();
    }
    return;
  }

  await PhotoManager.requestPermissionExtend(
    requestOption: const PermissionRequestOption(
      androidPermission: AndroidPermission(
        type: RequestType.common,
        mediaLocation: true,
      ),
    ),
  );
  await Permission.location.request();
  await Permission.notification.request();
  await Permission.camera.request();
  await PhotoManager.clearFileCache();

  await GetStorageData.saveBoolean(_permissionsAlreadyAskedKey, true);
}
