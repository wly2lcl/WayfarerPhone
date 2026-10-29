import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "wayfarer/local_data",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard call.arguments == nil else {
        result(FlutterError(code: "invalid_arguments", message: "No arguments expected", details: nil))
        return
      }
      do {
        for directory in [FileManager.SearchPathDirectory.documentDirectory, .applicationSupportDirectory] {
          var url = try FileManager.default.url(
            for: directory, in: .userDomainMask, appropriateFor: nil, create: true
          )
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
        }
        result(nil)
      } catch {
        result(FlutterError(
          code: "backup_exclusion_failed", message: error.localizedDescription, details: nil
        ))
      }
    }
  }
}
