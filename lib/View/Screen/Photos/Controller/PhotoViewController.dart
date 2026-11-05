import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:gallery_photos/Common/MediaActionService.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_photos/View/Constant/App_font.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Screen/Albums/Controller/AlbumsController.dart';
import 'package:gallery_photos/View/Screen/CleanerScreen/Controller/CleanerController.dart';
import 'package:gallery_photos/View/Screen/For%20You/controller/ForYouController.dart';
import 'package:gallery_photos/View/Screen/Photos/CopyMoveAlbumScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoViewScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/VideoViewScreen.dart';
import 'package:gallery_photos/View/Screen/Photos/WallpaperScreen.dart';
import 'package:gallery_photos/View/Screen/PlaceScreen/controller/PlacesController.dart';
import 'package:gallery_photos/View/Screen/RecycleBin/Controller/RecycleBinController.dart';
import 'package:gallery_photos/View/Screen/UtilityMedia/controller/UtilityMediaController.dart';
import 'package:gallery_photos/View/Setting/Controller/SettingsController.dart';
import 'package:gallery_photos/View/Setting/FileOperationService.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Photos/Controller/PhotosController.dart';
import 'package:gallery_photos/View/Screen/Photos/PhotoEditScreen.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:gallery_photos/Common/AppToast.dart';

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
    isFavorite.value = false;
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

        if (Get.isRegistered<PhotosController>()) {
          final photosController = Get.find<PhotosController>();
          await photosController.toggleFavorite(asset);
        }

        if (Get.isRegistered<UtilityMediaController>(
          tag: UtilityMediaType.favorites.name,
        )) {
          final favoriteController = Get.find<UtilityMediaController>(
            tag: UtilityMediaType.favorites.name,
          );

          await favoriteController.refreshMedia();
        }
      }
    } catch (e) {
      debugPrint("PhotoView Favorite Error: $e");
    }
  }

  AssetEntity get currentAsset {
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
          debugPrint("Mini Video Error: ${controller.value.errorDescription}");
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
        AppToast.show("Unable to access this photo");
        return;
      }

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], title: "Share Photo"),
      );
    } catch (e) {
      debugPrint("Share Error: $e");
      AppToast.show("Unable to share photo");
    }
  }

  Future<void> deletePhoto() async {
    final String? action = await Get.dialog<String>(
      ChromeDialog(
        title: 'Delete file?',
        message: 'Are you sure you want to delete the file?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChromeButton.ok(
              label: 'Add to Recycle Bin',
              onPressed: () => Get.back(result: 'recycle'),
            ),
            const SizedBox(height: 10),
            ChromeButton.danger(
              label: 'Delete permanently',
              onPressed: () => Get.back(result: 'permanent'),
            ),
          ],
        ),
      ),
    );

    if (action == null || action == "cancel") {
      return;
    }
    if (!await MediaActionService.ensureMediaManagement()) {
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
          AppToast.show("Unable to save file in Recycle Bin");
          return;
        }
        final List<String> result = await MediaActionService.deleteIds([
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
          AppToast.show("File moved to Recycle Bin");
        } else if (!MediaActionService.waitingForPermission) {
          await recycleController.permanentlyDeleteSilentlyById(asset.id);
          AppToast.show("Unable to delete original file");
        }

        return;
      }

      if (action == "permanent") {
        final List<String> result = await MediaActionService.deleteIds([
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

          AppToast.show("File deleted permanently");
        } else if (!MediaActionService.waitingForPermission) {
          AppToast.show("Unable to delete file");
        }
      }
    } catch (e) {
      AppToast.show("Something went wrong");
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
        AppToast.show("Unable to access this file");
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
      final date = formatDate(current.createDateTime);
      final time = formatTime(current.createDateTime);

      Get.dialog(
        Dialog(
          backgroundColor: InnerChrome.dialogBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Details",
                  style: ChromeText.title,
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
                    child: Text(
                      "Close",
                      style: TextStyle(
                        color: InnerChrome.accent,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
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

      AppToast.show("Unable to load file details");
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: InnerChrome.dialogInk,
            ),
          ),
        ),

        Text(
          ": ",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: InnerChrome.dialogInk,
          ),
        ),

        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,

            style: TextStyle(fontSize: 14, color: InnerChrome.muted),
          ),
        ),
      ],
    );
  }

  Future<bool?> _askToHide(String message) {
    return Get.dialog<bool>(
      Dialog(
        backgroundColor: InnerChrome.dialogBg,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hide Photo?',
                style: TextStyle(
                  color: InnerChrome.dialogInk,
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: InnerChrome.muted,
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Get.back(result: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: InnerChrome.dialogInk,
                          side: BorderSide(color: InnerChrome.line, width: 1.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Get.back(result: true),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: InnerChrome.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Hide',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Future<bool> lockPhoto() async {
    final confirm = await _askToHide('Are you sure you want to hide this file?');

    if (confirm != true) {
      return false;
    }

    if (!await MediaActionService.ensureMediaManagement()) {
      return false;
    }

    try {
      final File? file = await currentAsset.file;

      if (file == null || !await file.exists()) {
        AppToast.show("Unable to access this photo");
        return false;
      }

      final Directory hiddenDirectory = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/Hidden',
      );

      if (!await hiddenDirectory.exists()) {
        await hiddenDirectory.create(recursive: true);
      }

      final String fileName = file.path.split(Platform.pathSeparator).last;

      final File hiddenFile = File('${hiddenDirectory.path}/$fileName');

      await file.copy(hiddenFile.path);

      final List<String> result = await MediaActionService.deleteIds([
        currentAsset.id,
      ]);

      if (!result.contains(currentAsset.id)) {
        if (MediaActionService.waitingForPermission) {
          return false;
        }
        if (await hiddenFile.exists()) {
          await hiddenFile.delete();
        }

        AppToast.show("Unable to hide photo");

        return false;
      }

      if (Get.isRegistered<PhotosController>()) {
        final PhotosController photosController = Get.find<PhotosController>();

        photosController.removeAsset(currentAsset);
      }

      albumMedia?.removeWhere((item) => item.id == currentAsset.id);

      if (customAlbumName != null && Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().removeAssetFromCustomAlbum(
          customAlbumName!,
          currentAsset.id,
        );
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint("Hide Photo Error: $e");

      debugPrintStack(stackTrace: stackTrace);

      AppToast.show("Something went wrong");

      return false;
    }
  }

  Future<void> editPhoto() async {
    try {
      final AssetEntity selectedAsset = currentAsset;

      final File? file = await selectedAsset.file;

      if (file == null || !await file.exists()) {
        AppToast.show("Unable to access this photo");
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

      final SettingsController settingsController =
          Get.isRegistered<SettingsController>()
          ? Get.find<SettingsController>()
          : Get.put(SettingsController());

      String behavior = settingsController.editedFileSavingBehaviorValue.value;

      debugPrint("Edited File Saving Behavior: $behavior");

      if (behavior == SettingsController.alwaysAsk) {
        final String? selectedBehavior = await _showEditedFileSavingDialog();

        if (selectedBehavior == null) {
          return;
        }

        behavior = selectedBehavior;
      }

      final AssetEntity editedAsset = await PhotoManager.editor.saveImage(
        editedBytes,
        filename: 'Edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      debugPrint("Edited asset saved: ${editedAsset.id}");

      if (behavior == SettingsController.replaceFile) {
        try {
          if (Platform.isAndroid) {
            final trashResult = await PhotoManager.editor.android.moveToTrash([
              selectedAsset,
            ]);

            debugPrint("Original moved to trash: $trashResult");
          } else {
            await MediaActionService.deleteIds([selectedAsset.id]);
          }
        } catch (e) {
          debugPrint("Original trash/delete error: $e");
        }
      }

      try {
        final PhotosController photosController = Get.find<PhotosController>();

        photosController.addEditedAsset(editedAsset);
      } catch (e) {
        debugPrint("PhotosController update error: $e");
      }

      Get.back();

      Get.to(() => PhotoViewScreen(asset: editedAsset));

      if (behavior == SettingsController.replaceFile) {
        showToast("Photo replaced successfully");
      } else {
        showToast("Edited copy saved successfully");
      }
    } catch (e, stackTrace) {
      debugPrint("Edit Error: $e");

      debugPrintStack(stackTrace: stackTrace);

      AppToast.show("Unable to save edited photo");
    }
  }

  Future<String?> _showEditedFileSavingDialog() async {
    return await Get.dialog<String>(
      ChromeDialog(
        title: 'Save edited photo',
        message: 'How do you want to save this edited photo?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChromeButton.ok(
              label: 'Save copy',
              onPressed: () => Get.back(result: SettingsController.saveCopy),
            ),
            const SizedBox(height: 10),
            ChromeButton.danger(
              label: 'Replace file',
              onPressed: () =>
                  Get.back(result: SettingsController.replaceFile),
            ),
          ],
        ),
      ),
    );
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

  Future<int> _getAndroidApiLevel() async {
    try {
      final String version = await PhotoManager.systemVersion();

      debugPrint("PHOTO MANAGER SYSTEM VERSION: $version");

      final RegExp apiRegex = RegExp(r'API[\s:]*(\d+)');
      final Match? apiMatch = apiRegex.firstMatch(version);

      if (apiMatch != null) {
        return int.tryParse(apiMatch.group(1) ?? '') ?? 0;
      }

      final RegExp numberRegex = RegExp(r'^\d+$');
      if (numberRegex.hasMatch(version.trim())) {
        return int.tryParse(version.trim()) ?? 0;
      }

      final RegExp androidRegex = RegExp(
        r'Android[\s]+(\d+)',
        caseSensitive: false,
      );

      final Match? androidMatch = androidRegex.firstMatch(version);

      if (androidMatch != null) {
        final int androidVersion =
            int.tryParse(androidMatch.group(1) ?? '') ?? 0;

        switch (androidVersion) {
          case 11:
            return 30;
          case 12:
            return 31;
          case 13:
            return 33;
          case 14:
            return 34;
          case 15:
            return 35;
          case 16:
            return 36;
        }
      }
    } catch (e) {
      debugPrint("API LEVEL ERROR: $e");
    }

    return 0;
  }

  Future<String?> _copyToAndroidDownloads({
    required File sourceFile,
    required String fileName,
    required AssetType sourceType,
  }) async {
    try {
      const MethodChannel channel = MethodChannel('native_camera');

      final String mimeType = _getMimeType(fileName, sourceType);
      final dynamic response = await channel
          .invokeMethod('copyMediaToAlbum', <String, dynamic>{
            'sourcePath': sourceFile.path,
            'relativePath': 'Download/',
            'fileName': fileName,
            'mimeType': mimeType,
          });

      if (response == null) {
        debugPrint("DOWNLOAD COPY => Native response NULL");

        return null;
      }

      final String mediaId = response.toString();

      if (mediaId.trim().isEmpty) {
        debugPrint("DOWNLOAD COPY => Media ID empty");

        return null;
      }

      debugPrint("DOWNLOAD COPY => New MediaStore ID: $mediaId");

      return mediaId;
    } on PlatformException catch (e, stackTrace) {
      return null;
    } catch (e, stackTrace) {
      debugPrint("DOWNLOAD COPY ERROR => $e");

      debugPrintStack(stackTrace: stackTrace);

      return null;
    }
  }

  String _getMimeType(String fileName, AssetType type) {
    final String name = fileName.toLowerCase();

    if (type == AssetType.video) {
      if (name.endsWith('.mp4')) {
        return 'video/mp4';
      }

      if (name.endsWith('.mov')) {
        return 'video/quicktime';
      }

      if (name.endsWith('.mkv')) {
        return 'video/x-matroska';
      }

      if (name.endsWith('.avi')) {
        return 'video/x-msvideo';
      }

      if (name.endsWith('.webm')) {
        return 'video/webm';
      }

      return 'video/*';
    }

    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    if (name.endsWith('.gif')) {
      return 'image/gif';
    }

    if (name.endsWith('.heic')) {
      return 'image/heic';
    }

    if (name.endsWith('.heif')) {
      return 'image/heif';
    }

    return 'image/*';
  }

  Future<AssetEntity?> _copyAssetCrossPlatform({
    required AssetEntity source,
    required AssetPathEntity destinationAlbum,
  }) async {
    try {
      debugPrint("========================================");
      debugPrint("COPY START");
      debugPrint("Original ID: ${source.id}");
      debugPrint("Original Type: ${source.type}");
      debugPrint("Destination: ${destinationAlbum.name}");
      debugPrint("Destination ID: ${destinationAlbum.id}");

      final File? sourceFile = await source.file;

      if (sourceFile == null || !await sourceFile.exists()) {
        debugPrint("COPY => Source file not found");
        return null;
      }

      final String? sourceTitle = await source.titleAsync;

      final String fileName =
          (sourceTitle != null && sourceTitle.trim().isNotEmpty)
          ? sourceTitle
          : sourceFile.path.split(Platform.pathSeparator).last;

      debugPrint("COPY SOURCE FILE => ${sourceFile.path}");
      debugPrint("COPY FILE NAME => $fileName");

      if (Platform.isIOS) {
        debugPrint("COPY PLATFORM => iOS");

        try {
          final AssetEntity? result = await PhotoManager.editor.copyAssetToPath(
            asset: source,
            pathEntity: destinationAlbum,
          );

          debugPrint(
            "COPY iOS RESULT => "
            "${result != null ? result.id : 'NULL'}",
          );

          return result;
        } catch (e, stackTrace) {
          debugPrint("COPY iOS FAILED => $e");

          debugPrintStack(stackTrace: stackTrace);

          return null;
        }
      }

      if (Platform.isAndroid) {
        final int api = await _getAndroidApiLevel();

        debugPrint("COPY ANDROID API => $api");

        if (api > 0 && api <= 29) {
          debugPrint("COPY METHOD => PhotoManager copyAssetToPath");

          try {
            final AssetEntity? result = await PhotoManager.editor
                .copyAssetToPath(asset: source, pathEntity: destinationAlbum);

            debugPrint(
              "COPY LEGACY RESULT => "
              "${result != null ? result.id : 'NULL'}",
            );

            return result;
          } catch (e, stackTrace) {
            debugPrint("COPY LEGACY FAILED => $e");

            debugPrintStack(stackTrace: stackTrace);

            return null;
          }
        }

        if (api >= 30) {
          final String? relativePath = await destinationAlbum.relativePathAsync;

          debugPrint("COPY DESTINATION RELATIVE PATH => $relativePath");

          if (relativePath == null || relativePath.trim().isEmpty) {
            debugPrint("COPY => Destination relativePath is empty");

            return null;
          }

          final String cleanRelativePath = relativePath.trim().replaceAll(
            '\\',
            '/',
          );

          debugPrint("COPY CLEAN RELATIVE PATH => $cleanRelativePath");

          if (_isDownloadRelativePath(cleanRelativePath)) {
            debugPrint("COPY METHOD => Native MediaStore Downloads");

            try {
              final String? newAssetId = await _copyToAndroidDownloads(
                sourceFile: sourceFile,
                fileName: fileName,
                sourceType: source.type,
              );

              if (newAssetId == null || newAssetId.trim().isEmpty) {
                debugPrint("COPY DOWNLOAD => Native copy returned NULL");

                return null;
              }

              debugPrint(
                "COPY DOWNLOAD => New MediaStore ID => "
                "$newAssetId",
              );

              for (int attempt = 0; attempt < 5; attempt++) {
                debugPrint(
                  "COPY DOWNLOAD => AssetEntity.fromId attempt "
                  "${attempt + 1}/5",
                );

                try {
                  final AssetEntity? copiedAsset = await AssetEntity.fromId(
                    newAssetId,
                  );

                  if (copiedAsset != null) {
                    debugPrint("COPY DOWNLOAD => Asset FOUND by ID");

                    debugPrint(
                      "COPY DOWNLOAD => Asset ID => "
                      "${copiedAsset.id}",
                    );

                    debugPrint(
                      "COPY DOWNLOAD => Asset title => "
                      "${await copiedAsset.titleAsync}",
                    );

                    debugPrint(
                      "COPY DOWNLOAD => Asset relative path => "
                      "${copiedAsset.relativePath}",
                    );

                    return copiedAsset;
                  }

                  debugPrint(
                    "COPY DOWNLOAD => AssetEntity.fromId "
                    "returned NULL",
                  );
                } catch (e, stackTrace) {
                  debugPrint("COPY DOWNLOAD => fromId error => $e");

                  debugPrintStack(stackTrace: stackTrace);
                }

                if (attempt < 4) {
                  await Future.delayed(const Duration(milliseconds: 700));
                }
              }

              debugPrint(
                "COPY DOWNLOAD => fromId failed."
                " Trying album filename search...",
              );

              for (int attempt = 0; attempt < 3; attempt++) {
                debugPrint(
                  "COPY DOWNLOAD => Filename search "
                  "attempt ${attempt + 1}/3",
                );

                try {
                  final List<AssetEntity> assets = await destinationAlbum
                      .getAssetListRange(start: 0, end: 200);

                  debugPrint(
                    "COPY DOWNLOAD => Destination assets => "
                    "${assets.length}",
                  );

                  for (final AssetEntity asset in assets) {
                    final String? title = await asset.titleAsync;

                    if (title == fileName) {
                      debugPrint(
                        "COPY DOWNLOAD => "
                        "Found by filename => $title",
                      );

                      return asset;
                    }
                  }

                  final String lowerFileName = fileName.toLowerCase();

                  for (final AssetEntity asset in assets) {
                    final String? title = await asset.titleAsync;

                    if (title != null && title.toLowerCase() == lowerFileName) {
                      debugPrint(
                        "COPY DOWNLOAD => "
                        "Found by case-insensitive filename",
                      );

                      return asset;
                    }
                  }
                } catch (e, stackTrace) {
                  debugPrint(
                    "COPY DOWNLOAD => "
                    "Filename search error => $e",
                  );

                  debugPrintStack(stackTrace: stackTrace);
                }

                if (attempt < 2) {
                  await Future.delayed(const Duration(milliseconds: 700));
                }
              }

              debugPrint(
                "COPY DOWNLOAD => MediaStore copy completed "
                "but AssetEntity could not be resolved",
              );

              return null;
            } catch (e, stackTrace) {
              debugPrint("COPY DOWNLOAD FAILED => $e");
              debugPrintStack(stackTrace: stackTrace);
              return null;
            }
          }

          if (_isSupportedMediaStoreRelativePath(cleanRelativePath)) {
            debugPrint("COPY METHOD => MediaStore relativePath");

            try {
              if (source.type == AssetType.video) {
                debugPrint("COPY => Saving video to destination");

                final AssetEntity result = await PhotoManager.editor.saveVideo(
                  sourceFile,
                  title: fileName,
                  relativePath: cleanRelativePath,
                );
                debugPrint("COPY VIDEO RESULT => ${result.id}");
                return result;
              }

              debugPrint("COPY => Saving image to destination");

              final AssetEntity result = await PhotoManager.editor
                  .saveImageWithPath(
                    sourceFile.path,
                    title: fileName,
                    relativePath: cleanRelativePath,
                  );
              debugPrint("COPY IMAGE RESULT => ${result.id}");
              return result;
            } catch (e, stackTrace) {
              debugPrint("COPY MEDIASTORE FAILED => $e");
              debugPrintStack(stackTrace: stackTrace);
              return null;
            }
          }

          debugPrint(
            "COPY => Unsupported Android relative path: "
            "$cleanRelativePath",
          );

          return null;
        }

        debugPrint("COPY => Unknown Android API level: $api");

        return null;
      }

      debugPrint("COPY => Unsupported platform");

      return null;
    } catch (e, stackTrace) {
      debugPrint("COPY FINAL FAILED => $e");

      debugPrintStack(stackTrace: stackTrace);

      return null;
    }
  }

  bool _isDownloadRelativePath(String path) {
    final String normalized = path.trim().replaceAll('\\', '/').toLowerCase();

    return normalized == 'download' ||
        normalized == 'download/' ||
        normalized.startsWith('download/');
  }

  bool _isSupportedMediaStoreRelativePath(String path) {
    final String normalized = path.trim().replaceAll('\\', '/').toLowerCase();

    return normalized.startsWith('pictures/') ||
        normalized == 'pictures' ||
        normalized.startsWith('dcim/') ||
        normalized == 'dcim';
  }

  Future<void> copyPhoto() async {
    if (isCopyMoveLoading.value) {
      return;
    }
    try {
      final AssetEntity current = currentAsset;
      final File? originalFile = await current.file;

      if (originalFile == null || !await originalFile.exists()) {
        AppToast.show("Unable to access original file");

        return;
      }

      final DateTime oldLastModified = await originalFile.lastModified();

      final AssetPathEntity? destinationAlbum = await Get.to<AssetPathEntity>(
        () => CopyMoveAlbumScreen(asset: current, action: CopyMoveAction.copy),
      );

      if (destinationAlbum == null) {
        return;
      }

      if (destinationAlbum.isAll) {
        AppToast.show("Please select a valid album");

        return;
      }

      isCopyMoveLoading.value = true;

      debugPrint("================================");
      debugPrint("COPY START");
      debugPrint("Original ID: ${current.id}");
      debugPrint("Original File: ${originalFile.path}");
      debugPrint("Original Type: ${current.type}");
      debugPrint("Destination: ${destinationAlbum.name}");
      debugPrint("Destination ID: ${destinationAlbum.id}");
      debugPrint("================================");

      final AssetEntity? copiedAsset = await _copyAssetCrossPlatform(
        source: current,
        destinationAlbum: destinationAlbum,
      );

      if (copiedAsset == null) {
        debugPrint("COPY => FINAL RESULT: FAILED");

        AppToast.show(
          "Unable to copy photo to ${destinationAlbum.name}",
          long: true,
        );

        return;
      }

      if (FileOperationService.keepLastModified) {
        try {
          final File? copiedFile = await copiedAsset.file;

          if (copiedFile != null && await copiedFile.exists()) {
            await copiedFile.setLastModified(oldLastModified);

            debugPrint("COPY => Old last modified restored");
          }
        } catch (e) {
          debugPrint("COPY => Failed to restore last modified: $e");
        }
      }

      try {
        await PhotoManager.clearFileCache();
      } catch (e) {
        debugPrint("COPY => Cache clear error: $e");
      }

      debugPrint("================================");
      debugPrint("COPY SUCCESS");
      debugPrint("Original Asset ID: ${current.id}");
      debugPrint("Copied Asset ID: ${copiedAsset.id}");
      debugPrint("Destination: ${destinationAlbum.name}");
      debugPrint("================================");

      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }

      if (Get.isRegistered<CleanerController>()) {
        await Get.find<CleanerController>().rememberCopiedPhoto(
          current,
          copiedAsset,
        );
      }

      showToast("Copied to ${destinationAlbum.name}");
    } catch (e, stackTrace) {
      debugPrint("================================");
      debugPrint("COPY ERROR");
      debugPrint("$e");
      debugPrintStack(stackTrace: stackTrace);
      debugPrint("================================");

      AppToast.show("Unable to copy photo");
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

      final File? originalFile = await current.file;

      if (originalFile == null || !await originalFile.exists()) {
        AppToast.show("Unable to access original file");
        return;
      }

      final DateTime oldLastModified = await originalFile.lastModified();

      final AssetPathEntity? destinationAlbum = await Get.to<AssetPathEntity>(
        () => CopyMoveAlbumScreen(asset: current, action: CopyMoveAction.move),
      );

      if (destinationAlbum == null) {
        return;
      }

      if (destinationAlbum.isAll) {
        AppToast.show("Please select a valid album");
        return;
      }

      isCopyMoveLoading.value = true;

      debugPrint("================================");
      debugPrint("MOVE START");
      debugPrint("Original ID: ${current.id}");
      debugPrint("Original Type: ${current.type}");
      debugPrint("Destination: ${destinationAlbum.name}");
      debugPrint("Destination ID: ${destinationAlbum.id}");
      debugPrint("================================");

      if (Platform.isAndroid) {
        final int api = await _getAndroidApiLevel();

        if (api >= 30) {
          final String? relativePath = await destinationAlbum.relativePathAsync;

          debugPrint("MOVE DESTINATION RELATIVE PATH => $relativePath");

          if (relativePath == null || relativePath.trim().isEmpty) {
            AppToast.show("Unable to determine destination folder");

            return;
          }

          final String cleanRelativePath = relativePath.trim().replaceAll(
            '\\',
            '/',
          );

          debugPrint(
            "MOVE CLEAN RELATIVE PATH => "
            "$cleanRelativePath",
          );

          try {
            const MethodChannel channel = MethodChannel('native_camera');
            final dynamic response = await channel
                .invokeMethod('moveMediaToAlbum', <String, dynamic>{
                  'assetId': current.id,
                  'relativePath': cleanRelativePath,
                  'isVideo': current.type == AssetType.video,
                });

            if (response == null) {
              debugPrint("MOVE => Native MediaStore returned NULL");

              AppToast.show("Unable to move file");

              return;
            }

            debugPrint("MOVE => MediaStore move SUCCESS => $response");

            if (FileOperationService.keepLastModified) {
              try {
                final File? movedFile = await current.file;

                if (movedFile != null && await movedFile.exists()) {
                  await movedFile.setLastModified(oldLastModified);

                  debugPrint("MOVE => Old last modified restored");
                }
              } catch (e) {
                debugPrint("MOVE => Last modified error: $e");
              }
            }

            try {
              await PhotoManager.clearFileCache();
            } catch (e) {
              debugPrint("MOVE => Cache clear error: $e");
            }

            if (Get.isRegistered<AlbumsController>()) {
              await Get.find<AlbumsController>().loadAlbums();
            }

            if (Get.isRegistered<PhotosController>()) {
              final PhotosController photosController =
                  Get.find<PhotosController>();

              photosController.allMedia.refresh();
              photosController.filteredMedia.refresh();
            }

            if (Get.isRegistered<PlacesController>()) {
              final PlacesController placesController =
                  Get.find<PlacesController>();

              placesController.places.refresh();
            }

            debugPrint("================================");
            debugPrint("MOVE SUCCESS");
            debugPrint("Asset ID: ${current.id}");
            debugPrint("Destination: ${destinationAlbum.name}");
            debugPrint("================================");

            showToast("Moved to ${destinationAlbum.name}");

            Get.back();

            return;
          } on PlatformException catch (e) {
            debugPrint("MOVE PLATFORM ERROR => ${e.code}");
            debugPrint("MOVE MESSAGE => ${e.message}");

            if (e.code == "MEDIA_MANAGEMENT_DENIED") {
              AppToast.show("Media management permission was not granted.");
            } else {
              AppToast.show(e.message ?? "Unable to move media.");
            }

            return;
          }
        }
      }

      final AssetEntity? copiedAsset = await _copyAssetCrossPlatform(
        source: current,
        destinationAlbum: destinationAlbum,
      );

      if (copiedAsset == null) {
        AppToast.show("Unable to copy photo to ${destinationAlbum.name}");

        return;
      }

      if (FileOperationService.keepLastModified) {
        try {
          final File? copiedFile = await copiedAsset.file;

          if (copiedFile != null && await copiedFile.exists()) {
            await copiedFile.setLastModified(oldLastModified);
          }
        } catch (e) {
          debugPrint("MOVE => Last modified error: $e");
        }
      }

      final List<String> deletedIds = await MediaActionService.deleteIds(
        <String>[current.id],
      );

      if (!deletedIds.contains(current.id)) {
        AppToast.show("Photo copied, but original could not be removed");

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

      if (Get.isRegistered<PlacesController>()) {
        final PlacesController placesController = Get.find<PlacesController>();

        for (final PlaceGroup place in placesController.places) {
          place.assets.removeWhere((asset) => asset.id == current.id);
        }

        placesController.places.refresh();
      }

      showToast("Moved to ${destinationAlbum.name}");

      Get.back();
    } catch (e, stackTrace) {
      debugPrint("================================");
      debugPrint("MOVE ERROR");
      debugPrint("$e");

      debugPrintStack(stackTrace: stackTrace);

      debugPrint("================================");

      AppToast.show("Unable to move photo");
    } finally {
      isCopyMoveLoading.value = false;
    }
  }

  Future<void> shareAssets(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return;
    }

    try {
      final List<XFile> files = [];

      for (final AssetEntity asset in assets) {
        final File? file = await asset.file;

        if (file != null && await file.exists()) {
          files.add(XFile(file.path));
        }
      }

      if (files.isEmpty) {
        AppToast.show("Unable to access selected photos");
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: files,
          title: files.length > 1 ? "Share Photos" : "Share Photo",
        ),
      );
    } catch (e) {
      debugPrint("Batch Share Error: $e");
      AppToast.show("Unable to share selected photos");
    }
  }

  Future<List<String>> hideAssets(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return <String>[];
    }

    final confirm = await _askToHide(
      assets.length > 1
          ? 'Are you sure you want to hide ${assets.length} selected items?'
          : 'Are you sure you want to hide this file?',
    );

    if (confirm != true) {
      return <String>[];
    }

    if (!await MediaActionService.ensureMediaManagement()) {
      return <String>[];
    }

    final List<String> hiddenIds = [];

    for (final AssetEntity asset in assets) {
      try {
        final File? file = await asset.file;

        if (file == null || !await file.exists()) {
          continue;
        }

        final Directory hiddenDirectory = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/Hidden',
        );

        if (!await hiddenDirectory.exists()) {
          await hiddenDirectory.create(recursive: true);
        }

        final String fileName = file.path.split(Platform.pathSeparator).last;

        final File hiddenFile = File('${hiddenDirectory.path}/$fileName');

        await file.copy(hiddenFile.path);

        final List<String> result = await MediaActionService.deleteIds([
          asset.id,
        ]);

        if (!result.contains(asset.id)) {
          if (await hiddenFile.exists()) {
            await hiddenFile.delete();
          }
          continue;
        }

        hiddenIds.add(asset.id);

        if (Get.isRegistered<PhotosController>()) {
          Get.find<PhotosController>().removeAsset(asset);
        }

        albumMedia?.removeWhere((item) => item.id == asset.id);

        if (customAlbumName != null && Get.isRegistered<AlbumsController>()) {
          await Get.find<AlbumsController>().removeAssetFromCustomAlbum(
            customAlbumName!,
            asset.id,
          );
        }
      } catch (e, stackTrace) {
        debugPrint("Batch Hide Photo Error: $e");
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (hiddenIds.isEmpty) {
      AppToast.show("Unable to hide selected photos");
    } else {
      showToast(
        hiddenIds.length == 1
            ? "Photo hidden"
            : "${hiddenIds.length} photos hidden",
      );
    }

    return hiddenIds;
  }

  Future<void> copyAssets(List<AssetEntity> assets) async {
    if (assets.isEmpty || isCopyMoveLoading.value) {
      return;
    }

    try {
      final AssetPathEntity? destinationAlbum = await Get.to<AssetPathEntity>(
        () => CopyMoveAlbumScreen(
          asset: assets.first,
          action: CopyMoveAction.copy,
        ),
      );

      if (destinationAlbum == null) {
        return;
      }

      if (destinationAlbum.isAll) {
        AppToast.show("Please select a valid album");
        return;
      }

      isCopyMoveLoading.value = true;

      int successCount = 0;

      for (final AssetEntity asset in assets) {
        try {
          final File? originalFile = await asset.file;

          if (originalFile == null || !await originalFile.exists()) {
            continue;
          }

          final DateTime oldLastModified = await originalFile.lastModified();

          final AssetEntity? copiedAsset = await _copyAssetCrossPlatform(
            source: asset,
            destinationAlbum: destinationAlbum,
          );

          if (copiedAsset == null) {
            continue;
          }

          if (FileOperationService.keepLastModified) {
            try {
              final File? copiedFile = await copiedAsset.file;

              if (copiedFile != null && await copiedFile.exists()) {
                await copiedFile.setLastModified(oldLastModified);
              }
            } catch (e) {
              debugPrint("Batch Copy => Failed to restore last modified: $e");
            }
          }

          successCount++;
          if (Get.isRegistered<CleanerController>()) {
            await Get.find<CleanerController>().rememberCopiedPhoto(
              asset,
              copiedAsset,
            );
          }
        } catch (e) {
          debugPrint("Batch Copy Error for ${asset.id}: $e");
        }
      }

      try {
        await PhotoManager.clearFileCache();
      } catch (e) {
        debugPrint("Batch Copy => Cache clear error: $e");
      }

      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }

      if (successCount > 0) {
        showToast(
          successCount == 1
              ? "Copied to ${destinationAlbum.name}"
              : "$successCount items copied to ${destinationAlbum.name}",
        );
      } else {
        AppToast.show(
          "Unable to copy selected photos to ${destinationAlbum.name}",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("Batch Copy Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      AppToast.show("Unable to copy selected photos");
    } finally {
      isCopyMoveLoading.value = false;
    }
  }

  Future<List<String>> moveAssets(List<AssetEntity> assets) async {
    if (assets.isEmpty || isCopyMoveLoading.value) {
      return <String>[];
    }

    final List<String> movedSourceIds = [];

    try {
      final AssetPathEntity? destinationAlbum = await Get.to<AssetPathEntity>(
        () => CopyMoveAlbumScreen(
          asset: assets.first,
          action: CopyMoveAction.move,
        ),
      );

      if (destinationAlbum == null) {
        return <String>[];
      }

      if (destinationAlbum.isAll) {
        AppToast.show("Please select a valid album");
        return <String>[];
      }

      isCopyMoveLoading.value = true;

      String? relativePath;
      int androidApi = 0;

      if (Platform.isAndroid) {
        androidApi = await _getAndroidApiLevel();

        if (androidApi >= 30) {
          final String? rawRelativePath =
              await destinationAlbum.relativePathAsync;

          relativePath = rawRelativePath?.trim().replaceAll('\\', '/');
        }
      }

      for (final AssetEntity asset in assets) {
        try {
          final File? originalFile = await asset.file;

          if (originalFile == null || !await originalFile.exists()) {
            continue;
          }

          final DateTime oldLastModified = await originalFile.lastModified();

          bool movedThisAsset = false;

          if (Platform.isAndroid &&
              androidApi >= 30 &&
              relativePath != null &&
              relativePath.isNotEmpty) {
            try {
              const MethodChannel channel = MethodChannel('native_camera');

              final dynamic response = await channel
                  .invokeMethod('moveMediaToAlbum', <String, dynamic>{
                    'assetId': asset.id,
                    'relativePath': relativePath,
                    'isVideo': asset.type == AssetType.video,
                  });

              if (response != null) {
                if (FileOperationService.keepLastModified) {
                  try {
                    final File? movedFile = await asset.file;

                    if (movedFile != null && await movedFile.exists()) {
                      await movedFile.setLastModified(oldLastModified);
                    }
                  } catch (e) {
                    debugPrint("Batch Move => Last modified error: $e");
                  }
                }

                movedThisAsset = true;
              }
            } on PlatformException catch (e) {
              debugPrint(
                "Batch Move Platform Error for ${asset.id}: ${e.code}",
              );
            }
          }

          if (!movedThisAsset) {
            final AssetEntity? copiedAsset = await _copyAssetCrossPlatform(
              source: asset,
              destinationAlbum: destinationAlbum,
            );

            if (copiedAsset == null) {
              continue;
            }

            if (FileOperationService.keepLastModified) {
              try {
                final File? copiedFile = await copiedAsset.file;

                if (copiedFile != null && await copiedFile.exists()) {
                  await copiedFile.setLastModified(oldLastModified);
                }
              } catch (e) {
                debugPrint("Batch Move => Last modified error: $e");
              }
            }

            final List<String> deletedIds = await PhotoManager.editor
                .deleteWithIds(<String>[asset.id]);

            if (!deletedIds.contains(asset.id)) {
              continue;
            }

            movedThisAsset = true;
          }

          if (movedThisAsset) {
            movedSourceIds.add(asset.id);
          }
        } catch (e) {
          debugPrint("Batch Move Error for ${asset.id}: $e");
        }
      }

      try {
        await PhotoManager.clearFileCache();
      } catch (e) {
        debugPrint("Batch Move => Cache clear error: $e");
      }

      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }

      if (Get.isRegistered<PhotosController>()) {
        final PhotosController photosController = Get.find<PhotosController>();

        photosController.allMedia.removeWhere(
          (item) => movedSourceIds.contains(item.id),
        );
        photosController.filteredMedia.removeWhere(
          (item) => movedSourceIds.contains(item.id),
        );

        photosController.allMedia.refresh();
        photosController.filteredMedia.refresh();
      }

      if (Get.isRegistered<PlacesController>()) {
        final PlacesController placesController = Get.find<PlacesController>();

        for (final PlaceGroup place in placesController.places) {
          place.assets.removeWhere((a) => movedSourceIds.contains(a.id));
        }

        placesController.places.refresh();
      }

      if (movedSourceIds.isNotEmpty) {
        showToast(
          movedSourceIds.length == 1
              ? "Moved to ${destinationAlbum.name}"
              : "${movedSourceIds.length} items moved to ${destinationAlbum.name}",
        );
      } else {
        AppToast.show(
          "Unable to move selected photos to ${destinationAlbum.name}",
        );
      }
    } catch (e, stackTrace) {
      debugPrint("Batch Move Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      AppToast.show("Unable to move selected photos");
    } finally {
      isCopyMoveLoading.value = false;
    }

    return movedSourceIds;
  }

  Future<void> setAsWallpaper() async {
    try {
      final current = currentAsset;

      if (current.type == AssetType.video) {
        AppToast.show("Video wallpaper is not supported");
        return;
      }

      final file = await current.file;

      if (file == null || !await file.exists()) {
        AppToast.show("Unable to access this photo");
        return;
      }

      await Get.to(() => WallpaperScreen(imageFile: file));
    } catch (e, stackTrace) {
      debugPrint("Wallpaper Screen Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      AppToast.show("Unable to open wallpaper screen");
    }
  }

  Future<void> renamePhoto() async {
    final AssetEntity current = currentAsset;

    try {
      final File? file = await current.file;

      if (file == null || !await file.exists()) {
        AppToast.show("Unable to access this photo");
        return;
      }

      final DateTime oldLastModified = await file.lastModified();

      final String oldFileName = file.path.split('/').last;

      final int dotIndex = oldFileName.lastIndexOf('.');

      final String extension = dotIndex != -1
          ? oldFileName.substring(dotIndex)
          : '.jpg';

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

      final int newDotIndex = newName.lastIndexOf('.');

      if (newDotIndex != -1) {
        newName = newName.substring(0, newDotIndex);
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
        AppToast.show("Invalid file name");
        return;
      }

      if (newName.isEmpty) {
        AppToast.show("Please enter a valid file name");
        return;
      }

      final String finalFileName = '$newName$extension';

      if (finalFileName == oldFileName) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        AppToast.show("Unable to read photo");
        return;
      }

      debugPrint("================================");
      debugPrint("RENAME START");
      debugPrint("Old Name : $oldFileName");
      debugPrint("New Name : $finalFileName");
      debugPrint("Old Asset ID : ${current.id}");
      debugPrint("Old Last Modified : $oldLastModified");
      debugPrint("================================");

      final AssetEntity newAsset = await PhotoManager.editor.saveImage(
        bytes,
        filename: finalFileName,
      );

      debugPrint("NEW ASSET CREATED");
      debugPrint("New Asset ID : ${newAsset.id}");

      final List<String> deletedIds = await MediaActionService.deleteIds(
        <String>[current.id],
      );

      if (!deletedIds.contains(current.id)) {
        debugPrint("RENAME => OLD FILE DELETE FAILED");

        AppToast.show(
          "New file created, but old file could not be removed",
          long: true,
        );

        return;
      }

      _renamedAsset = newAsset;

      final File? renamedFile = await newAsset.file;

      if (renamedFile != null && await renamedFile.exists()) {
        _renamedFile = renamedFile;

        if (FileOperationService.keepLastModified) {
          try {
            await renamedFile.setLastModified(oldLastModified);

            debugPrint("RENAME => Old last modified restored");

            debugPrint("Last Modified : $oldLastModified");
          } catch (e) {
            debugPrint("RENAME => Failed to restore last modified: $e");
          }
        }
      }

      await PhotoManager.clearFileCache();

      if (Get.isRegistered<PhotosController>()) {
        final PhotosController photosController = Get.find<PhotosController>();

        try {
          photosController.allMedia.removeWhere(
            (item) => item.id == current.id,
          );

          photosController.filteredMedia.removeWhere(
            (item) => item.id == current.id,
          );

          photosController.allMedia.add(newAsset);

          photosController.filteredMedia.add(newAsset);

          photosController.allMedia.refresh();
          photosController.filteredMedia.refresh();
        } catch (e) {
          debugPrint("PhotosController Rename Update Error => $e");
        }
      }

      if (Get.isRegistered<AlbumPhotosController>(tag: current.id)) {
        try {
          final AlbumPhotosController albumController =
              Get.find<AlbumPhotosController>(tag: current.id);

          final int index = albumController.media.indexWhere(
            (asset) => asset.id == current.id,
          );

          if (index != -1) {
            albumController.media[index] = newAsset;
            albumController.media.refresh();

            debugPrint("ALBUM MEDIA UPDATED => OLD ASSET REPLACED");
          }
        } catch (e) {
          debugPrint("AlbumPhotosController Rename Update Error => $e");
        }
      }

      try {
        final controllers = Get.find<AlbumPhotosController>();

        final int index = controllers.media.indexWhere(
          (asset) => asset.id == current.id,
        );

        if (index != -1) {
          controllers.media[index] = newAsset;
          controllers.media.refresh();

          debugPrint("ACTIVE ALBUM CONTROLLER UPDATED => $newAsset");
        }
      } catch (e) {
        debugPrint("Active Album Controller Not Found => $e");
      }

      if (Get.isRegistered<AlbumsController>()) {
        try {
          await Get.find<AlbumsController>().loadAlbums();

          debugPrint("ALBUMS CONTROLLER REFRESHED");
        } catch (e) {
          debugPrint("Albums Rename Refresh Error => $e");
        }
      }

      if (Get.isRegistered<PlacesController>()) {
        try {
          final PlacesController placesController =
              Get.find<PlacesController>();

          for (final PlaceGroup place in placesController.places) {
            final int index = place.assets.indexWhere(
              (asset) => asset.id == current.id,
            );

            if (index != -1) {
              place.assets[index] = newAsset;
            }
          }

          placesController.places.refresh();
        } catch (e) {
          debugPrint("Places Rename Update Error => $e");
        }
      }

      debugPrint("================================");
      debugPrint("RENAME SUCCESS");
      debugPrint("New File : $finalFileName");
      debugPrint("New Asset ID : ${newAsset.id}");
      debugPrint("================================");

      AppToast.show("Photo renamed successfully");
    } catch (e, stackTrace) {
      debugPrint("RENAME ERROR");
      debugPrint("$e");

      debugPrintStack(stackTrace: stackTrace);

      AppToast.show("Unable to rename photo");
    }
  }

  Future<void> resizePhoto() async {
    try {
      final AssetEntity current = currentAsset;

      final File? file = await current.file;

      if (file == null || !await file.exists()) {
        AppToast.show("Image file not found");
        return;
      }

      final Uint8List originalBytes = await file.readAsBytes();

      final ui.Codec originalCodec = await ui.instantiateImageCodec(
        originalBytes,
      );

      final ui.FrameInfo originalFrame = await originalCodec.getNextFrame();

      final ui.Image originalImage = originalFrame.image;

      final int originalWidth = originalImage.width;
      final int originalHeight = originalImage.height;

      if (originalWidth <= 0 || originalHeight <= 0) {
        AppToast.show("Invalid image resolution");
        return;
      }

      final String oldFileName = file.path.split('/').last;

      final int dotIndex = oldFileName.lastIndexOf('.');

      final String oldName = dotIndex != -1
          ? oldFileName.substring(0, dotIndex)
          : oldFileName;

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
        AppToast.show("Please enter image name");
        return;
      }

      final ui.Codec resizedCodec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: result.width,
        targetHeight: result.height,
      );

      final ui.FrameInfo resizedFrame = await resizedCodec.getNextFrame();

      final ui.Image resizedImage = resizedFrame.image;

      final ByteData? resizedData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (resizedData == null) {
        AppToast.show("Unable to process image");
        return;
      }

      final Uint8List resizedBytes = resizedData.buffer.asUint8List();

      String fileName = result.name.trim();

      fileName = fileName.replaceAll(RegExp(r'[\/\\:*?"<>|]'), '_');

      fileName = fileName.replaceFirst(
        RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false),
        '',
      );

      if (fileName.isEmpty) {
        fileName = 'Resized_${DateTime.now().millisecondsSinceEpoch}';
      }

      final AssetEntity resizedAsset = await PhotoManager.editor.saveImage(
        resizedBytes,
        filename: '$fileName.png',
      );

      final File? newFile = await resizedAsset.file;

      if (newFile != null && await newFile.exists()) {
        final Uint8List newBytes = await newFile.readAsBytes();

        final ui.Codec verifyCodec = await ui.instantiateImageCodec(newBytes);

        final ui.FrameInfo verifyFrame = await verifyCodec.getNextFrame();

        final ui.Image verifyImage = verifyFrame.image;

        debugPrint("================================");
        debugPrint("RESIZE VERIFIED");
        debugPrint("Original : $originalWidth x $originalHeight");
        debugPrint("Target   : ${result.width} x ${result.height}");
        debugPrint("Saved    : ${verifyImage.width} x ${verifyImage.height}");
        debugPrint("Quality  : LOSSLESS PNG");
        debugPrint("================================");
      }

      if (Get.isRegistered<PhotosController>()) {
        final PhotosController photosController = Get.find<PhotosController>();

        photosController.addEditedAsset(resizedAsset);
      }

      if (Get.isRegistered<AlbumsController>()) {
        await Get.find<AlbumsController>().loadAlbums();
      }

      Get.off(() => PhotoViewScreen(asset: resizedAsset));
    } catch (e, stackTrace) {
      debugPrint("================================");
      debugPrint("RESIZE ERROR");
      debugPrint("$e");
      debugPrintStack(stackTrace: stackTrace);
      debugPrint("================================");

      AppToast.show("Unable to resize photo");
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

    if (currentIndex.value >= 0 &&
        currentIndex.value < media.length &&
        media[currentIndex.value].type == AssetType.video) {
      _openSlideshowVideo(media[currentIndex.value]);
      return;
    }

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
    } else if (slideshowMoveBackwards) {
      nextIndex = currentIndex.value - 1;

      if (nextIndex < 0) {
        if (slideshowLoop) {
          nextIndex = media.length - 1;
        } else {
          stopSlideshow();
          return;
        }
      }
    } else {
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
  final RxInt speed = 1.obs;

  final RxString animation = "None".obs;

  final RxBool includeGifs = true.obs;
  final RxBool randomOrder = false.obs;
  final RxBool moveBackwards = false.obs;
  final RxBool loop = false.obs;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: InnerChrome.dialogBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Slideshow', style: ChromeText.title),
            const SizedBox(height: 12),
            Text('Speed', style: ChromeText.body),
            const SizedBox(height: 8),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: InnerChrome.dialogField,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (speed.value > 1) {
                        speed.value--;
                      }
                    },
                    icon: Icon(
                      Icons.remove,
                      size: 18,
                      color: InnerChrome.dialogIcon,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Obx(
                        () => Text(
                          '${speed.value}s',
                          style: ChromeText.row,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (speed.value < 10) {
                        speed.value++;
                      }
                    },
                    icon: Icon(
                      Icons.add,
                      size: 18,
                      color: InnerChrome.dialogIcon,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _row(
              'Animation',
              DropdownButtonHideUnderline(
                child: Obx(
                  () => DropdownButton<String>(
                    value: animation.value,
                    isDense: true,
                    dropdownColor: InnerChrome.dialogDrop,
                    iconEnabledColor: InnerChrome.dialogIcon,
                    style: ChromeText.row,
                    items: [
                      DropdownMenuItem(
                        value: 'None',
                        child: Text('None', style: ChromeText.row),
                      ),
                      DropdownMenuItem(
                        value: 'Fade',
                        child: Text('Fade', style: ChromeText.row),
                      ),
                      DropdownMenuItem(
                        value: 'Slide',
                        child: Text('Slide', style: ChromeText.row),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      animation.value = value;
                    },
                  ),
                ),
              ),
            ),
            _check('Include GIFs', includeGifs, fallback: true),
            _check('Random order', randomOrder),
            _check('Move backwards', moveBackwards),
            _check('Loop Slideshow', loop),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChromeButton.cancel(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChromeButton.ok(
                    onPressed: () {
                      Navigator.of(context).pop(
                        SlideShowResult(
                          duration: Duration(seconds: speed.value),
                          animation: animation.value,
                          includeGifs: includeGifs.value,
                          randomOrder: randomOrder.value,
                          moveBackwards: moveBackwards.value,
                          loop: loop.value,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _check(String title, RxBool value, {bool fallback = false}) {
    return _row(
      title,
      Obx(
        () => Checkbox(
          value: value.value,
          activeColor: InnerChrome.accent,
          side: BorderSide(color: InnerChrome.faint, width: 1.4),
          onChanged: (next) {
            value.value = next ?? fallback;
          },
        ),
      ),
    );
  }

  Widget _row(String title, Widget trailing) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(child: Text(title, style: ChromeText.row)),
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
    return ChromeDialog(
      title: 'Rename',
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        style: ChromeText.row,
        decoration: InputDecoration(
          hintText: 'File name',
          hintStyle: TextStyle(color: InnerChrome.dialogHint, fontSize: 14),
          filled: true,
          fillColor: InnerChrome.dialogField,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        ChromeButton.cancel(onPressed: () => Navigator.of(context).pop()),
        ChromeButton.ok(
          label: 'Save',
          onPressed: () {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(name);
          },
        ),
      ],
    );
  }
}

class ResizeResult {
  final int width;
  final int height;
  final String name;

  ResizeResult({required this.width, required this.height, required this.name});
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

  void _widthChanged() {
    if (_updating) return;

    final int? width = int.tryParse(widthController.text.trim());

    if (width == null || width <= 0) return;

    _updating = true;

    final int height = (width / aspectRatio).round();

    heightController.text = height.toString();

    _updating = false;
  }

  void _heightChanged() {
    if (_updating) return;

    final int? height = int.tryParse(heightController.text.trim());

    if (height == null || height <= 0) return;

    _updating = true;

    final int width = (height * aspectRatio).round();

    widthController.text = width.toString();

    _updating = false;
  }

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

    Navigator.of(
      context,
    ).pop(ResizeResult(width: width, height: height, name: name));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: InnerChrome.dialogBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Resize', style: ChromeText.title),
            ),

            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _dimensionField(
                    label: "Width",
                    controller: widthController,
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(bottom: 10, left: 8, right: 8),
                  child: Text(
                    ":",
                    style: TextStyle(
                      fontSize: 16,
                      color: InnerChrome.muted,
                    ),
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

            TextField(
              controller: nameController,
              textInputAction: TextInputAction.done,
              style: ChromeText.row,
              decoration: InputDecoration(
                filled: true,
                fillColor: InnerChrome.dialogField,
                hintText: "Title",
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: InnerChrome.dialogHint,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: InnerChrome.dialogIcon,
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
                        backgroundColor: InnerChrome.dialogSecondaryBg,
                        foregroundColor: InnerChrome.dialogSecondaryFg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                        backgroundColor: InnerChrome.dialogPrimaryBg,
                        foregroundColor: InnerChrome.dialogPrimaryFg,
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

  Widget _dimensionField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: InnerChrome.muted),
        ),

        const SizedBox(height: 5),

        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            filled: true,
            fillColor: InnerChrome.dialogField,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide.none,
            ),
          ),
          style: ChromeText.row,
        ),
      ],
    );
  }
}
