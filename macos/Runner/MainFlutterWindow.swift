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

    super.awakeFromNib()
  }
}
