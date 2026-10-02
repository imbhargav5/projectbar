import Foundation
import ProjectBarCore

enum ProjectBoardFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case behind = "Behind"
    case running = "Running"
    case complete = "Complete"

    var id: Self { self }

    func includes(_ project: ProjectRecord, cadence: CadenceSnapshot) -> Bool {
        switch self {
        case .all: true
        case .behind: cadence.behind > 0
        case .running: project.activeRun != nil
        case .complete: cadence.isComplete
        }
    }
}

struct ProjectPeriodSummary: Identifiable, Equatable {
    let period: CadencePeriod
    let projectCount: Int
    let completed: Int
    let target: Int

    var id: CadencePeriod { self.period }
    var intervalLabel: String { self.period == .daily ? "today" : "this week" }
}

struct ProjectBoardPresentation {
    private struct Entry {
        let project: ProjectRecord
        let cadence: CadenceSnapshot
    }

    private let entries: [Entry]
    let summaries: [ProjectPeriodSummary]
    let runsBehind: Int
    let runningCount: Int

    init(projects: [ProjectRecord], now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let entries = projects.map {
            Entry(project: $0, cadence: ProjectCadence.snapshot(for: $0, at: now, calendar: calendar))
        }
        self.entries = entries
        self.runsBehind = entries.reduce(0) { $0 + $1.cadence.behind }
        self.runningCount = projects.count { $0.activeRun != nil }
        self.summaries = CadencePeriod.allCases.compactMap { period in
            let matching = entries.filter { $0.project.cadencePeriod == period }
            guard !matching.isEmpty else { return nil }
            return ProjectPeriodSummary(
                period: period,
                projectCount: matching.count,
                completed: matching.reduce(0) { $0 + $1.cadence.completed },
                target: matching.reduce(0) { $0 + $1.cadence.target })
        }
    }

    func projects(
        matching query: String = "", filter: ProjectBoardFilter = .all, pinnedIDs: Set<UUID> = []) -> [ProjectRecord]
    {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = self.entries.filter {
            (query.isEmpty || $0.project.name.localizedStandardContains(query)) &&
                filter.includes($0.project, cadence: $0.cadence)
        }.map(\.project)
        return matching.filter { pinnedIDs.contains($0.id) } + matching.filter { !pinnedIDs.contains($0.id) }
    }

    var statusItemTitle: String {
        guard !self.entries.isEmpty else { return "" }
        var parts: [String] = []
        if self.runsBehind > 0 { parts.append("\(self.runsBehind) behind pace") }
        if self.runningCount > 0 { parts.append("\(self.runningCount) running") }
        if !parts.isEmpty { return parts.joined(separator: " · ") }
        return self.summaries.map {
            "\($0.completed)/\($0.target) \($0.intervalLabel)"
        }.joined(separator: " · ")
    }
}

enum ProjectBoardLayout {
    static func columnCount(for width: CGFloat) -> Int {
        min(3, max(1, Int((width - 32 + 12) / (240 + 12))))
    }

    static func popoverSize(available: CGSize, isEmpty: Bool) -> CGSize {
        CGSize(
            width: min(812, max(1, available.width - 24)),
            height: min(isEmpty ? 440 : 720, max(1, available.height - 32)))
    }
}

enum ProjectTargetInput {
    static let range = 1...200

    static func value(from text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              self.range.contains(value)
        else { return nil }
        return value
    }
}
