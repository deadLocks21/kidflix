import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Enable native full-screen: green ⊕ button, View ▸ Enter Full Screen
    // (⌃⌘F), and media_kit's in-player fullscreen button all route through
    // `toggleFullScreen:`, which is a no-op unless the window advertises
    // `.fullScreenPrimary`. AppKit normally adds this automatically for a
    // titled, resizable window — but that auto-behaviour is unreliable in
    // sandboxed Mac App Store / TestFlight builds: the "Enter Full Screen"
    // menu item ends up disabled there even though it works in a locally
    // signed release build. Setting it explicitly makes full-screen
    // capability deterministic across every build flavour.
    self.collectionBehavior.insert(.fullScreenPrimary)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
