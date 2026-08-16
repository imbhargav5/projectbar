import Foundation

public struct ActiveAgentRun: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date

    public init(id: UUID = UUID(), startedAt: Date) {
        self.id = id
        self.startedAt = startedAt
    }
}

public struct CompletedAgentRun: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date

    public init(id: UUID = UUID(), startedAt: Date, completedAt: Date) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

public struct ProjectRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var folderPath: String?
    public var dailyRunTarget: Int
    public let createdAt: Date
    public var completedRuns: [CompletedAgentRun]
    public var activeRun: ActiveAgentRun?

    public init(
        id: UUID = UUID(),
        name: String,
        folderPath: String? = nil,
        dailyRunTarget: Int = 10,
        createdAt: Date = Date(),
        completedRuns: [CompletedAgentRun] = [],
        activeRun: ActiveAgentRun? = nil)
    {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.dailyRunTarget = dailyRunTarget
        self.createdAt = createdAt
        self.completedRuns = completedRuns
        self.activeRun = activeRun
    }

    public func completedRuns(on date: Date, calendar: Calendar) -> [CompletedAgentRun] {
        self.completedRuns.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
    }

    public func completedRunCount(on date: Date, calendar: Calendar) -> Int {
        self.completedRuns(on: date, calendar: calendar).count
    }

    public func lastCompletedRun(on date: Date, calendar: Calendar) -> CompletedAgentRun? {
        self.completedRuns(on: date, calendar: calendar).max { $0.completedAt < $1.completedAt }
    }

    public var mostRecentCompletedRun: CompletedAgentRun? {
        self.completedRuns.max { $0.completedAt < $1.completedAt }
    }
}

public struct ProjectBarState: Codable, Equatable, Sendable {
    public var version: Int
    public var projects: [ProjectRecord]

    public init(version: Int = 1, projects: [ProjectRecord] = []) {
        self.version = version
        self.projects = projects
    }
}
