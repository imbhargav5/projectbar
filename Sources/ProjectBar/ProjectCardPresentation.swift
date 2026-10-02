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
    let timingText: String
    let progressText: String
    let expectedText: String

    var actionTitle: String { self.visualState == .active ? "Mark complete" : "Mark started" }
    var actionSymbol: String { self.visualState == .active ? "checkmark" : "play" }
    var isActionProminent: Bool { self.visualState == .active }

    static func make(
        project: ProjectRecord,
        cadence: CadenceSnapshot,
        relativeDescription: (Date) -> String,
        elapsedDescription: (Date) -> String,
        timeDescription: (Date) -> String)
        -> ProjectCardPresentation
    {
        let lastText = project.mostRecentCompletedRun.map { "Last \(relativeDescription($0.completedAt))" }
        let progressText = "\(cadence.completed)/\(cadence.target) \(cadence.period == .daily ? "today" : "this week")"
        let expectedText = "\(cadence.expected) expected by now"
        let state: VisualState
        let status: String
        let symbol: String
        let timing: String

        if let activeRun = project.activeRun {
            state = .active
            status = "Running · \(elapsedDescription(activeRun.startedAt))"
            symbol = "bolt.horizontal.circle"
            timing = cadence.behind > 0
                ? "\(cadence.behind) behind pace · 1 in progress"
                : lastText ?? "Manually tracked run"
        } else if cadence.isComplete {
            state = .complete
            status = "Target complete"
            symbol = "checkmark.circle"
            timing = lastText ?? "You’ve reached your target"
        } else if cadence.behind > 0 {
            state = .overdue
            if cadence.period == .daily, cadence.phase == .afterWork {
                status = "\(cadence.behind) short today"
            } else if cadence.period == .weekly, cadence.periodProgress >= 1 {
                status = "\(cadence.behind) short this week"
            } else {
                status = "\(cadence.behind) behind pace"
            }
            symbol = "clock.badge.exclamationmark"
            timing = lastText ?? "No completed runs yet"
        } else {
            state = .normal
            status = cadence.phase == .beforeWork ? "Scheduled" : "On pace"
            symbol = "clock"
            let nextText = cadence.nextDueDate.map {
                cadence.phase == .beforeWork
                    ? "Next at \(timeDescription($0))"
                    : "Next \(relativeDescription($0))"
            }
            timing = [nextText, lastText].compactMap { $0 }.joined(separator: " · ")
        }

        return ProjectCardPresentation(
            visualState: state,
            statusText: status,
            statusSymbol: symbol,
            timingText: timing,
            progressText: progressText,
            expectedText: expectedText)
    }
}
