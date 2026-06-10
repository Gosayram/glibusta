import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    // Configure window
    self.contentViewController = flutterViewController
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    // Set default and minimum sizes
    let defaultSize = NSSize(width: 1200, height: 800)
    let minSize = NSSize(width: 900, height: 620)
    self.minSize = minSize
    self.setContentSize(defaultSize)

    // Center window on screen
    self.center()

    // Style
    self.isMovableByWindowBackground = true
    self.backgroundColor = NSColor.windowBackgroundColor

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
