import Foundation
@testable import ProjectBar
import ProjectBarCore
import Testing

struct ProjectCardPresentationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    @Test("On-pace cards separate status, timing, and progress")
    func onCadencePresentation() {
        let now = self.date(hour: 11)
        let project = ProjectRecord(
            name: "ProjectBar",
            dailyRunTarget: 10,
            completedRuns: [self.run(completedAt: self.date(hour: 10, minute: 40))])
        let presentation = self.presentation(
            project: project,
            now: now,
            relativeDescription: { date in date < now ? "18m ago" : "in 42m" })

        #expect(presentation.visualState == .normal)
        #expect(presentation.statusText == "On pace")
        #expect(presentation.timingText == "Next in 42m · Last 18m ago")
        #expect(presentation.progressText == "1/10 today")
        #expect(presentation.expectedText == "1 expected by now")
        #expect(presentation.actionTitle == "Mark started")
        #expect(presentation.isActionProminent == false)
    }

    @Test("Behind cards keep last-run timing separate")
    func overduePresentation() {
        let now = self.date(hour: 13)
        let project = ProjectRecord(
            name: "ProjectBar",
            dailyRunTarget: 10,
            completedRuns: [self.run(completedAt: self.date(day: 15, hour: 17))])
        let presentation = self.presentation(
            project: project,
            now: now,
            relativeDescription: { _ in "yesterday" })

        #expect(presentation.visualState == .overdue)
        #expect(presentation.statusText == "3 behind pace")
        #expect(presentation.timingText == "Last yesterday")
        #expect(presentation.actionTitle == "Mark started")
        #expect(presentation.isActionProminent == false)
    }

    @Test("Running cards distinguish the completion deficit from work in progress")
    func activePresentation() {
        let now = self.date(hour: 13)
        let project = ProjectRecord(
            name: "ProjectBar",
            dailyRunTarget: 10,
            activeRun: ActiveAgentRun(startedAt: self.date(hour: 12, minute: 57)))
        let presentation = self.presentation(
            project: project,
            now: now,
            elapsedDescription: { _ in "3m" })

        #expect(presentation.visualState == .active)
        #expect(presentation.statusText == "Running · 3m")
        #expect(presentation.timingText == "3 behind pace · 1 in progress")
        #expect(presentation.actionTitle == "Mark complete")
        #expect(presentation.isActionProminent == true)
    }

    @Test("Complete cards retain a secondary manual-start action")
    func completePresentation() {
        let now = self.date(hour: 16)
        let project = ProjectRecord(
            name: "ProjectBar",
            dailyRunTarget: 1,
            completedRuns: [self.run(completedAt: self.date(hour: 15, minute: 56))])
        let presentation = self.presentation(
            project: project,
            now: now,
            relativeDescription: { _ in "4m ago" })

        #expect(presentation.visualState == .complete)
        #expect(presentation.statusText == "Target complete")
        #expect(presentation.timingText == "Last 4m ago")
        #expect(presentation.actionTitle == "Mark started")
        #expect(presentation.isActionProminent == false)
    }

    @Test("Before-work cards show the first checkpoint and prior run")
    func beforeWorkPresentation() {
        let now = self.date(hour: 9)
        let project = ProjectRecord(
            name: "ProjectBar",
            dailyRunTarget: 10,
            completedRuns: [self.run(completedAt: self.date(day: 15, hour: 17))])
        let presentation = self.presentation(
            project: project,
            now: now,
            relativeDescription: { _ in "yesterday" },
            timeDescription: { _ in "10:30 AM" })

        #expect(presentation.visualState == .normal)
        #expect(presentation.statusText == "Scheduled")
        #expect(presentation.timingText == "Next at 10:30 AM · Last yesterday")
        #expect(presentation.actionTitle == "Mark started")
        #expect(presentation.isActionProminent == false)
    }

    @Test("Weekly cards report a shortfall only after the weekly cadence ends")
    func weeklyShortfallPresentation() {
        let now = self.date(day: 23, hour: 20)
        let project = ProjectRecord(
            name: "Weekly Project",
            dailyRunTarget: 7,
            cadencePeriod: .weekly,
            completedRuns: (17...21).map { day in
                self.run(completedAt: self.date(day: day, hour: 15))
            })
        let presentation = self.presentation(
            project: project,
            now: now,
            relativeDescription: { _ in "2d ago" })

        #expect(presentation.visualState == .overdue)
        #expect(presentation.statusText == "2 short this week")
        #expect(presentation.timingText == "Last 2d ago")
        #expect(presentation.progressText == "5/7 this week")
        #expect(presentation.actionTitle == "Mark started")
    }

    @Test("Weekly cards stay due rather than final during an earlier evening")
    func weeklyEveningPresentation() {
        let now = self.date(day: 20, hour: 20)
        let project = ProjectRecord(
            name: "Weekly Project",
            dailyRunTarget: 7,
            cadencePeriod: .weekly,
            completedRuns: (17...19).map { day in
                self.run(completedAt: self.date(day: day, hour: 15))
            })
        let presentation = self.presentation(
            project: project,
            now: now,
            relativeDescription: { _ in "yesterday" })

        #expect(presentation.visualState == .overdue)
        #expect(presentation.statusText == "1 behind pace")
        #expect(presentation.timingText == "Last yesterday")
    }

    private func presentation(
        project: ProjectRecord,
        now: Date,
        relativeDescription: @escaping (Date) -> String = { _ in "relative" },
        elapsedDescription: @escaping (Date) -> String = { _ in "elapsed" },
        timeDescription: @escaping (Date) -> String = { _ in "time" })
        -> ProjectCardPresentation
    {
        ProjectCardPresentation.make(
            project: project,
            cadence: ProjectCadence.snapshot(for: project, at: now, calendar: self.calendar),
            relativeDescription: relativeDescription,
            elapsedDescription: elapsedDescription,
            timeDescription: timeDescription)
    }

    private func date(
        day: Int = 16,
        hour: Int,
        minute: Int = 0)
        -> Date
    {
        self.calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute))!
    }

    private func run(completedAt: Date) -> CompletedAgentRun {
        CompletedAgentRun(startedAt: completedAt.addingTimeInterval(-60), completedAt: completedAt)
    }
}
