import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

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
