import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    self.backgroundColor = NSColor(
      calibratedRed: 18.0 / 255.0,
      green: 18.0 / 255.0,
      blue: 18.0 / 255.0,
      alpha: 1.0
    )
    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unified
    }

    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Default to iPad-like dimensions (landscape iPad 10th gen).
    let iPadSize = NSSize(width: 1024, height: 768)
    self.setContentSize(iPadSize)
    self.minSize = NSSize(width: 768, height: 600)
    if let screen = self.screen {
      let screenFrame = screen.visibleFrame
      let x = screenFrame.midX - iPadSize.width / 2
      let y = screenFrame.midY - iPadSize.height / 2
      self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    setupTrafficLightAlignment()
    repositionTrafficLights()

    super.awakeFromNib()
  }

  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    repositionTrafficLights()
  }

  /// Repositions the macOS traffic lights (close, miniaturize, zoom) so their
  /// vertical center shares the exact same horizontal central axis (Y = 19.0pt)
  /// as the Flutter persistent top control bar / sidebar toolbar buttons (height 38.0pt).
  func repositionTrafficLights() {
    guard !self.styleMask.contains(.fullScreen),
          let close = standardWindowButton(.closeButton),
          let mini = standardWindowButton(.miniaturizeButton),
          let zoom = standardWindowButton(.zoomButton),
          let titlebar = close.superview else { return }

    let targetCenterYFromTop: CGFloat = 19.0
    let buttonDiameter: CGFloat = 14.0
    let originY = titlebar.isFlipped
        ? targetCenterYFromTop - (buttonDiameter / 2.0)
        : titlebar.bounds.height - targetCenterYFromTop - (buttonDiameter / 2.0)

    close.frame.origin.y = originY
    mini.frame.origin.y = originY
    zoom.frame.origin.y = originY
  }

  private func setupTrafficLightAlignment() {
    guard let themeFrame = self.contentView?.superview else { return }
    let themeFrameClass: AnyClass = type(of: themeFrame)
    let sel = NSSelectorFromString("_tileTitlebarAndRedisplay:")

    guard let origMethod = class_getInstanceMethod(themeFrameClass, sel) else { return }
    typealias TileFunc = @convention(c) (NSView, Selector, Bool) -> Void
    let origImp = unsafeBitCast(method_getImplementation(origMethod), to: TileFunc.self)

    let block: @convention(block) (NSView, Bool) -> Void = { [weak self] view, redisplay in
      origImp(view, sel, redisplay)
      if let window = self ?? (view.window as? MainFlutterWindow) {
        window.repositionTrafficLights()
      }
    }
    method_setImplementation(origMethod, imp_implementationWithBlock(block))
  }
}
