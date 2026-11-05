import 'package:photo_manager/photo_manager.dart';

class CleanerItemData {
  final AssetEntity asset;
  final String type;
  final int size;

  CleanerItemData({
    required this.asset,
    required this.type,
    required this.size,
  });
}