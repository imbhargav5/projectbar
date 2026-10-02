import Foundation
import ProjectBarCore
import Testing

struct ProjectCadenceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
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

    @Test("Weekly checkpoints span seven local workday windows")
    func weeklyCadence() {
        let schedule = WorkdaySchedule()

        #expect(schedule.scheduledDate(
            forRunNumber: 1,
            target: 7,
            period: .weekly,
            on: self.date(day: 17, hour: 8),
            calendar: self.calendar) == self.date(day: 17, hour: 15))
        #expect(schedule.scheduledDate(
            forRunNumber: 4,
            target: 7,
            period: .weekly,
            on: self.date(day: 17, hour: 8),
            calendar: self.calendar) == self.date(day: 20, hour: 15))
        #expect(schedule.expectedRunCount(
            at: self.date(day: 19, hour: 14, minute: 59),
            target: 7,
            period: .weekly,
            calendar: self.calendar) == 2)
        #expect(schedule.expectedRunCount(
            at: self.date(day: 19, hour: 15),
            target: 7,
            period: .weekly,
            calendar: self.calendar) == 3)
    }

    @Test("Weekly progress pauses overnight and completions reset next week")
    func weeklyBoundaries() {
        let mondayCompletion = self.date(day: 17, hour: 16)
        let project = ProjectRecord(
            name: "Weekly Project",
            dailyRunTarget: 7,
            cadencePeriod: .weekly,
            completedRuns: [self.run(completedAt: mondayCompletion)])
        let schedule = WorkdaySchedule()

        #expect(schedule.expectedRunCount(
            at: self.date(day: 17, hour: 20),
            target: 7,
            period: .weekly,
            calendar: self.calendar) == 1)
        #expect(schedule.expectedRunCount(
            at: self.date(day: 18, hour: 9),
            target: 7,
            period: .weekly,
            calendar: self.calendar) == 1)
        #expect(project.completedRunCount(
            in: .weekly,
            containing: self.date(day: 18, hour: 9),
            calendar: self.calendar) == 1)
        #expect(project.completedRunCount(
            in: .weekly,
            containing: self.date(day: 24, hour: 0),
            calendar: self.calendar) == 0)
    }

    @Test("Saved projects without a cadence period remain daily")
    func legacyProjectDecoding() throws {
        let json = """
        {
          "id": "67E55044-10B1-426F-9247-BB680E5FE0C8",
          "name": "Legacy Project",
          "dailyRunTarget": 10,
          "createdAt": "2026-08-17T04:30:00Z",
          "completedRuns": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let project = try decoder.decode(ProjectRecord.self, from: Data(json.utf8))

        #expect(project.cadencePeriod == .daily)
        #expect(project.runTarget == 10)
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
