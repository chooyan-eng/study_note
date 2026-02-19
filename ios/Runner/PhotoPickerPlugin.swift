import Flutter
import UIKit

/// MethodChannel 'study_note/photo_picker' を登録し、カメラ撮影を提供するプラグイン。
/// 撮影した画像を PNG データとして Flutter 側に返す。
class PhotoPickerPlugin: NSObject, FlutterPlugin, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  private var flutterResult: FlutterResult?

  // MARK: - FlutterPlugin

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "study_note/photo_picker",
      binaryMessenger: registrar.messenger()
    )
    let instance = PhotoPickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickPhoto":
      self.flutterResult = result
      openCamera()
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Camera

  private func openCamera() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      flutterResult?(
        FlutterError(
          code: "CAMERA_UNAVAILABLE",
          message: "Camera is not available on this device",
          details: nil
        )
      )
      flutterResult = nil
      return
    }

    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = self

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard
        let windowScene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first(where: { $0.activationState == .foregroundActive }),
        let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
      else {
        self.flutterResult?(
          FlutterError(
            code: "NO_VIEW_CONTROLLER",
            message: "Could not find root view controller",
            details: nil
          )
        )
        self.flutterResult = nil
        return
      }
      rootVC.present(picker, animated: true)
    }
  }

  // MARK: - UIImagePickerControllerDelegate

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true)

    guard
      let image = info[.originalImage] as? UIImage,
      let pngData = image.pngData()
    else {
      flutterResult?(
        FlutterError(
          code: "IMAGE_CONVERSION_FAILED",
          message: "Failed to convert captured image to PNG",
          details: nil
        )
      )
      flutterResult = nil
      return
    }

    flutterResult?(FlutterStandardTypedData(bytes: pngData))
    flutterResult = nil
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    flutterResult?(nil)
    flutterResult = nil
  }
}
