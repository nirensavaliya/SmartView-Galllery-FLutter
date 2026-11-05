import UIKit
import Flutter
import Photos
import AVFoundation
import GoogleMaps

// This project uses the UIScene lifecycle (SceneDelegate + scene manifest in
// Info.plist). With scenes, `window?.rootViewController` does NOT exist yet in
// didFinishLaunching, so the Flutter engine has to be set up in
// `didInitializeImplicitFlutterEngine`. Doing it there registers ALL plugins
// (photo_manager, permission_handler, ...) and the "native_camera" channel.

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private let nativeChannelName = "native_camera"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Google Maps (Places screen). The key is read from Info.plist
        // (key: GMSApiKey). Without it the map screen would crash on iOS.
        if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !key.isEmpty {
            GMSServices.provideAPIKey(key)
        }

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }

    func didInitializeImplicitFlutterEngine(
        _ engineBridge: FlutterImplicitEngineBridge
    ) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let channel = FlutterMethodChannel(
            name: nativeChannelName,
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )

        channel.setMethodCallHandler { [weak self] call, result in

            guard let self = self else {
                result(
                    FlutterError(
                        code: "APP_DELEGATE_ERROR",
                        message: "AppDelegate unavailable",
                        details: nil
                    )
                )
                return
            }

            switch call.method {

            // =====================================================
            // CAMERA
            // =====================================================
            case "openCamera":
                DispatchQueue.main.async {
                    self.openNativeCamera(result: result)
                }

            // =====================================================
            // COPY MEDIA TO ALBUM
            // =====================================================
            case "copyMediaToAlbum":

                guard
                    let args = call.arguments as? [String: Any],
                    let sourceId = args["assetId"] as? String,
                    let albumId = args["albumId"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS",
                            message: "assetId or albumId missing",
                            details: nil
                        )
                    )
                    return
                }

                self.copyMediaToAlbum(
                    sourceAssetId: sourceId,
                    destinationAlbumId: albumId,
                    result: result
                )

            // =====================================================
            // BIOMETRIC SETTINGS
            // iOS cannot open the Face ID / Touch ID page directly,
            // so the app's own page in Settings is opened.
            // =====================================================
            case "openBiometricSettings":
                DispatchQueue.main.async {
                    self.openAppSettings(result: result)
                }

            // Android-only features: nothing to do on iOS.
            case "requestMediaManagement":
                result(true)

            case "trim":
                guard
                    let args = call.arguments as? [String: Any],
                    let sourcePath = args["sourcePath"] as? String,
                    let startMs = args["startMs"] as? Int,
                    let endMs = args["endMs"] as? Int
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS",
                            message: "Trim arguments missing",
                            details: nil
                        )
                    )
                    return
                }
                self.trimVideo(
                    sourcePath: sourcePath,
                    startMs: startMs,
                    endMs: endMs,
                    result: result
                )

            case "trimFrames":
                guard
                    let args = call.arguments as? [String: Any],
                    let sourcePath = args["sourcePath"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS",
                            message: "Trim arguments missing",
                            details: nil
                        )
                    )
                    return
                }
                let count = args["count"] as? Int ?? 8
                self.trimFrames(
                    sourcePath: sourcePath,
                    count: count,
                    result: result
                )

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }


    // =========================================================
    // TOP VIEW CONTROLLER (works with scenes)
    // =========================================================

    private func topViewController() -> UIViewController? {

        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let activeScene =
            windowScenes.first(where: { $0.activationState == .foregroundActive })
            ?? windowScenes.first

        let window =
            activeScene?.windows.first(where: { $0.isKeyWindow })
            ?? activeScene?.windows.first

        var top = window?.rootViewController

        while let presented = top?.presentedViewController {
            top = presented
        }

        return top
    }


    // =========================================================
    // OPEN APP SETTINGS
    // =========================================================

    private func openAppSettings(result: @escaping FlutterResult) {

        guard
            let url = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(url)
        else {
            result(
                FlutterError(
                    code: "SETTINGS_ERROR",
                    message: "Unable to open Settings",
                    details: nil
                )
            )
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            result(success)
        }
    }


    // =========================================================
    // OPEN NATIVE CAMERA
    // =========================================================

    private func openNativeCamera(
        result: @escaping FlutterResult
    ) {

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            result(
                FlutterError(
                    code: "CAMERA_NOT_AVAILABLE",
                    message: "Camera is not available on this device",
                    details: nil
                )
            )
            return
        }

        guard let presenter = topViewController() else {
            result(
                FlutterError(
                    code: "VIEW_CONTROLLER_NOT_FOUND",
                    message: "Unable to find root view controller",
                    details: nil
                )
            )
            return
        }

        let picker = UIImagePickerController()

        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = self

        presenter.present(picker, animated: true) {
            result(true)
        }
    }

    private func trimVideo(
        sourcePath: String,
        startMs: Int,
        endMs: Int,
        result: @escaping FlutterResult
    ) {
        if endMs - startMs < 500 {
            result(
                FlutterError(
                    code: "INVALID_RANGE",
                    message: "Select at least half a second",
                    details: nil
                )
            )
            return
        }

        let source = URL(fileURLWithPath: sourcePath)
        let asset = AVAsset(url: source)
        guard let export = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            result(
                FlutterError(
                    code: "TRIM_FAILED",
                    message: "Unable to trim video",
                    details: nil
                )
            )
            return
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("trim_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: output)

        export.outputURL = output
        export.outputFileType = .mp4
        let start = CMTime(value: CMTimeValue(startMs), timescale: 1000)
        let length = CMTime(value: CMTimeValue(endMs - startMs), timescale: 1000)
        export.timeRange = CMTimeRange(start: start, duration: length)

        export.exportAsynchronously {
            DispatchQueue.main.async {
                if export.status == .completed {
                    result(output.path)
                } else {
                    result(
                        FlutterError(
                            code: "TRIM_FAILED",
                            message: export.error?.localizedDescription ?? "Unable to trim video",
                            details: nil
                        )
                    )
                }
            }
        }
    }

    private func trimFrames(
        sourcePath: String,
        count: Int,
        result: @escaping FlutterResult
    ) {
        let safeCount = min(max(count, 4), 12)
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: URL(fileURLWithPath: sourcePath))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 90)
            let durationMs = Int(CMTimeGetSeconds(asset.duration) * 1000)
            var images: [FlutterStandardTypedData] = []
            for index in 0..<safeCount {
                let ms = safeCount == 1 ? 0 : durationMs * index / (safeCount - 1)
                let time = CMTime(value: CMTimeValue(ms), timescale: 1000)
                if let image = try? generator.copyCGImage(at: time, actualTime: nil),
                   let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.55) {
                    images.append(FlutterStandardTypedData(bytes: data))
                }
            }
            DispatchQueue.main.async {
                result(images)
            }
        }
    }


    // =========================================================
    // COPY MEDIA TO ALBUM
    // =========================================================

    private func copyMediaToAlbum(
        sourceAssetId: String,
        destinationAlbumId: String,
        result: @escaping FlutterResult
    ) {

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in

            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "PHOTO_PERMISSION_DENIED",
                            message: "Photo library permission denied",
                            details: nil
                        )
                    )
                }
                return
            }

            let sourceResult = PHAsset.fetchAssets(
                withLocalIdentifiers: [sourceAssetId],
                options: nil
            )

            guard let sourceAsset = sourceResult.firstObject else {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "SOURCE_NOT_FOUND",
                            message: "Source photo/video not found",
                            details: nil
                        )
                    )
                }
                return
            }

            let destinationResult = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [destinationAlbumId],
                options: nil
            )

            guard let destinationAlbum = destinationResult.firstObject else {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "ALBUM_NOT_FOUND",
                            message: "Destination album not found",
                            details: nil
                        )
                    )
                }
                return
            }

     PHPhotoLibrary.shared().performChanges({

         let albumChangeRequest = PHAssetCollectionChangeRequest(
             for: destinationAlbum
         )

         albumChangeRequest?.addAssets([sourceAsset] as NSArray)

     }) { success, error in

         DispatchQueue.main.async {

             if success {
                 result(true)
             } else {
                 result(
                     FlutterError(
                         code: "COPY_FAILED",
                         message:
                             error?.localizedDescription
                             ?? "Unable to copy media",
                         details: nil
                     )
                 )
             }
         }
     }
        }
    }
}


// =============================================================
// CAMERA DELEGATE
// =============================================================

extension AppDelegate:
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate {

    func imagePickerControllerDidCancel(
        _ picker: UIImagePickerController
    ) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info:
            [UIImagePickerController.InfoKey: Any]
    ) {

        let image = info[.originalImage] as? UIImage

        picker.dismiss(animated: true)

        // The old code threw the photo away. Android's camera app saves the
        // picture by itself, so on iOS it is saved to the photo library here
        // (the gallery then shows it like on Android).
        guard let image = image else { return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { _, error in
            if let error = error {
                print("Camera save error: \(error.localizedDescription)")
            }
        }
    }
}
