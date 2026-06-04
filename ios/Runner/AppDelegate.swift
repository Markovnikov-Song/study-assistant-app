import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "focus_guard",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getStatus":
          result([
            "platform": "ios",
            "usageAccessGranted": false,
            "overlayGranted": false,
            "screenTimeAvailable": false,
            "entitlementRequired": true,
            "serviceAvailable": false
          ])
        case "openUsageAccessSettings", "openOverlaySettings":
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
          result(nil)
        case "getInstalledApps":
          result([])
        case "start", "stop":
          result(FlutterError(
            code: "IOS_SCREEN_TIME_ENTITLEMENT_REQUIRED",
            message: "iOS app locking requires Apple's Screen Time entitlement.",
            details: nil
          ))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
