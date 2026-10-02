import AppKit
import Foundation
@testable import ProjectBar
import ProjectBarCore
import Testing

@MainActor
struct ProjectBoardInteractionTests {
    @Test("Density and pins persist independently of project records")
    func preferencesPersist() throws {
        let suite = "ProjectBarPreferencesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ProjectBoardPreferences(defaults: defaults)
        #expect(first.density == .compact)
        #expect(first.pinnedProjectIDs.isEmpty)
        let kept = UUID(), removed = UUID()
        first.density = .comfortable
        first.togglePin(for: kept)
        first.togglePin(for: removed)
        let reloaded = ProjectBoardPreferences(defaults: defaults)
        #expect(reloaded.density == .comfortable)
        #expect(reloaded.pinnedProjectIDs == [kept, removed])
        reloaded.retainPins(for: [kept])
        #expect(ProjectBoardPreferences(defaults: defaults).pinnedProjectIDs == [kept])
        reloaded.togglePin(for: kept)
        #expect(ProjectBoardPreferences(defaults: defaults).pinnedProjectIDs.isEmpty)
    }

    @Test("Unknown preference values recover to safe defaults")
    func unknownPreferences() throws {
        let suite = "ProjectBarPreferencesTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Unknown", forKey: "board.cardDensity")
        defaults.set(["not-a-uuid"], forKey: "board.pinnedProjectIDs")
        let preferences = ProjectBoardPreferences(defaults: defaults)
        #expect(preferences.density == .compact)
        #expect(preferences.pinnedProjectIDs.isEmpty)
    }

    @Test("Arrow navigation respects row geometry and incomplete final rows", arguments: [1, 2, 3])
    func navigation(columns: Int) {
        let ids = (0..<8).map { _ in UUID() }
        let interaction = ProjectBoardInteraction()
        interaction.move(.down, in: ids, columns: columns)
        #expect(interaction.selectedProjectID == ids[0])
        interaction.move(.down, in: ids, columns: columns)
        #expect(interaction.selectedProjectID == ids[columns])
        interaction.move(.up, in: ids, columns: columns)
        #expect(interaction.selectedProjectID == ids[0])
        interaction.move(.left, in: ids, columns: columns)
        #expect(interaction.selectedProjectID == ids[0])
        interaction.selectedProjectID = ids[6]
        interaction.move(.down, in: ids, columns: columns)
        #expect(interaction.selectedProjectID == ids[columns == 1 ? 7 : 6])
        interaction.selectedProjectID = ids.last
        interaction.move(.right, in: ids, columns: columns)
        #expect(interaction.selectedProjectID == ids.last)
        interaction.move(.down, in: [], columns: columns)
        #expect(interaction.selectedProjectID == nil)
    }

    @Test("Removing a selected result picks its nearest remaining neighbor")
    func selectionAfterFiltering() {
        let ids = (0..<5).map { _ in UUID() }
        let interaction = ProjectBoardInteraction()
        interaction.selectedProjectID = ids[2]
        interaction.reconcileSelection(previous: ids, current: [ids[0], ids[1], ids[3], ids[4]])
        #expect(interaction.selectedProjectID == ids[3])
        interaction.reconcileSelection(previous: ids, current: [ids[0]])
        #expect(interaction.selectedProjectID == ids[0])
        interaction.reconcileSelection(previous: ids, current: [])
        #expect(interaction.selectedProjectID == nil)
        interaction.selectedProjectID = ids[2]
        interaction.reconcileSelection(previous: ids, current: [ids[0], ids[3], ids[4]])
        #expect(interaction.selectedProjectID == ids[3])
        interaction.selectedProjectID = ids[3]
        interaction.reconcileSelection(previous: ids, current: [ids[0], ids[2]])
        #expect(interaction.selectedProjectID == ids[2])
    }

    @Test("Adding reveals the first new project and clears filters only when something was added")
    func revealAddedProjects() {
        let first = UUID(), added = UUID(), secondAdded = UUID()
        let interaction = ProjectBoardInteraction()
        interaction.query = "old search"
        interaction.filter = .running
        #expect(interaction.revealAddedProjects(previous: [first], current: [first]) == nil)
        #expect(interaction.query == "old search")
        #expect(interaction.filter == .running)
        #expect(interaction.revealAddedProjects(previous: [first], current: [first, added, secondAdded]) == added)
        #expect(interaction.query.isEmpty)
        #expect(interaction.filter == .all)
        #expect(interaction.selectedProjectID == added)
        #expect(interaction.scrollAnchor == added)
    }

    @Test("Board shortcuts leave text editing and repeat activations alone")
    func keyboardCommands() {
        func command(_ code: UInt16, _ text: String = "", _ modifiers: NSEvent.ModifierFlags = [],
                     repeatKey: Bool = false, grid: Bool = false, editing: Bool = false) -> ProjectBoardCommand? {
            ProjectBoardCommand.resolve(keyCode: code, characters: text, modifiers: modifiers,
                                        isRepeat: repeatKey, gridFocused: grid, isEditingText: editing)
        }
        #expect(command(3, "f", .command, editing: true) == .search)
        for (text, filter) in zip(["1", "2", "3", "4"], ProjectBoardFilter.allCases) {
            #expect(command(18, text, .command) == .filter(filter))
        }
        #expect(command(36, "\r", .command, grid: true) == .activate)
        #expect(command(36, "\r", .command, repeatKey: true, grid: true) == nil)
        #expect(command(36, "\r", .command, grid: true, editing: true) == nil)
        #expect(command(36, "\r", .command) == nil)
        #expect(command(36, "\r", [], editing: true) == nil)
        #expect(command(123, grid: true) == .move(.left))
        #expect(command(126, repeatKey: true, grid: true) == .move(.up))
        #expect(command(123, editing: true) == nil)
        #expect(command(123, "", .command, grid: true) == nil)
        #expect(command(6, "z", .command, editing: true) == nil)
        #expect(command(48, "\t", [], grid: true) == nil)
        #expect(command(53) == .escape)
    }

    @Test("Folder actions report unavailable locations and keep paths copyable")
    func folderActions() {
        var revealed: [URL] = []
        var copied: [String] = []
        let actions = ProjectFolderActions(
            isReadableDirectory: { $0 == "/available/project" },
            reveal: { revealed.append($0) }, copy: { copied.append($0) })
        #expect(actions.revealFolder(at: "/available/project") == nil)
        #expect(revealed.map(\.path) == ["/available/project"])
        #expect(actions.revealFolder(at: "/offline/project")?.contains("Folder unavailable") == true)
        #expect(revealed.count == 1)
        actions.copy("/offline/project")
        #expect(copied == ["/offline/project"])
    }

    @Test("The AppKit bridge consumes one activation and yields to editors, menus, and other windows")
    func keyboardEventRouting() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let otherWindow = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        otherWindow.isReleasedWhenClosed = false
        let keyboard = ProjectBoardKeyboard.KeyboardView()
        window.contentView = keyboard
        defer { keyboard.stop(); window.close(); otherWindow.close() }
        keyboard.gridFocused = true
        var commands: [ProjectBoardCommand] = []
        keyboard.onCommand = { commands.append($0) }
        func event(_ code: UInt16 = 36, _ characters: String = "\r", _ modifiers: NSEvent.ModifierFlags = .command,
                   repeatKey: Bool = false, in target: NSWindow? = nil) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                         timestamp: 0, windowNumber: (target ?? window).windowNumber,
                                         context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                         isARepeat: repeatKey, keyCode: code))
        }
        #expect(keyboard.handle(try event()) == nil)
        #expect(commands == [.activate])
        #expect(keyboard.handle(try event(repeatKey: true)) == nil)
        #expect(commands == [.activate])
        #expect(keyboard.handle(try event(in: otherWindow)) != nil)
        keyboard.enabled = false // The board disables this while a sheet, alert, or file panel is open.
        #expect(keyboard.handle(try event(53, "", [])) != nil)
        keyboard.enabled = true
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: NSMenu())
        #expect(keyboard.handle(try event(53, "", [])) != nil)
        NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: NSMenu())
        #expect(keyboard.handle(try event(53, "", [])) == nil)
        #expect(commands == [.activate, .escape])

        let editor = NSTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        keyboard.addSubview(editor)
        #expect(window.makeFirstResponder(editor))
        #expect(keyboard.handle(try event(123, "", [])) != nil)
        #expect(keyboard.handle(try event()) != nil)
        #expect(keyboard.handle(try event(repeatKey: true)) != nil)
        #expect(keyboard.handle(try event(48, "\t", [])) != nil)
        #expect(keyboard.handle(try event(3, "f")) == nil)
        #expect(commands == [.activate, .escape, .search])
    }
}
