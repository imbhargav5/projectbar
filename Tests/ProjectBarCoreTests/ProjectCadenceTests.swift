import Foundation
import ProjectBarCore
import Testing

struct ProjectCadenceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }()

    @Test("Cadence is quiet before work and complete after work")
    func workdayBoundaries() {
        let schedule = WorkdaySchedule()

        #expect(schedule.expectedRunCount(
            at: self.date(hour: 9, minute: 59),
            target: 10,
            calendar: self.calendar) == 0)
        #expect(schedule.expectedRunCount(
            at: self.date(hour: 20),
            target: 10,
            calendar: self.calendar) == 10)
        #expect(schedule.expectedRunCount(
            at: self.date(hour: 23, minute: 59),
            target: 10,
            calendar: self.calendar) == 10)
    }

    @Test("Ten runs are centered at one-hour checkpoints")
    func tenRunCadence() {
        let schedule = WorkdaySchedule()

        #expect(schedule.expectedRunCount(
            at: self.date(hour: 10, minute: 29, second: 59),
            target: 10,
            calendar: self.calendar) == 0)
        #expect(schedule.expectedRunCount(
            at: self.date(hour: 10, minute: 30),
            target: 10,
            calendar: self.calendar) == 1)
        #expect(schedule.expectedRunCount(
            at: self.date(hour: 15),
            target: 10,
            calendar: self.calendar) == 5)
        #expect(schedule.scheduledDate(
            forRunNumber: 6,
            target: 10,
            on: self.date(hour: 12),
            calendar: self.calendar) == self.date(hour: 15, minute: 30))
    }

    @Test("One hundred runs produce six-minute slots")
    func hundredRunCadence() {
        let schedule = WorkdaySchedule()

        #expect(schedule.scheduledDate(
            forRunNumber: 1,
            target: 100,
            on: self.date(hour: 8),
            calendar: self.calendar) == self.date(hour: 10, minute: 3))
        #expect(schedule.scheduledDate(
            forRunNumber: 2,
            target: 100,
            on: self.date(hour: 8),
            calendar: self.calendar) == self.date(hour: 10, minute: 9))
        #expect(schedule.expectedRunCount(
            at: self.date(hour: 10, minute: 3),
            target: 100,
            calendar: self.calendar) == 1)
    }

    @Test("Snapshot reports overdue work and the next unmet checkpoint")
    func overdueSnapshot() {
        let now = self.date(hour: 15)
        let project = ProjectRecord(
            name: "ProjectBar",
            dailyRunTarget: 10,
            completedRuns: [
                self.run(completedAt: self.date(hour: 10, minute: 5)),
                self.run(completedAt: self.date(hour: 11)),
                self.run(completedAt: self.date(hour: 12)),
            ])

        let snapshot = ProjectCadence.snapshot(for: project, at: now, calendar: self.calendar)

        #expect(snapshot.completed == 3)
        #expect(snapshot.expected == 5)
        #expect(snapshot.behind == 2)
        #expect(snapshot.phase == .working)
        #expect(snapshot.nextDueDate == self.date(hour: 13, minute: 30))
    }

    @Test("Completed runs reset on the local calendar day")
    func localMidnightReset() {
        let completedAt = self.date(day: 16, hour: 23, minute: 59)
        let project = ProjectRecord(
            name: "ProjectBar",
            dailyRunTarget: 10,
            completedRuns: [self.run(completedAt: completedAt)])

        #expect(project.completedRunCount(
            on: self.date(day: 16, hour: 23, minute: 59),
            calendar: self.calendar) == 1)
        #expect(project.completedRunCount(
            on: self.date(day: 17, hour: 0),
            calendar: self.calendar) == 0)
        #expect(project.mostRecentCompletedRun?.completedAt == completedAt)
    }

    @Test("A single daily run is due at the workday midpoint")
    func singleRunCadence() {
        let schedule = WorkdaySchedule()

        #expect(schedule.expectedRunCount(
            at: self.date(hour: 14, minute: 59),
            target: 1,
            calendar: self.calendar) == 0)
        #expect(schedule.expectedRunCount(
            at: self.date(hour: 15),
            target: 1,
            calendar: self.calendar) == 1)
    }

    private func date(
        day: Int = 16,
        hour: Int,
        minute: Int = 0,
        second: Int = 0)
        -> Date
    {
        self.calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute,
            second: second))!
    }

    private func run(completedAt: Date) -> CompletedAgentRun {
        CompletedAgentRun(startedAt: completedAt.addingTimeInterval(-60), completedAt: completedAt)
    }
}
