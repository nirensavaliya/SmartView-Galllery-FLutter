import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/Photos/CopyMoveAlbumScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/VideoViewScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/WallpaperScreen.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoEditScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class PhotoViewController extends GetxController {
  final AssetEntity asset;
  final List<AssetEntity>? albumMedia;
  final String? customAlbumName;
  PhotoViewController(this.asset, {this.albumMedia, this.customAlbumName});
  final RxBool isFavorite = false.obs;
  final RxBool isDeleting = false.obs;
  final RxBool miniVideoIsPlaying = false.obs;
  final RxInt currentIndex = 0.obs;
  final RxBool showMiniVideo = true.obs;
  Future<void> _miniVideoToggleQueue = Future.value();
  Future<File?>? fileFuture;
  VideoPlayerController? miniVideoController;
  final RxBool isCopyMoveLoading = false.obs;
  AssetEntity? _renamedAsset;
  File? _renamedFile;
  final RxBool isSlideshow = false.obs;
  Timer? slideshowTimer;
  Duration slideshowDuration = const Duration(seconds: 1);
  String slideshowAnimation = "None";
  bool slideshowIncludeGifs = true;
  bool slideshowRandomOrder = false;
  bool slideshowMoveBackwards = false;
  bool slideshowLoop = false;
  final PageController slideshowPageController = PageController();
  final RxDouble miniVideoX = 12.0.obs;
  final RxDouble miniVideoY = 100.0.obs;
  @override
  void onInit() {
    super.onInit();
    isFavorite.value = asset.isFavorite;
  }

  void initializePhotoView() {
    if (albumMedia != null) {
      final index = albumMedia!.indexWhere((element) => element.id == asset.id);
      currentIndex.value = index == -1 ? 0 : index;
    } else if (Get.isRegistered<PhotosController>()) {
      final photosController = Get.find<PhotosController>();
      final media = photosController.filteredMedia;
      final index = media.indexWhere((element) => element.id == asset.id);
      currentIndex.value = index == -1 ? 0 : index;
    } else {
      currentIndex.value = 0;
    }
    fileFuture = asset.file;
  }

  Future<void> toggleFavorite() async {
    try {
      final newValue = !isFavorite.value;

      final result = await PhotoManager.plugin.favoriteAsset(
        asset.id,
        newValue,
      );

      if (result) {
        isFavorite.value = newValue;

        final photosController = Get.find<PhotosController>();

        await photosController.toggleFavorite(asset);
      }
    } catch (e) {
      debugPrint("PhotoView Favorite Error: $e");
    }
  }

  AssetEntity get currentAsset {
    // Rename ke baad latest asset return karo
    if (_renamedAsset != null && _renamedAsset!.id == asset.id) {
      return _renamedAsset!;
    }

    if (albumMedia != null) {
      if (albumMedia!.isEmpty) {
        return asset;
      }

      final index = currentIndex.value;

      if (index < 0 || index >= albumMedia!.length) {
        return asset;
      }

      return albumMedia![index];
    }

    final photosController = Get.find<PhotosController>();
    final media = photosController.filteredMedia;

    if (media.isEmpty) {
      return asset;
    }

    final index = currentIndex.value;

    if (index < 0 || index >= media.length) {
      return asset;
    }

    return media[index];
  }

  void setMiniVideoController(VideoPlayerController controller) {
    final oldController = miniVideoController;

    if (oldController != null) {
      oldController.removeListener(_miniVideoListener);
    }

    miniVideoController = controller;

    controller.removeListener(_miniVideoListener);
    controller.addListener(_miniVideoListener);

    _syncMiniVideoState();
  }

  void _syncMiniVideoState() {
    final controller = miniVideoController;

    if (controller == null) {
      miniVideoIsPlaying.value = false;
      return;
    }

    if (!controller.value.isInitialized || controller.value.hasError) {
      miniVideoIsPlaying.value = false;
      return;
    }

    miniVideoIsPlaying.value = controller.value.isPlaying;
  }

  void _miniVideoListener() {
    final controller = miniVideoController;

    if (controller == null) {
      return;
    }

    if (!controller.value.isInitialized) {
      miniVideoIsPlaying.value = false;
      return;
    }

    if (controller.value.hasError) {
      miniVideoIsPlaying.value = false;

      debugPrint(
        "Mini Video Controller Error: "
        "${controller.value.errorDescription}",
      );

      return;
    }

    miniVideoIsPlaying.value = controller.value.isPlaying;
  }

  Future<void> closeMiniVideo() async {
    final controller = miniVideoController;

    try {
      if (controller != null &&
          controller.value.isInitialized &&
          controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (e) {
      debugPrint("Mini Video Close Error: $e");
    }

    miniVideoIsPlaying.value = false;
    showMiniVideo.value = false;
  }

  void expandMiniVideo() {
    Get.back();
  }

  Future<void> toggleMiniVideoPlayPause() {
    _miniVideoToggleQueue = _miniVideoToggleQueue.then((_) async {
      final controller = miniVideoController;

      if (controller == null) {
        debugPrint("Mini Video: controller is null");
        return;
      }

      try {
        if (!controller.value.isInitialized) {
          debugPrint("Mini Video: controller not initialized");
          return;
        }

        if (controller.value.hasError) {
          debugPrint(
            "Mini Video Error: ${controller.value.errorDescription}",
          );
          return;
        }

        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await controller.play();
        }

        miniVideoIsPlaying.value = controller.value.isPlaying;
      } catch (e, stackTrace) {
        debugPrint("Mini Video Play/Pause Error: $e");
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    return _miniVideoToggleQueue;
  }
  Future<void> sharePhoto() async {
    try {
      final file = await asset.file;

      if (file == null) {
        Get.snackbar("Share", "Unable to access this photo");
        return;
      }

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], title: "Share Photo"),
      );
    } catch (e) {
      debugPrint("Share Error: $e");
      Get.snackbar("Share", "Unable to share photo");
    }
  }

  Future<void> deletePhoto() async {
    final String? action = await Get.dialog<String>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Are you sure you want to delete the file?",
          style: TextStyle(
            fontFamily: FontFamily.robotoBold,
            fontSize: 18,
            color: const Color(0xff222222),
          ),
        ),
        content: Text(
          "Choose what you want to do with this file.",
          style: TextStyle(
            fontFamily: FontFamily.robotoRegular,
            fontSize: 14,
            color: const Color(0xff555555),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(result: "cancel");
            },
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: FontFamily.robotoMedium,
                color: const Color(0xff555555),
              ),
            ),
          ),

          TextButton(
            onPressed: () {
              Get.back(result: "recycle");
            },
            child: Text(
              "Add to Recycle Bin",
              style: TextStyle(
                fontFamily: FontFamily.robotoMedium,
                color: const Color(0xff333333),
              ),
            ),
          ),

          TextButton(
            onPressed: () {
              Get.back(result: "permanent");
            },
            child: Text(
              "Delete Permanently",
              style: TextStyle(
                fontFamily: FontFamily.robotoMedium,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (action == null || action == "cancel") {
      return;
    }
    try {
      isDeleting.value = true;
      if (action == "recycle") {
        final RecycleBinController recycleController =
            Get.isRegistered<RecycleBinController>()
            ? Get.find<RecycleBinController>()
            : Get.put(RecycleBinController());
        final bool saved = await recycleController.addToRecycleBin(asset);
        if (!saved) {
          Get.snackbar(
            "Recycle Bin",
            "Unable to save file in Recycle Bin",
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
          return;
        }
        final List<String> result = await PhotoManager.editor.deleteWithIds([
          asset.id,
        ]);
        if (Get.isRegistered<AlbumsController>()) {
          await Get.find<AlbumsController>().loadAlbums();
        }
        if (result.contains(asset.id)) {
          final photosController = Get.find<PhotosController>();
          photosController.removeAsset(asset);
          if (customAlbumName != null) {
            if (Get.isRegistered<AlbumsController>()) {
              await Get.find<AlbumsController>().removeAssetFromCustomAlbum(
                customAlbumName!,
                asset.id,
              );
            }
          }
          Get.back();
          Get.snackbar(
            "Recycle Bin",
            "File moved to Recycle Bin",
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          );
        } else {
          await recycleController.permanentlyDeleteSilentlyById(asset.id);
          Get.snackbar(
            "Delete",
            "Unable to delete original file",
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
        }

        return;
      }

      if (action == "permanent") {
        final List<String> result = await PhotoManager.editor.deleteWithIds([
          asset.id,
        ]);
        if (result.contains(asset.id)) {
          final photosController = Get.find<PhotosController>();
          photosController.removeAsset(asset);
          if (customAlbumName != null) {
            if (Get.isRegistered<AlbumsController>()) {
              await Get.find<AlbumsController>().removeAssetFromCustomAlbum(
                customAlbumName!,
                asset.id,
              );
            }
          }
          Get.back();

          Get.snackbar(
            "Delete",
            "File deleted permanently",
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          );
        } else {
          Get.snackbar(
            "Delete",
            "Unable to delete file",
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint("====================================");
      debugPrint("DELETE FILE ERROR");
      debugPrint("$e");
      debugPrintStack(stackTrace: stackTrace);
      debugPrint("====================================");

      Get.snackbar(
        "Delete",
        "Something went wrong",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> showDetails() async {
    try {
      final current = currentAsset;

      File? file;
      if (_renamedAsset?.id == current.id && _renamedFile != null) {
        file = _renamedFile;
      } else {
        file = await current.file;
      }

      if (file == null || !await file.exists()) {
        Get.snackbar(
          "Details",
          "Unable to access this file",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final fileName = file.path.split('/').last;

      String format = "Unknown";

      final dotIndex = fileName.lastIndexOf('.');

      if (dotIndex != -1 && dotIndex < fileName.length - 1) {
        format = fileName.substring(dotIndex + 1).toUpperCase();
      }

      final filePath = file.path;
      final fileSize = await file.length();

      final Uint8List imageBytes = await file.readAsBytes();

      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);

      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      final ui.Image image = frameInfo.image;

      final int actualWidth = image.width;
      final int actualHeight = image.height;

      final String resolution = "$actualWidth × $actualHeight px";

      debugPrint("================================");
      debugPrint("DETAILS");
      debugPrint("File       : $fileName");
      debugPrint("Resolution : $resolution");
      debugPrint("Size       : $fileSize bytes");
      debugPrint("================================");

      final date = formatDate(current.createDateTime);
      final time = formatTime(current.createDateTime);

      Get.dialog(
        Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Details",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),

                _detailRow("Name", fileName),

                const SizedBox(height: 13),

                _detailRow("Format", format),

                const SizedBox(height: 13),

                _detailRow("Path", filePath, maxLines: 3),

                const SizedBox(height: 13),

                _detailRow("Size", formatBytes(fileSize)),

                const SizedBox(height: 13),

                _detailRow("Resolution", resolution),

                const SizedBox(height: 13),

                _detailRow("Date", date),

                const SizedBox(height: 13),

                _detailRow("Time", time),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Get.back();
                    },
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("Details Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      Get.snackbar(
        "Details",
        "Unable to load file details",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _detailRow(String title, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        SizedBox(
          width: 90,

          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        const Text(
          ": ",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Future<void> lockPhoto() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Hide Photo?"),
        content: const Text("Are you sure you want to hide this file?"),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(result: false);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Get.back(result: true);
            },
            child: const Text("Hide", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final file = await asset.file;

      if (file == null || !await file.exists()) {
        Get.snackbar("Hide", "Unable to access this photo");
        return;
      }
      final hiddenDirectory = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/Hidden',
      );

      if (!await hiddenDirectory.exists()) {
        await hiddenDirectory.create(recursive: true);
      }

      final fileName = file.path.split('/').last;

      final hiddenFile = File('${hiddenDirectory.path}/$fileName');

      await file.copy(hiddenFile.path);
      final result = await PhotoManager.editor.deleteWithIds([asset.id]);

      if (result.contains(asset.id)) {
        Get.snackbar("Hidden", "Photo hidden successfully");

        Get.back();
      } else {
        if (await hiddenFile.exists()) {
          await hiddenFile.delete();
        }

        Get.snackbar("Hide", "Unable to hide photo");
      }
    } catch (e) {
      debugPrint("Hide Photo Error: $e");

      Get.snackbar("Hide", "Something went wrong");
    }
  }

  Future<void> editPhoto() async {
    try {
      final AssetEntity selectedAsset = currentAsset;
      final file = await selectedAsset.file;

      if (file == null || !await file.exists()) {
        Get.snackbar("Edit", "Unable to access this photo");
        return;
      }
      final PhotoEditResult? result = await Get.to<PhotoEditResult?>(
        () => PhotoEditScreen(file: file),
      );
      if (result == null) {
        return;
      }

      final Uint8List editedBytes = result.bytes;

      if (editedBytes.isEmpty) {
        return;
      }
      debugPrint("Edited image received: ${editedBytes.length} bytes");
      final AssetEntity editedAsset = await PhotoManager.editor.saveImage(
        editedBytes,
        filename: 'Edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      debugPrint("Edited asset saved: ${editedAsset.id}");
      if (result.replaceOriginal) {
        try {
          if (Platform.isAndroid) {
            final trashResult = await PhotoManager.editor.android.moveToTrash([
              selectedAsset,
            ]);

            debugPrint("Original moved to trash: $trashResult");
          } else {
            await PhotoManager.editor.deleteWithIds([selectedAsset.id]);
          }
        } catch (e) {
          debugPrint("Original trash/delete error: $e");
        }
      }

      try {
        final photosController = Get.find<PhotosController>();

        photosController.addEditedAsset(editedAsset);
      } catch (e) {
        debugPrint("PhotosController update error: $e");
      }
      Get.back();
      Get.to(() => PhotoViewScreen(asset: editedAsset));

      showToast(
        result.replaceOriginal
            ? "Photo replaced successfully"
            : "Edited copy saved successfully",
      );
    } catch (e, stackTrace) {
      debugPrint("Edit Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      Get.snackbar("Edit", "Unable to save edited photo");
    }
  }

  void showMore(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy - 220,
      overlay.size.width - buttonPosition.dx - buttonSize.width,
      overlay.size.height - buttonPosition.dy,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: Colors.black,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: "copy",
          child: Text(
            "Copy To",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: FontFamily.robotoBold,
            ),
          ),
        ),

        PopupMenuItem<String>(
          value: "move",
          child: Text(
            "Move To",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: FontFamily.robotoBold,
            ),
          ),
        ),

        if (currentAsset.type != AssetType.video) ...[
          PopupMenuItem<String>(
            value: "wallpaper",
            child: Text(
              "Set as wallpaper",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: FontFamily.robotoBold,
              ),
            ),
          ),
        ],

        PopupMenuItem<String>(
          value: "rename",
          child: Text(
            "Rename",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: FontFamily.robotoBold,
            ),
          ),
        ),

        if (currentAsset.type != AssetType.video) ...[
          PopupMenuItem<String>(
            value: "resize",
            child: Text(
              "Resize",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: FontFamily.robotoBold,
              ),
            ),
          ),
        ],
        PopupMenuItem<String>(
          value: "slideshow",
          child: Text(
            "Start Slideshow",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: FontFamily.robotoBold,
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == null) {
        return;
      }

      switch (value) {
        case "copy":
          copyPhoto();
          break;

        case "move":
          movePhoto();
          break;

        case "wallpaper":
          setAsWallpaper();
          break;

        case "rename":
          renamePhoto();
          break;

        case "resize":
          resizePhoto();
          break;

        case "slideshow":
          slideShow();
          break;
      }
    });
  }

  Future<void> copyPhoto() async {
    if (isCopyMoveLoading.value) {
      return;
    }

    try {
      final AssetEntity current = currentAsset;

      final AssetPathEntity? destinationAlbum = await Get.to<AssetPathEntity>(
        () => CopyMoveAlbumScreen(asset: current, action: CopyMoveAction.copy),
      );

      if (destinationAlbum == null) {
        return;
      }

      if (destinationAlbum.isAll) {
        Get.snackbar(
          "Copy",
          "Please select a valid album",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      isCopyMoveLoading.value = true;

      debugPrint("================================");
      debugPrint("COPY START");
      debugPrint("Original ID: ${current.id}");
      debugPrint("Destination: ${destinationAlbum.name}");
      debugPrint("Destination ID: ${destinationAlbum.id}");
      debugPrint("================================");

      final AssetEntity? copiedAsset = await PhotoManager.editor
          .copyAssetToPath(asset: current, pathEntity: destinationAlbum);

      if (copiedAsset == null) {
        Get.snackbar(
          "Copy",
          "Unable to copy photo",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      debugPrint("COPY SUCCESS");
      debugPrint("Original Asset ID: ${current.id}");
      debugPrint("Copied Asset ID: ${copiedAsset.id}");
      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }

      showToast("Copied to ${destinationAlbum.name}");
    } catch (e, stackTrace) {
      debugPrint("================================");
      debugPrint("COPY ERROR");
      debugPrint("$e");
      debugPrintStack(stackTrace: stackTrace);
      debugPrint("================================");

      Get.snackbar(
        "Copy",
        "Unable to copy photo",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      isCopyMoveLoading.value = false;
    }
  }

  Future<void> movePhoto() async {
    if (isCopyMoveLoading.value) {
      return;
    }

    try {
      final AssetEntity current = currentAsset;
      final AssetPathEntity? destinationAlbum = await Get.to<AssetPathEntity>(
        () => CopyMoveAlbumScreen(asset: current, action: CopyMoveAction.move),
      );

      if (destinationAlbum == null) {
        return;
      }

      if (destinationAlbum.isAll) {
        Get.snackbar(
          "Move",
          "Please select a valid album",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      isCopyMoveLoading.value = true;

      debugPrint("================================");
      debugPrint("MOVE START");
      debugPrint("Original ID: ${current.id}");
      debugPrint("Destination: ${destinationAlbum.name}");
      debugPrint("Destination ID: ${destinationAlbum.id}");
      debugPrint("================================");
      if (Platform.isAndroid) {
        await PhotoManager.editor.android.moveAssetToAnother(
          entity: current,
          target: destinationAlbum,
        );

        debugPrint("ANDROID MOVE SUCCESS");
      } else if (Platform.isIOS) {
        final AssetEntity? movedAsset = await PhotoManager.editor
            .copyAssetToPath(asset: current, pathEntity: destinationAlbum);

        if (movedAsset == null) {
          Get.snackbar(
            "Move",
            "Unable to add photo to destination album",
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
          return;
        }
        debugPrint("IOS DESTINATION ADD SUCCESS");
        if (albumMedia != null) {}
      } else {
        Get.snackbar(
          "Move",
          "Unsupported platform",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }
      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }
      if (Get.isRegistered<PhotosController>()) {
        final PhotosController photosController = Get.find<PhotosController>();

        photosController.allMedia.removeWhere((item) => item.id == current.id);

        photosController.filteredMedia.removeWhere(
          (item) => item.id == current.id,
        );

        photosController.allMedia.refresh();
        photosController.filteredMedia.refresh();
      }

      showToast("Moved to ${destinationAlbum.name}");
      Get.back();
    } catch (e, stackTrace) {
      debugPrint("================================");
      debugPrint("MOVE ERROR");
      debugPrint("$e");
      debugPrintStack(stackTrace: stackTrace);
      debugPrint("================================");

      Get.snackbar(
        "Move",
        "Unable to move photo",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      isCopyMoveLoading.value = false;
    }
  }

  Future<void> setAsWallpaper() async {
    try {
      final current = currentAsset;

      if (current.type == AssetType.video) {
        Get.snackbar(
          "Wallpaper",
          "Video wallpaper is not supported",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final file = await current.file;

      if (file == null || !await file.exists()) {
        Get.snackbar(
          "Wallpaper",
          "Unable to access this photo",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await Get.to(() => WallpaperScreen(imageFile: file));
    } catch (e, stackTrace) {
      debugPrint("Wallpaper Screen Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      Get.snackbar(
        "Wallpaper",
        "Unable to open wallpaper screen",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> renamePhoto() async {
    final AssetEntity current = currentAsset;

    try {
      final File? file = await current.file;

      if (file == null || !await file.exists()) {
        Get.snackbar(
          "Rename",
          "Unable to access this photo",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final String oldFileName = file.path.split('/').last;

      final int dotIndex = oldFileName.lastIndexOf('.');

      final String extension = dotIndex != -1
          ? oldFileName.substring(dotIndex)
          : '';

      final String oldName = dotIndex != -1
          ? oldFileName.substring(0, dotIndex)
          : oldFileName;

      final String? result = await Get.dialog<String>(
        _RenameDialog(initialName: oldName),
      );

      if (result == null || result.trim().isEmpty) {
        return;
      }

      String newName = result.trim();
      if (extension.isNotEmpty &&
          !newName.toLowerCase().endsWith(extension.toLowerCase())) {
        newName = '$newName$extension';
      }
      if (newName == oldFileName) {
        return;
      }

      if (newName.contains('/') ||
          newName.contains('\\') ||
          newName.contains(':') ||
          newName.contains('*') ||
          newName.contains('?') ||
          newName.contains('"') ||
          newName.contains('<') ||
          newName.contains('>') ||
          newName.contains('|')) {
        Get.snackbar(
          "Rename",
          "Invalid file name",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final String newPath = '${file.parent.path}/$newName';

      if (await File(newPath).exists()) {
        Get.snackbar(
          "Rename",
          "A file with this name already exists",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final File renamedFile = await file.rename(newPath);
      _renamedFile = renamedFile;
      _renamedAsset = current;
      debugPrint("RENAME SUCCESS");
      debugPrint("Asset ID  : ${current.id}");
      debugPrint("Old Name  : $oldFileName");
      await PhotoManager.clearFileCache();

      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }
      Get.snackbar(
        "Rename",
        "Photo renamed successfully",
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e, stackTrace) {
      debugPrint("================================");
      debugPrint("RENAME ERROR");
      debugPrint("$e");
      debugPrintStack(stackTrace: stackTrace);
      debugPrint("================================");

      Get.snackbar(
        "Rename",
        "Unable to rename photo",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> resizePhoto() async {
    try {
      final AssetEntity current = currentAsset;

      final File? file = await current.file;

      if (file == null || !await file.exists()) {
        Get.snackbar(
          "Resize",
          "Image file not found",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      // =========================================================
      // ORIGINAL IMAGE
      // =========================================================

      final Uint8List originalBytes = await file.readAsBytes();

      final ui.Codec originalCodec =
      await ui.instantiateImageCodec(originalBytes);

      final ui.FrameInfo originalFrame =
      await originalCodec.getNextFrame();

      final ui.Image originalImage = originalFrame.image;

      final int originalWidth = originalImage.width;
      final int originalHeight = originalImage.height;

      if (originalWidth <= 0 || originalHeight <= 0) {
        Get.snackbar(
          "Resize",
          "Invalid image resolution",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      // =========================================================
      // OLD FILE NAME
      // =========================================================

      final String oldFileName = file.path.split('/').last;

      final int dotIndex = oldFileName.lastIndexOf('.');

      final String oldName = dotIndex != -1
          ? oldFileName.substring(0, dotIndex)
          : oldFileName;

      // =========================================================
      // RESIZE DIALOG
      // =========================================================

      final ResizeResult? result = await Get.dialog<ResizeResult>(
        _ResizeDialog(
          width: originalWidth,
          height: originalHeight,
          initialName: oldName,
        ),
        barrierDismissible: false,
      );

      if (result == null) {
        return;
      }

      if (result.name.trim().isEmpty) {
        Get.snackbar(
          "Resize",
          "Please enter image name",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      // =========================================================
      // ACTUAL RESIZE
      // =========================================================

      final ui.Codec resizedCodec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: result.width,
        targetHeight: result.height,
      );

      final ui.FrameInfo resizedFrame =
      await resizedCodec.getNextFrame();

      final ui.Image resizedImage = resizedFrame.image;

      // =========================================================
      // LOSSLESS IMAGE OUTPUT
      // PNG = NO JPEG QUALITY COMPRESSION
      // =========================================================

      final ByteData? resizedData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (resizedData == null) {
        Get.snackbar(
          "Resize",
          "Unable to process image",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      final Uint8List resizedBytes =
      resizedData.buffer.asUint8List();

      // =========================================================
      // FILE NAME
      // =========================================================

      String fileName = result.name.trim();

      fileName = fileName.replaceAll(
        RegExp(r'[\/\\:*?"<>|]'),
        '_',
      );

      fileName = fileName.replaceFirst(
        RegExp(
          r'\.(png|jpg|jpeg|webp)$',
          caseSensitive: false,
        ),
        '',
      );

      if (fileName.isEmpty) {
        fileName =
        'Resized_${DateTime.now().millisecondsSinceEpoch}';
      }

      final AssetEntity resizedAsset =
      await PhotoManager.editor.saveImage(
        resizedBytes,
        filename: '$fileName.png',
      );

      // =========================================================
      // VERIFY WIDTH / HEIGHT
      // =========================================================

      final File? newFile = await resizedAsset.file;

      if (newFile != null && await newFile.exists()) {
        final Uint8List newBytes = await newFile.readAsBytes();

        final ui.Codec verifyCodec =
        await ui.instantiateImageCodec(newBytes);

        final ui.FrameInfo verifyFrame =
        await verifyCodec.getNextFrame();

        final ui.Image verifyImage = verifyFrame.image;

        debugPrint("================================");
        debugPrint("RESIZE VERIFIED");
        debugPrint(
          "Original : $originalWidth x $originalHeight",
        );
        debugPrint(
          "Target   : ${result.width} x ${result.height}",
        );
        debugPrint(
          "Saved    : ${verifyImage.width} x ${verifyImage.height}",
        );
        debugPrint("Quality  : LOSSLESS PNG");
        debugPrint("================================");
      }

      // =========================================================
      // REFRESH APP DATA
      // =========================================================

      if (Get.isRegistered<PhotosController>()) {
        final PhotosController photosController =
        Get.find<PhotosController>();

        photosController.addEditedAsset(resizedAsset);
      }

      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }

      // =========================================================
      // OPEN RESIZED PHOTO
      // =========================================================

      Get.off(
            () => PhotoViewScreen(
          asset: resizedAsset,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("================================");
      debugPrint("RESIZE ERROR");
      debugPrint("$e");
      debugPrintStack(stackTrace: stackTrace);
      debugPrint("================================");

      Get.snackbar(
        "Resize",
        "Unable to resize photo",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }
  Future<void> slideShow() async {
    final result = await Get.dialog<SlideShowResult>(
      const SlideShowDialog(),
      barrierDismissible: false,
    );

    if (result == null) {
      return;
    }

    slideshowDuration = result.duration;
    slideshowAnimation = result.animation;
    slideshowIncludeGifs = result.includeGifs;
    slideshowRandomOrder = result.randomOrder;
    slideshowMoveBackwards = result.moveBackwards;
    slideshowLoop = result.loop;

    startSlideshow();
  }

  void startSlideshow() {
    stopSlideshow();

    isSlideshow.value = true;

    final List<AssetEntity> media;

    if (albumMedia != null) {
      media = albumMedia!;
    } else if (Get.isRegistered<PhotosController>()) {
      media = Get.find<PhotosController>().filteredMedia;
    } else {
      return;
    }

    if (media.isEmpty) {
      stopSlideshow();
      return;
    }

    // =====================================================
    // AGAR SLIDESHOW KA FIRST/CURRENT ITEM VIDEO HAI
    // TO DIRECT VIDEO SCREEN OPEN KARO
    // =====================================================
    if (currentIndex.value >= 0 &&
        currentIndex.value < media.length &&
        media[currentIndex.value].type == AssetType.video) {
      _openSlideshowVideo(media[currentIndex.value]);
      return;
    }

    // =====================================================
    // NORMAL SLIDESHOW TIMER
    // =====================================================
    slideshowTimer = Timer.periodic(slideshowDuration, (_) async {
      if (!isSlideshow.value) {
        return;
      }

      final List<AssetEntity> media;

      if (albumMedia != null) {
        media = albumMedia!;
      } else if (Get.isRegistered<PhotosController>()) {
        media = Get.find<PhotosController>().filteredMedia;
      } else {
        return;
      }

      if (media.isEmpty) {
        stopSlideshow();
        return;
      }

      await _moveSlideshowNext();
    });
  }

  Future<void> _openSlideshowVideo(AssetEntity video) async {
    if (!isSlideshow.value) {
      return;
    }
    stopSlideshow();
    await Get.to(() => VideoViewScreen(asset: video));
  }

  Future<void> _moveSlideshowNext() async {
    final List<AssetEntity> media;

    if (albumMedia != null) {
      media = albumMedia!;
    } else if (Get.isRegistered<PhotosController>()) {
      media = Get.find<PhotosController>().filteredMedia;
    } else {
      return;
    }

    if (media.isEmpty) {
      stopSlideshow();
      return;
    }

    int nextIndex;

    // =========================================================
    // RANDOM
    // =========================================================
    if (slideshowRandomOrder) {
      final availableIndexes = List<int>.generate(
        media.length,
        (index) => index,
      );

      availableIndexes.remove(currentIndex.value);

      if (availableIndexes.isEmpty) {
        if (slideshowLoop) {
          nextIndex = 0;
        } else {
          stopSlideshow();
          return;
        }
      } else {
        availableIndexes.shuffle();
        nextIndex = availableIndexes.first;
      }
    }
    // =========================================================
    // BACKWARD
    // =========================================================
    else if (slideshowMoveBackwards) {
      nextIndex = currentIndex.value - 1;

      if (nextIndex < 0) {
        if (slideshowLoop) {
          nextIndex = media.length - 1;
        } else {
          stopSlideshow();
          return;
        }
      }
    }
    // =========================================================
    // FORWARD
    // =========================================================
    else {
      nextIndex = currentIndex.value + 1;

      if (nextIndex >= media.length) {
        if (slideshowLoop) {
          nextIndex = 0;
        } else {
          stopSlideshow();
          return;
        }
      }
    }

    // =========================================================
    // MOVE PAGE FIRST
    // =========================================================

    if (!slideshowPageController.hasClients) {
      return;
    }

    try {
      if (slideshowAnimation == "Fade") {
        slideshowPageController.jumpToPage(nextIndex);
      } else {
        await slideshowPageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }

      // PageView ka onPageChanged bhi currentIndex update karega,
      // lekin yaha bhi sync rakho.
      if (isSlideshow.value) {
        currentIndex.value = nextIndex;
      }
    } catch (e) {
      debugPrint("Slideshow Page Error: $e");
    }
  }

  void stopSlideshow() {
    slideshowTimer?.cancel();
    slideshowTimer = null;

    isSlideshow.value = false;
  }

  String formatDate(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${date.day.toString().padLeft(2, '0')} "
        "${months[date.month - 1]} "
        "${date.year}";
  }

  String formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;

    final actualHour = hour == 0 ? 12 : hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? "PM" : "AM";

    return "$actualHour:$minute $period";
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) {
      return "0 B";
    }

    const units = ["B", "KB", "MB", "GB"];

    int index = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index++;
    }

    return "${size.toStringAsFixed(2)} ${units[index]}";
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
    );
  }
}

class SlideShowResult {
  final Duration duration;
  final String animation;
  final bool includeGifs;
  final bool randomOrder;
  final bool moveBackwards;
  final bool loop;

  const SlideShowResult({
    required this.duration,
    required this.animation,
    required this.includeGifs,
    required this.randomOrder,
    required this.moveBackwards,
    required this.loop,
  });
}

class SlideShowDialog extends StatefulWidget {
  const SlideShowDialog({super.key});

  @override
  State<SlideShowDialog> createState() => _SlideShowDialogState();
}

class _SlideShowDialogState extends State<SlideShowDialog> {
  int speed = 1;

  String animation = "None";

  bool includeGifs = true;
  bool randomOrder = false;
  bool moveBackwards = false;
  bool loop = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Slideshow speed",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 10),

            // SPEED
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xffeeeeee),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (speed > 1) {
                        setState(() {
                          speed--;
                        });
                      }
                    },
                    icon: const Icon(Icons.remove, size: 18),
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        "${speed}s",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      if (speed < 10) {
                        setState(() {
                          speed++;
                        });
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ANIMATION
            _row(
              "Animation",
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: animation,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: "None", child: Text("None")),
                    DropdownMenuItem(value: "Fade", child: Text("Fade")),
                    DropdownMenuItem(value: "Slide", child: Text("Slide")),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      animation = value;
                    });
                  },
                ),
              ),
            ),

            // INCLUDE GIFS
            _row(
              "Include GIFs",
              Checkbox(
                value: includeGifs,
                onChanged: (value) {
                  setState(() {
                    includeGifs = value ?? true;
                  });
                },
              ),
            ),

            // RANDOM
            _row(
              "Random order",
              Checkbox(
                value: randomOrder,
                onChanged: (value) {
                  setState(() {
                    randomOrder = value ?? false;
                  });
                },
              ),
            ),

            // BACKWARDS
            _row(
              "Move backwards",
              Checkbox(
                value: moveBackwards,
                onChanged: (value) {
                  setState(() {
                    moveBackwards = value ?? false;
                  });
                },
              ),
            ),

            // LOOP
            _row(
              "Loop Slideshow",
              Checkbox(
                value: loop,
                onChanged: (value) {
                  setState(() {
                    loop = value ?? false;
                  });
                },
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("Cancel"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        SlideShowResult(
                          duration: Duration(seconds: speed),
                          animation: animation,
                          includeGifs: includeGifs,
                          randomOrder: randomOrder,
                          moveBackwards: moveBackwards,
                          loop: loop,
                        ),
                      );
                    },
                    child: const Text("OK"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, Widget trailing) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          trailing,
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initialName;

  const _RenameDialog({required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Rename"),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: "File name"),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            final name = controller.text.trim();

            if (name.isEmpty) {
              return;
            }

            Navigator.of(context).pop(name);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

class ResizeResult {
  final int width;
  final int height;
  final String name;

  ResizeResult({
    required this.width,
    required this.height,
    required this.name,
  });
}

class _ResizeDialog extends StatefulWidget {
  final int width;
  final int height;
  final String initialName;

  const _ResizeDialog({
    required this.width,
    required this.height,
    required this.initialName,
  });

  @override
  State<_ResizeDialog> createState() => _ResizeDialogState();
}

class _ResizeDialogState extends State<_ResizeDialog> {
  late final TextEditingController widthController;
  late final TextEditingController heightController;
  late final TextEditingController nameController;

  late final double aspectRatio;

  bool _updating = false;

  @override
  void initState() {
    super.initState();

    widthController = TextEditingController(text: widget.width.toString());

    heightController = TextEditingController(text: widget.height.toString());

    nameController = TextEditingController(text: widget.initialName);

    aspectRatio = widget.width / widget.height;

    widthController.addListener(_widthChanged);
    heightController.addListener(_heightChanged);
  }

  @override
  void dispose() {
    widthController.removeListener(_widthChanged);
    heightController.removeListener(_heightChanged);

    widthController.dispose();
    heightController.dispose();
    nameController.dispose();

    super.dispose();
  }

  // ===========================================================
  // WIDTH -> HEIGHT
  // ===========================================================

  void _widthChanged() {
    if (_updating) return;

    final int? width = int.tryParse(widthController.text.trim());

    if (width == null || width <= 0) return;

    _updating = true;

    final int height = (width / aspectRatio).round();

    heightController.text = height.toString();

    _updating = false;
  }

  // ===========================================================
  // HEIGHT -> WIDTH
  // ===========================================================

  void _heightChanged() {
    if (_updating) return;

    final int? height = int.tryParse(heightController.text.trim());

    if (height == null || height <= 0) return;

    _updating = true;

    final int width = (height * aspectRatio).round();

    widthController.text = width.toString();

    _updating = false;
  }

  // ===========================================================
  // RESIZE
  // ===========================================================

  void _resize() {
    final int? width = int.tryParse(widthController.text.trim());

    final int? height = int.tryParse(heightController.text.trim());

    final String name = nameController.text.trim();

    if (width == null || width <= 0) {
      return;
    }

    if (height == null || height <= 0) {
      return;
    }

    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      ResizeResult(width: width, height: height, name: name,),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // =================================================
            // TITLE
            // =================================================
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Resize",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // =================================================
            // WIDTH / HEIGHT
            // =================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _dimensionField(
                    label: "Width",
                    controller: widthController,
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(bottom: 10, left: 8, right: 8),
                  child: Text(
                    ":",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),

                Expanded(
                  child: _dimensionField(
                    label: "Height",
                    controller: heightController,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // =================================================
            // NAME / TITLE
            // =================================================
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xffeeeeee),
                hintText: "Title",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black54),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.black54,
                  ),
                  onPressed: () {
                    nameController.clear();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // =================================================
            // BUTTONS
            // =================================================
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xffeeeeee),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 18),

                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _resize,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff292727),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text(
                        "Resize",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DIMENSION FIELD
  // =========================================================

  Widget _dimensionField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),

        const SizedBox(height: 5),

        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffe9e9e9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }
}
