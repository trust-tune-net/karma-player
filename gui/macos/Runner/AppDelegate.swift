import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // CRITICAL FIX: Ignore SIGPIPE at the OS signal level
    // 
    // This prevents the app from being terminated when writing to closed pipes,
    // which commonly happens when:
    // 1. macOS closes stdout/stderr when app is backgrounded
    // 2. App is foregrounded and Flutter tries to log
    // 3. Write to closed pipe would normally send SIGPIPE and kill process
    //
    // With SIG_IGN, the write() call will fail gracefully instead of killing the app.
    // This is the ONLY way to prevent SIGPIPE crashes - Dart-level handling doesn't work
    // because the signal terminates the process before Dart code can run.
    //
    // This is standard practice used by Chrome, Firefox, VS Code, and all major macOS apps.
    // See: https://man7.org/linux/man-pages/man2/signal.2.html
    signal(SIGPIPE, SIG_IGN)
    
    super.applicationDidFinishLaunching(notification)
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
