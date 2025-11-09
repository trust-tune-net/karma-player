import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let targetSize = NSSize(width: 1400, height: 840)
    self.setContentSize(targetSize)
    self.minSize = NSSize(width: 1100, height: 720)

    // Register generated plugins (package plugins)
    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register custom AudioDeviceChannel plugin
    NSLog("[MainFlutterWindow] Registering AudioDeviceChannel...")
    let registrar = flutterViewController.registrar(forPlugin: "AudioDeviceChannel")
    AudioDeviceChannel.register(with: registrar)
    NSLog("[MainFlutterWindow] ✓ AudioDeviceChannel registered successfully")

    super.awakeFromNib()
  }
}
