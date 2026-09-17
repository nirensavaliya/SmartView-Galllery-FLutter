import UIKit
import Flutter
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let nativeCameraChannel = "native_camera"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        guard let controller =
            window?.rootViewController as? FlutterViewController else {

            return super.application(
                application,
                didFinishLaunchingWithOptions: launchOptions
            )
        }

        let cameraChannel = FlutterMethodChannel(
            name: nativeCameraChannel,
            binaryMessenger: controller.binaryMessenger
        )

        cameraChannel.setMethodCallHandler { [weak self] call, result in

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
                    let assetId = call.arguments as? [String: Any],
                    let sourceId = assetId["assetId"] as? String,
                    let albumId = assetId["albumId"] as? String
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

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
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

        guard let rootViewController =
            window?.rootViewController else {

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

        rootViewController.present(
            picker,
            animated: true
        ) {
            result(true)
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

        PHPhotoLibrary.requestAuthorization(
            for: .readWrite
        ) { status in

            guard status == .authorized ||
                  status == .limited else {

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

            let sourceResult =
                PHAsset.fetchAssets(
                    withLocalIdentifiers: [sourceAssetId],
                    options: nil
                )

            guard let sourceAsset =
                sourceResult.firstObject else {

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


            let destinationResult =
                PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [destinationAlbumId],
                    options: nil
                )

            guard let destinationAlbum =
                destinationResult.firstObject else {

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

                let request =
                    PHAssetChangeRequest.creationRequestForAsset(
                        from: sourceAsset
                    )

                guard let placeholder =
                    request.placeholderForCreatedAsset else {
                    return
                }

                let albumChangeRequest =
                    PHAssetCollectionChangeRequest(
                        for: destinationAlbum
                    )

                albumChangeRequest?.addAssets(
                    [placeholder] as NSArray
                )

            }) { success, error in

                DispatchQueue.main.async {

                    if success {

                        print(
                            "IOS COPY SUCCESS: \(destinationAlbum.localizedTitle ?? "")"
                        )

                        result(true)

                    } else {

                        print(
                            "IOS COPY ERROR: \(error?.localizedDescription ?? "Unknown error")"
                        )

                        result(
                            FlutterError(
                                code: "COPY_FAILED",
                                message:
                                    error?.localizedDescription ??
                                    "Unable to copy media",
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

        picker.dismiss(
            animated: true
        )
    }


    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info:
            [UIImagePickerController.InfoKey: Any]
    ) {

        if let image =
            info[.originalImage] as? UIImage {

            print(
                "Native Camera Image Captured"
            )

            _ = image
        }

        picker.dismiss(
            animated: true
        )
    }
}