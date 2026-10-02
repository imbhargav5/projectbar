import AppKit
import SwiftUI

enum ProjectBoardCommand: Equatable {
    case search
    case filter(ProjectBoardFilter)
    case escape
    case activate
    case move(ProjectGridDirection)

    static func resolve(
        keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags,
        isRepeat: Bool, gridFocused: Bool, isEditingText: Bool) -> Self?
    {
        let modifiers = modifiers.intersection([.command, .control, .option, .shift])
        if modifiers == .command {
            switch characters.lowercased() {
            case "f": return isRepeat ? nil : .search
            case "1": return isRepeat ? nil : .filter(.all)
            case "2": return isRepeat ? nil : .filter(.behind)
            case "3": return isRepeat ? nil : .filter(.running)
            case "4": return isRepeat ? nil : .filter(.complete)
            default:
                if (keyCode == 36 || keyCode == 76), gridFocused, !isEditingText, !isRepeat { return .activate }
            }
        }
        guard modifiers.isEmpty else { return nil }
        if keyCode == 53, !isRepeat { return .escape }
        guard gridFocused, !isEditingText else { return nil }
        switch keyCode {
        case 123: return .move(.left)
        case 124: return .move(.right)
        case 125: return .move(.down)
        case 126: return .move(.up)
        default: return nil
        }
    }
}

/// App-local shortcuts, scoped to this popover's window. Native controls retain all other events.
struct ProjectBoardKeyboard: NSViewRepresentable {
    let enabled: Bool
    let gridFocused: Bool
    let onCommand: (ProjectBoardCommand) -> Void

    func makeNSView(context: Context) -> KeyboardView { KeyboardView() }

    func updateNSView(_ view: KeyboardView, context: Context) {
        view.enabled = self.enabled
        view.gridFocused = self.gridFocused
        view.onCommand = self.onCommand
    }

    static func dismantleNSView(_ view: KeyboardView, coordinator: ()) { view.stop() }

    @MainActor
    final class KeyboardView: NSView {
        var enabled = true
        var gridFocused = false
        var onCommand: ((ProjectBoardCommand) -> Void)?
        private var monitor: Any?
        private var observers: [NSObjectProtocol] = []
        private var menuTrackingDepth = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.stop()
            guard self.window != nil else { return }
            self.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handle(event)
            }
            for (name, delta) in [(NSMenu.didBeginTrackingNotification, 1), (NSMenu.didEndTrackingNotification, -1)] {
                self.observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.menuTrackingDepth = max(0, self.menuTrackingDepth + delta)
                    }
                })
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            self.monitor = nil
            for observer in self.observers { NotificationCenter.default.removeObserver(observer) }
            self.observers = []
            self.menuTrackingDepth = 0
        }

        func handle(_ event: NSEvent) -> NSEvent? {
            guard self.enabled, self.menuTrackingDepth == 0,
                  let window = self.window, event.window === window,
                  window.attachedSheet == nil, NSApp.modalWindow == nil else { return event }
            let editor = window.firstResponder as? NSTextView
            guard editor?.hasMarkedText() != true else { return event }
            // Never deliver repeat activations to a newly morphed button or the responder chain.
            if event.isARepeat, self.gridFocused, editor == nil,
               event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
               [36, 76].contains(event.keyCode) { return nil }
            guard let command = ProjectBoardCommand.resolve(
                keyCode: event.keyCode, characters: event.charactersIgnoringModifiers ?? "",
                modifiers: event.modifierFlags, isRepeat: event.isARepeat,
                gridFocused: self.gridFocused, isEditingText: editor != nil) else { return event }
            self.onCommand?(command)
            return nil
        }
    }
}
