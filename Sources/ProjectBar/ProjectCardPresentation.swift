import Foundation
import ProjectBarCore

struct ProjectCardPresentation: Equatable {
    enum VisualState: Equatable {
        case normal
        case overdue
        case active
        case complete
    }

    let visualState: VisualState
    let statusText: String
    let statusSymbol: String
    let actionTitle: String
    let actionSymbol: String
    let isActionProminent: Bool

    static func make(
        project: ProjectRecord,
        cadence: CadenceSnapshot,
        relativeDescription: (Date) -> String,
        elapsedDescription: (Date) -> String,
        timeDescription: (Date) -> String)
        -> ProjectCardPresentation
    {
        let lastRun = project.mostRecentCompletedRun

        if let activeRun = project.activeRun {
            let stillDue = max(0, cadence.behind - 1)
            let backlog = stillDue > 0
                ? " · \(stillDue) still due"
                : ""
            return ProjectCardPresentation(
                visualState: .active,
                statusText: "Running \(elapsedDescription(activeRun.startedAt))\(backlog)",
                statusSymbol: "bolt.horizontal.circle.fill",
                actionTitle: "Confirm complete",
                actionSymbol: "checkmark",
                isActionProminent: true)
        }

        if cadence.isComplete {
            return ProjectCardPresentation(
                visualState: .complete,
                statusText: Self.join(
                    "Complete",
                    lastRun.map { "Last \(relativeDescription($0.completedAt))" }) ?? "Complete",
                statusSymbol: "checkmark.circle.fill",
                actionTitle: "Start another",
                actionSymbol: "bolt.fill",
                isActionProminent: false)
        }

        if cadence.behind > 0 {
            let dueText = cadence.phase == .afterWork
                ? "\(cadence.behind) short today"
                : "\(cadence.behind) due now"
            return ProjectCardPresentation(
                visualState: .overdue,
                statusText: Self.join(
                    dueText,
                    lastRun.map { "Last \(relativeDescription($0.completedAt))" }) ?? dueText,
                statusSymbol: "exclamationmark.circle.fill",
                actionTitle: "Start due agent",
                actionSymbol: "bolt.fill",
                isActionProminent: true)
        }

        if cadence.phase == .beforeWork, let nextDueDate = cadence.nextDueDate {
            let scheduleText = cadence.completed == 0
                ? "Starts at \(timeDescription(nextDueDate))"
                : "Next at \(timeDescription(nextDueDate))"
            return ProjectCardPresentation(
                visualState: .normal,
                statusText: Self.join(
                    scheduleText,
                    lastRun.map { "Last \(relativeDescription($0.completedAt))" }) ?? scheduleText,
                statusSymbol: "clock",
                actionTitle: "Start agent",
                actionSymbol: "bolt.fill",
                isActionProminent: false)
        }

        let lastText = lastRun.map { "Last \(relativeDescription($0.completedAt))" }
        let nextText = cadence.nextDueDate.map { "Next \(relativeDescription($0))" }
        return ProjectCardPresentation(
            visualState: .normal,
            statusText: Self.join(lastText, nextText) ?? "On cadence",
            statusSymbol: "clock",
            actionTitle: "Start agent",
            actionSymbol: "bolt.fill",
            isActionProminent: false)
    }

    private static func join(_ first: String?, _ second: String?) -> String? {
        [first, second]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}
