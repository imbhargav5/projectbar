import Foundation

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
        on date: Date,
        calendar: Calendar)
        -> Date?
    {
        guard target > 0, (1...target).contains(runNumber) else { return nil }
        let workday = self.interval(containing: date, calendar: calendar)
        let checkpoint = (Double(runNumber) - 0.5) / Double(target)
        return workday.start.addingTimeInterval(workday.duration * checkpoint)
    }

    public func expectedRunCount(at date: Date, target: Int, calendar: Calendar) -> Int {
        guard target > 0 else { return 0 }
        let workday = self.interval(containing: date, calendar: calendar)
        if date < workday.start {
            return 0
        }
        if date >= workday.end {
            return target
        }

        let elapsed = date.timeIntervalSince(workday.start)
        let progress = elapsed / workday.duration
        return min(target, max(0, Int(floor(progress * Double(target) + 0.5))))
    }
}

public enum WorkdayPhase: Equatable, Sendable {
    case beforeWork
    case working
    case afterWork
}

public struct CadenceSnapshot: Equatable, Sendable {
    public let target: Int
    public let completed: Int
    public let expected: Int
    public let behind: Int
    public let phase: WorkdayPhase
    public let nextDueDate: Date?
    public let workdayProgress: Double

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
        let target = max(1, project.dailyRunTarget)
        let completed = project.completedRunCount(on: date, calendar: calendar)
        let expected = schedule.expectedRunCount(at: date, target: target, calendar: calendar)
        let workday = schedule.interval(containing: date, calendar: calendar)
        let phase: WorkdayPhase
        let progress: Double

        if date < workday.start {
            phase = .beforeWork
            progress = 0
        } else if date >= workday.end {
            phase = .afterWork
            progress = 1
        } else {
            phase = .working
            progress = min(1, max(0, date.timeIntervalSince(workday.start) / workday.duration))
        }

        let nextRunNumber = min(completed + 1, target)
        let nextDueDate = completed >= target
            ? nil
            : schedule.scheduledDate(
                forRunNumber: nextRunNumber,
                target: target,
                on: date,
                calendar: calendar)

        return CadenceSnapshot(
            target: target,
            completed: completed,
            expected: expected,
            behind: max(0, expected - completed),
            phase: phase,
            nextDueDate: nextDueDate,
            workdayProgress: progress)
    }
}
