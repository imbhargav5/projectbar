import AppKit
import Foundation

@MainActor
struct ProjectFolderActions {
    var isReadableDirectory: (String) -> Bool = { path in
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) &&
            isDirectory.boolValue && FileManager.default.isReadableFile(atPath: path)
    }
    var reveal: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    var copy: (String) -> Void = { path in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    /// Returns a user-facing failure without changing the saved path.
    func revealFolder(at path: String) -> String? {
        guard self.isReadableDirectory(path) else {
            return "Folder unavailable: \(path). Check that the folder or drive is accessible."
        }
        self.reveal(URL(fileURLWithPath: path, isDirectory: true))
        return nil
    }
}
