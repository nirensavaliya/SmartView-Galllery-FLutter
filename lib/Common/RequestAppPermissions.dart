import 'package:permission_handler/permission_handler.dart';

Future<void> RequestAppPermissions() async {
  final permissions = <Permission>[
    Permission.camera,
    Permission.location,
    Permission.notification,
    Permission.photos,
    Permission.videos,
    Permission.storage,
  ];

  final statuses = await permissions.request();

  print("Camera: ${statuses[Permission.camera]}");
  print("Location: ${statuses[Permission.location]}");
  print("Notification: ${statuses[Permission.notification]}");
  print("Photos: ${statuses[Permission.photos]}");
  print("Videos: ${statuses[Permission.videos]}");
  print("Storage: ${statuses[Permission.storage]}");
}