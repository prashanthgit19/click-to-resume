import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Phase0Controller.shared.bootstrap()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Phase0Controller.shared.bootstrap()
        for url in urls {
            Phase0Controller.shared.handle(url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
