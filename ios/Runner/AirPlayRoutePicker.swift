import AVKit
import Flutter
import UIKit

/// Hosts the system AirPlay route picker so the player's output button opens
/// the real route sheet.
///
/// `AVRoutePickerView` is the only supported way to present that sheet — the
/// picker cannot be summoned programmatically without private API. It draws its
/// own glyph and tracks the active route itself, so Flutter supplies nothing
/// but the tint colours and lets the control own its appearance and state.
final class AirPlayRoutePickerFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    AirPlayRoutePickerPlatformView(frame: frame, arguments: args)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class AirPlayRoutePickerPlatformView: NSObject, FlutterPlatformView {
  private let routePickerView: AVRoutePickerView

  init(frame: CGRect, arguments args: Any?) {
    routePickerView = AVRoutePickerView(frame: frame)
    routePickerView.backgroundColor = .clear
    // This player only ever routes audio. Left on, the picker would sort video
    // destinations such as an Apple TV above the user's headphones.
    routePickerView.prioritizesVideoDevices = false
    super.init()

    guard let params = args as? [String: Any] else { return }
    if let tint = params["tintColor"] as? NSNumber {
      routePickerView.tintColor = UIColor(argb: tint.uint32Value)
    }
    if let activeTint = params["activeTintColor"] as? NSNumber {
      routePickerView.activeTintColor = UIColor(argb: activeTint.uint32Value)
    }
  }

  func view() -> UIView {
    routePickerView
  }
}

extension UIColor {
  fileprivate convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
