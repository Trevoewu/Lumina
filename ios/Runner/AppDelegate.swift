import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appIconChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "lumina/app_icon",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(UIApplication.shared.supportsAlternateIcons)
      case "getIcon":
        result(UIApplication.shared.alternateIconName ?? "default")
      case "setIcon":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(
            FlutterError(
              code: "unsupported",
              message: "Alternate app icons are not supported on this device.",
              details: nil
            )
          )
          return
        }
        guard
          let arguments = call.arguments as? [String: Any],
          let iconId = arguments["iconId"] as? String,
          ["default", "a1", "a2", "b1", "b2", "c1", "c2"].contains(iconId)
        else {
          result(
            FlutterError(
              code: "invalid_icon",
              message: "Unknown app icon.",
              details: nil
            )
          )
          return
        }
        let alternateName: String? = iconId == "default" ? nil : iconId
        UIApplication.shared.setAlternateIconName(alternateName) { error in
          if let error {
            result(
              FlutterError(
                code: "icon_change_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    appIconChannel = channel
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AirPlayRoutePicker") {
      registrar.register(
        AirPlayRoutePickerFactory(),
        withId: "lumina/airplay_route_picker"
      )
    }
  }
}
