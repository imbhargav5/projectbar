import AppKit
import SwiftUI

@main
struct ProjectBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.largeTitle)
                Text("Project settings live directly on each ProjectBar card.")
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(width: 420, height: 180)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let launchAtLogin = LaunchAtLoginManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--enable-launch-at-login") {
            self.launchAtLogin.setEnabled(true)
        }
        self.statusItemController = StatusItemController(
            store: ProjectStore(),
            launchAtLogin: self.launchAtLogin)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        self.launchAtLogin.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.statusItemController?.stop()
    }
}
