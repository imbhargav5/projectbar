import Foundation

public extension CadencePeriod {
    func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        let component: Calendar.Component = switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        }
        if let interval = calendar.dateInterval(of: component, for: date) {
            return interval
        }

        let start = calendar.startOfDay(for: date)
        let dayCount = self == .daily ? 1 : 7
        let end = calendar.date(byAdding: .day, value: dayCount, to: start)
            ?? start.addingTimeInterval(Double(dayCount) * 24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }
}

public struct WorkdaySchedule: Equatable, Sendable {
    public let startHour: Int
    public let endHour: Int

    public init(startHour: Int = 10, endHour: Int = 20) {
        precondition((0...23).contains(startHour))
        precondition((1...24).contains(endHour))
        precondition(startHour < endHour)
        self.startHour = startHour
        self.endHour = endHour
    }

    public func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .hour, value: self.startHour, to: startOfDay) ?? startOfDay
        let end = calendar.date(byAdding: .hour, value: self.endHour, to: startOfDay) ?? start
        return DateInterval(start: start, end: end)
    }

    public func scheduledDate(
        forRunNumber runNumber: Int,
        target: Int,
        period: CadencePeriod = .daily,
        on date: Date,
        calendar: Calendar)
        -> Date?
    {
        guard target > 0, (1...target).contains(runNumber) else { return nil }
        let workIntervals = self.intervals(for: period, containing: date, calendar: calendar)
        let totalDuration = workIntervals.reduce(0) { $0 + $1.duration }
        guard totalDuration > 0 else { return nil }

        var offset = totalDuration * (Double(runNumber) - 0.5) / Double(target)
        for interval in workIntervals {
            if offset < interval.duration {
                return interval.start.addingTimeInterval(offset)
            }
            offset -= interval.duration
        }
        return workIntervals.last?.end
    }

    public func expectedRunCount(
        at date: Date,
        target: Int,
        period: CadencePeriod = .daily,
        calendar: Calendar)
        -> Int
    {
        guard target > 0 else { return 0 }
        let progress = self.progress(at: date, period: period, calendar: calendar)
        return min(target, max(0, Int(floor(progress * Double(target) + 0.5))))
    }

    public func progress(
        at date: Date,
        period: CadencePeriod = .daily,
        calendar: Calendar)
        -> Double
    {
        let workIntervals = self.intervals(for: period, containing: date, calendar: calendar)
        let totalDuration = workIntervals.reduce(0) { $0 + $1.duration }
        guard totalDuration > 0 else { return 0 }

        let elapsed = workIntervals.reduce(0.0) { partialResult, interval in
            if date <= interval.start {
                return partialResult
            }
            if date >= interval.end {
                return partialResult + interval.duration
            }
            return partialResult + date.timeIntervalSince(interval.start)
        }
        return min(1, max(0, elapsed / totalDuration))
    }

    public func intervals(
        for period: CadencePeriod,
        containing date: Date,
        calendar: Calendar)
        -> [DateInterval]
    {
        let cadenceInterval = period.interval(containing: date, calendar: calendar)
        var intervals: [DateInterval] = []
        var day = calendar.startOfDay(for: cadenceInterval.start)

        while day < cadenceInterval.end {
            intervals.append(self.interval(containing: day, calendar: calendar))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day), nextDay > day else {
                break
            }
            day = nextDay
        }
        return intervals
    }
}

public enum WorkdayPhase: Equatable, Sendable {
    case beforeWork
    case working
    case afterWork
}

public struct CadenceSnapshot: Equatable, Sendable {
    public let period: CadencePeriod
    public let target: Int
    public let completed: Int
    public let expected: Int
    public let behind: Int
    public let phase: WorkdayPhase
    public let nextDueDate: Date?
    public let periodProgress: Double

    public var isComplete: Bool {
        self.completed >= self.target
    }

    public var completionProgress: Double {
        guard self.target > 0 else { return 1 }
        return min(1, Double(self.completed) / Double(self.target))
    }

    public var expectedProgress: Double {
        guard self.target > 0 else { return 1 }
        return min(1, Double(self.expected) / Double(self.target))
    }
}

public enum ProjectCadence {
    public static func snapshot(
        for project: ProjectRecord,
        at date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        schedule: WorkdaySchedule = WorkdaySchedule())
        -> CadenceSnapshot
    {
        let period = project.cadencePeriod
        let target = max(1, project.runTarget)
        let completed = project.completedRunCount(in: period, containing: date, calendar: calendar)
        let expected = schedule.expectedRunCount(
            at: date,
            target: target,
            period: period,
            calendar: calendar)
        let workday = schedule.interval(containing: date, calendar: calendar)
        let phase: WorkdayPhase

        if date < workday.start {
            phase = .beforeWork
        } else if date >= workday.end {
            phase = .afterWork
        } else {
            phase = .working
        }

        let nextRunNumber = min(completed + 1, target)
        let nextDueDate = completed >= target
            ? nil
            : schedule.scheduledDate(
                forRunNumber: nextRunNumber,
                target: target,
                period: period,
                on: date,
                calendar: calendar)

        return CadenceSnapshot(
            period: period,
            target: target,
            completed: completed,
            expected: expected,
            behind: max(0, expected - completed),
            phase: phase,
            nextDueDate: nextDueDate,
            periodProgress: schedule.progress(at: date, period: period, calendar: calendar))
    }
}
