import Foundation

public enum CadencePeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        }
    }

    public var shortLabel: String {
        switch self {
        case .daily: "day"
        case .weekly: "wk"
        }
    }
}

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
    public var cadencePeriod: CadencePeriod
    public let createdAt: Date
    public var completedRuns: [CompletedAgentRun]
    public var activeRun: ActiveAgentRun?

    public init(
        id: UUID = UUID(),
        name: String,
        folderPath: String? = nil,
        dailyRunTarget: Int = 10,
        cadencePeriod: CadencePeriod = .daily,
        createdAt: Date = Date(),
        completedRuns: [CompletedAgentRun] = [],
        activeRun: ActiveAgentRun? = nil)
    {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.dailyRunTarget = dailyRunTarget
        self.cadencePeriod = cadencePeriod
        self.createdAt = createdAt
        self.completedRuns = completedRuns
        self.activeRun = activeRun
    }

    public var runTarget: Int {
        get { self.dailyRunTarget }
        set { self.dailyRunTarget = newValue }
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

    public func completedRuns(
        in period: CadencePeriod,
        containing date: Date,
        calendar: Calendar)
        -> [CompletedAgentRun]
    {
        let interval = period.interval(containing: date, calendar: calendar)
        return self.completedRuns.filter {
            $0.completedAt >= interval.start && $0.completedAt < interval.end
        }
    }

    public func completedRunCount(
        in period: CadencePeriod,
        containing date: Date,
        calendar: Calendar)
        -> Int
    {
        self.completedRuns(in: period, containing: date, calendar: calendar).count
    }

    public func lastCompletedRun(
        in period: CadencePeriod,
        containing date: Date,
        calendar: Calendar)
        -> CompletedAgentRun?
    {
        self.completedRuns(in: period, containing: date, calendar: calendar)
            .max { $0.completedAt < $1.completedAt }
    }

    public var mostRecentCompletedRun: CompletedAgentRun? {
        self.completedRuns.max { $0.completedAt < $1.completedAt }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case folderPath
        case dailyRunTarget
        case cadencePeriod
        case createdAt
        case completedRuns
        case activeRun
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath)
        self.dailyRunTarget = try container.decode(Int.self, forKey: .dailyRunTarget)
        self.cadencePeriod = try container.decodeIfPresent(CadencePeriod.self, forKey: .cadencePeriod) ?? .daily
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.completedRuns = try container.decode([CompletedAgentRun].self, forKey: .completedRuns)
        self.activeRun = try container.decodeIfPresent(ActiveAgentRun.self, forKey: .activeRun)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfPresent(self.folderPath, forKey: .folderPath)
        try container.encode(self.dailyRunTarget, forKey: .dailyRunTarget)
        try container.encode(self.cadencePeriod, forKey: .cadencePeriod)
        try container.encode(self.createdAt, forKey: .createdAt)
        try container.encode(self.completedRuns, forKey: .completedRuns)
        try container.encodeIfPresent(self.activeRun, forKey: .activeRun)
    }
}

public struct ProjectBarState: Codable, Equatable, Sendable {
    public var version: Int
    public var projects: [ProjectRecord]

    public init(version: Int = 2, projects: [ProjectRecord] = []) {
        self.version = version
        self.projects = projects
    }
}
