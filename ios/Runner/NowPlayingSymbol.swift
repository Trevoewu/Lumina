import Flutter
import UIKit

/// The "now playing" waveform in the player's Up next list, drawn as the SF
/// Symbol so it can run the system's variable-colour effect while audio
/// plays. Flutter recreates the view when playback starts or stops, so the
/// view only needs to know whether to animate.
final class NowPlayingSymbolFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NowPlayingSymbolPlatformView(frame: frame, arguments: args)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class NowPlayingSymbolPlatformView: NSObject, FlutterPlatformView {
  private let imageView: UIImageView

  init(frame: CGRect, arguments args: Any?) {
    let params = args as? [String: Any] ?? [:]
    let pointSize = (params["size"] as? NSNumber)?.doubleValue ?? 20
    let configuration = UIImage.SymbolConfiguration(
      pointSize: CGFloat(pointSize),
      weight: .regular
    )
    imageView = UIImageView(
      image: UIImage(systemName: "waveform", withConfiguration: configuration)
    )
    imageView.frame = frame
    imageView.contentMode = .center
    imageView.backgroundColor = .clear
    if let color = params["color"] as? NSNumber {
      imageView.tintColor = UIColor(nowPlayingARGB: color.uint32Value)
    }
    super.init()

    let animating = (params["animating"] as? Bool) ?? false
    // Symbol effects arrived in iOS 17; earlier systems, and readers who
    // asked for less motion, get the still waveform.
    guard animating, !UIAccessibility.isReduceMotionEnabled else { return }
    if #available(iOS 18.0, *) {
      imageView.addSymbolEffect(
        .variableColor.cumulative.dimInactiveLayers.nonReversing,
        options: .repeat(.continuous)
      )
    } else if #available(iOS 17.0, *) {
      imageView.addSymbolEffect(
        .variableColor.cumulative.dimInactiveLayers.nonReversing,
        options: .repeating
      )
    }
  }

  func view() -> UIView {
    imageView
  }
}

extension UIColor {
  fileprivate convenience init(nowPlayingARGB argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
