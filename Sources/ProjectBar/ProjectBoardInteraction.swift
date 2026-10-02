import Foundation
import Observation

enum ProjectGridDirection: Equatable {
    case left, right, up, down
}

@MainActor
@Observable
final class ProjectBoardInteraction {
    var query = ""
    var filter: ProjectBoardFilter = .all
    var selectedProjectID: UUID?
    var scrollAnchor: UUID?
    var completionNotice: CompletionNotice?
    var folderMessage: String?

    struct CompletionNotice {
        let projectID: UUID
        let runID: UUID
        let projectName: String
    }

    func move(_ direction: ProjectGridDirection, in ids: [UUID], columns: Int) {
        guard !ids.isEmpty else { self.selectedProjectID = nil; return }
        guard let selected = self.selectedProjectID, let index = ids.firstIndex(of: selected) else {
            self.selectedProjectID = ids.first
            return
        }
        let columns = max(1, columns)
        let destination: Int
        switch direction {
        case .left: destination = max(0, index - 1)
        case .right: destination = min(ids.count - 1, index + 1)
        case .up: destination = index >= columns ? index - columns : index
        case .down:
            destination = index / columns < (ids.count - 1) / columns ? min(ids.count - 1, index + columns) : index
        }
        self.selectedProjectID = ids[destination]
    }

    func reconcileSelection(previous: [UUID], current: [UUID]) {
        guard let selected = self.selectedProjectID, !current.contains(selected) else { return }
        let index = previous.firstIndex(of: selected) ?? 0
        let remaining = Set(current)
        let nearest = previous.enumerated().filter { remaining.contains($0.element) }.min { lhs, rhs in
            let leftDistance = abs(lhs.offset - index), rightDistance = abs(rhs.offset - index)
            // Prefer the following card when both neighbors are equally close.
            return leftDistance == rightDistance ? lhs.offset > rhs.offset : leftDistance < rightDistance
        }
        self.selectedProjectID = nearest?.element ?? current.first
    }

    @discardableResult
    func revealAddedProjects(previous: Set<UUID>, current: [UUID]) -> UUID? {
        guard let added = current.first(where: { !previous.contains($0) }) else { return nil }
        self.query = ""
        self.filter = .all
        self.selectedProjectID = added
        self.scrollAnchor = added
        return added
    }
}
