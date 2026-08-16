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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.statusItemController = StatusItemController(store: ProjectStore())
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.statusItemController?.stop()
    }
}
