import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // ponytail: mirrors lib/core/config/app_info.dart — keep in sync.
  private let appName = "Glibusta"
  private let appLegaleseOwner = "GoSayram Glibusta"

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Re-target the standard About menu item so the panel shows a copyright
    // computed at runtime (current year + app owner) instead of the Info.plist
    // string baked at build time.
    if let appMenu = NSApp.mainMenu?.items.first?.submenu {
      for item in appMenu.items
        where item.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:)) {
        item.target = self
        item.action = #selector(showAboutPanel)
      }
    }
  }

  @objc private func showAboutPanel() {
    let year = Calendar.current.component(.year, from: Date())
    let copyright = "Copyright © \(year) \(appLegaleseOwner). All rights reserved."
    // `.copyright` is not a Swift enum case; use the raw value that the panel
    // honours (NSAboutPanelOptionCopyright = "Copyright").
    NSApp.orderFrontStandardAboutPanel(options: [
      .applicationName: appName,
      NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): copyright,
    ])
  }
}
