import Foundation
@testable import ProjectBar
import ProjectBarCore
import Testing

struct ProjectCardPresentationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }()

    @Test("On-cadence cards combine last and next run details")
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
        #expect(presentation.statusText == "Last 18m ago · Next in 42m")
        #expect(presentation.actionTitle == "Start agent")
        #expect(presentation.isActionProminent == false)
    }

    @Test("Overdue cards combine due count and cross-day last run")
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
        #expect(presentation.statusText == "3 due now · Last yesterday")
        #expect(presentation.actionTitle == "Start due agent")
        #expect(presentation.isActionProminent == true)
    }

    @Test("Running cards subtract the active run from the remaining backlog")
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
        #expect(presentation.statusText == "Running 3m · 2 still due")
        #expect(presentation.actionTitle == "Confirm complete")
        #expect(presentation.isActionProminent == true)
    }

    @Test("Complete cards retain an outlined start-another action")
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
        #expect(presentation.statusText == "Complete · Last 4m ago")
        #expect(presentation.actionTitle == "Start another")
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
        #expect(presentation.statusText == "Starts at 10:30 AM · Last yesterday")
        #expect(presentation.actionTitle == "Start agent")
        #expect(presentation.isActionProminent == false)
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
