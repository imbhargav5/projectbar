import AppKit
import Foundation
@testable import ProjectBar
import ProjectBarCore
import SwiftUI
import Testing

/// Opt-in native previews for visual review, without launching the app or touching user data.
/// PROJECTBAR_PREVIEW_DIR=/tmp/projectbar-previews swift test --filter ProjectBoardRenderingTests
@MainActor
struct ProjectBoardRenderingTests {
    @Test("Render native board and settings fixtures for visual inspection")
    func renderPreviews() async throws {
        guard let outputPath = ProcessInfo.processInfo.environment["PROJECTBAR_PREVIEW_DIR"] else { return }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared
        let now = Calendar.autoupdatingCurrent.date(from: DateComponents(
            year: 2026, month: 9, day: 16, hour: 14, minute: 20))!
        var fixtures: [(String, Int, CGSize, ColorScheme, ProjectCardDensity)] = []
        for density in ProjectCardDensity.allCases {
            for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                for count in [0, 1, 16, 50] {
                    fixtures.append(("board-\(density.rawValue.lowercased())-\(appearance)-\(count)", count,
                                     CGSize(width: 812, height: count == 0 ? 440 : 720), scheme, density))
                }
            }
            fixtures.append(("board-\(density.rawValue.lowercased())-two-columns", 16,
                             CGSize(width: 536, height: 720), .light, density))
            fixtures.append(("board-\(density.rawValue.lowercased())-one-column", 16,
                             CGSize(width: 320, height: 600), .light, density))
        }
        fixtures += [
            ("board-pinned", 16, CGSize(width: 812, height: 720), .light, .compact),
            ("board-running", 16, CGSize(width: 812, height: 720), .light, .compact),
            ("board-no-matches", 16, CGSize(width: 812, height: 720), .light, .compact),
            ("board-completion", 16, CGSize(width: 812, height: 720), .light, .compact),
            ("board-unavailable-folder", 16, CGSize(width: 812, height: 720), .light, .compact),
            ("board-long-name", 16, CGSize(width: 812, height: 720), .light, .compact),
            ("board-density-switch", 50, CGSize(width: 812, height: 720), .light, .compact),
            ("board-focus-after-filter", 16, CGSize(width: 812, height: 720), .light, .compact),
            ("board-keyboard-actions", 16, CGSize(width: 812, height: 720), .light, .compact),
        ]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for (name, count, size, scheme, density) in fixtures {
            if let requested = ProcessInfo.processInfo.environment["PROJECTBAR_PREVIEW_FIXTURE"], requested != name { continue }
            var projects = self.projects(count: count, now: now)
            if name == "board-long-name" {
                projects[0].name = "An unusually long project name that needs two complete lines and a useful tooltip"
                projects[0].dailyRunTarget = 200
            }
            let url = directory.appendingPathComponent("state.json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(ProjectBarState(projects: projects)).write(to: url)
            let store = ProjectStore(persistenceURL: url)
            store.tick(at: now)
            let suite = "ProjectBarPreview-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let preferences = ProjectBoardPreferences(defaults: defaults)
            preferences.density = density
            let interaction = ProjectBoardInteraction()
            if name == "board-pinned" {
                preferences.togglePin(for: projects[1].id)
                preferences.togglePin(for: projects[6].id)
                interaction.selectedProjectID = projects[1].id
            }
            if name == "board-running" { interaction.filter = .running }
            if name == "board-no-matches" { interaction.query = "No matching project" }
            if name == "board-completion" {
                let completed = projects[2]
                interaction.completionNotice = .init(projectID: completed.id,
                                                     runID: try #require(completed.completedRuns.last?.id), projectName: completed.name)
            }
            if name == "board-unavailable-folder" {
                interaction.folderMessage = "Folder unavailable: /Volumes/OfflineDrive/My Project. Check that the folder or drive is accessible."
            }
            if name == "board-density-switch" {
                interaction.selectedProjectID = projects[10].id
                interaction.scrollAnchor = projects[9].id
            }
            if name == "board-focus-after-filter" || name == "board-keyboard-actions" {
                interaction.selectedProjectID = projects[0].id
            }
            let view = ProjectBoardView(
                store: store, launchAtLogin: LaunchAtLoginManager(service: PreviewLoginService()),
                preferences: preferences, interaction: interaction, onClose: {})
                .environment(\.colorScheme, scheme)
            try await self.render(view, name: name, size: size, scheme: scheme, output: output) { keyboard in
                if name == "board-density-switch" {
                    let anchor = try #require(interaction.scrollAnchor)
                    preferences.density = .comfortable
                    try await Task.sleep(for: .milliseconds(250))
                    #expect(interaction.selectedProjectID == projects[10].id)
                    #expect(interaction.scrollAnchor == anchor)
                }
                if name == "board-focus-after-filter" {
                    let keyboard = try #require(keyboard)
                    #expect(keyboard.gridFocused)
                    interaction.filter = .complete
                    try await Task.sleep(for: .milliseconds(150))
                    #expect(interaction.selectedProjectID == projects[2].id)
                    #expect(keyboard.gridFocused)
                    interaction.query = "No matching project"
                    try await Task.sleep(for: .milliseconds(150))
                    #expect(interaction.selectedProjectID == nil)
                    #expect(!keyboard.gridFocused)
                    #expect(keyboard.window?.firstResponder is NSTextView)
                }
                if name == "board-keyboard-actions" {
                    let keyboard = try #require(keyboard)
                    #expect(keyboard.gridFocused)
                    keyboard.onCommand?(.search)
                    try await Task.sleep(for: .milliseconds(150))
                    let editor = try #require(keyboard.window?.firstResponder as? NSTextView)
                    editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
                    try await Task.sleep(for: .milliseconds(150))
                    #expect(keyboard.gridFocused)
                    #expect(interaction.selectedProjectID == projects[0].id)
                    #expect(store.projects[0].activeRun == nil)
                    let windowNumber = try #require(keyboard.window?.windowNumber)
                    let key = try #require(NSEvent.keyEvent(
                        with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                        windowNumber: windowNumber, context: nil,
                        characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
                    #expect(keyboard.handle(key) == nil)
                    #expect(keyboard.handle(key) == nil) // Same rendered intent cannot toggle back.
                    #expect(store.projects[0].activeRun != nil)
                    #expect(store.projects[0].completedRuns.isEmpty)
                    try await Task.sleep(for: .milliseconds(150))
                    #expect(keyboard.handle(key) == nil)
                    #expect(store.projects[0].activeRun == nil)
                    #expect(store.projects[0].completedRuns.count == 1)
                    try await Task.sleep(for: .milliseconds(150))
                }
            }
        }
        for target in [1, 200, 0] {
            let view = ProjectSettingsView(
                project: ProjectRecord(name: "ProjectBar", dailyRunTarget: target), onSave: { _, _, _ in })
            try await self.render(view, name: "settings-\(target)", size: CGSize(width: 460, height: 450),
                                  scheme: .light, output: output)
        }
    }

    private func render<V: View>(
        _ view: V, name: String, size: CGSize, scheme: ColorScheme, output: URL,
        afterLayout: (@MainActor (ProjectBoardKeyboard.KeyboardView?) async throws -> Void)? = nil) async throws
    {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let hosting = NSHostingView(rootView: view
            .environment(\.colorScheme, scheme)
            .environment(\.controlActiveState, .active)
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        hosting.frame = CGRect(origin: .zero, size: size)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(400))
        try await afterLayout?(self.keyboard(in: hosting))
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(250))
        hosting.display()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: output.appendingPathComponent("\(name).png"))
        #expect(data.count > 5000)
        window.close()
    }

    private func keyboard(in view: NSView) -> ProjectBoardKeyboard.KeyboardView? {
        if let keyboard = view as? ProjectBoardKeyboard.KeyboardView { return keyboard }
        return view.subviews.lazy.compactMap { self.keyboard(in: $0) }.first
    }

    private func projects(count: Int, now: Date) -> [ProjectRecord] {
        let names = [
            "ProjectBar", "Agent orchestration playground", "CodexBar", "Design system exploration",
            "Documentation", "Weekly research", "API integrations", "Personal website",
            "Cloudflare Workers", "Notes", "Developer tools", "Mobile experiments",
            "Community projects", "Performance", "Open source", "Weekend ideas",
        ]
        return (0..<count).map { index in
            let target = index % 4 == 2 ? 2 : 10
            let completed = index % 4 == 2 ? 2 : (index % 4 == 1 ? 1 : 0)
            return ProjectRecord(
                name: index < names.count ? names[index] : "Project \(index + 1)",
                folderPath: index % 3 == 0 ? "/tmp/ProjectBarPreview/Project-\(index)" : nil,
                dailyRunTarget: target,
                cadencePeriod: index % 5 == 4 ? .weekly : .daily,
                completedRuns: (0..<completed).map { offset in
                    let date = now.addingTimeInterval(-Double((offset + 1) * 1800))
                    return CompletedAgentRun(startedAt: date.addingTimeInterval(-600), completedAt: date)
                },
                activeRun: index % 4 == 1 ? ActiveAgentRun(startedAt: now.addingTimeInterval(-480)) : nil)
        }
    }
}

@MainActor
private final class PreviewLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus { .disabled }
    func register() throws {}
    func unregister() throws {}
    func openSystemSettings() {}
}
