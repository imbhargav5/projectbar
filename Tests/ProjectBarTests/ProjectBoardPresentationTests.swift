import Foundation
@testable import ProjectBar
import ProjectBarCore
import Testing

struct ProjectBoardPresentationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(day: Int = 19, hour: Int = 13) -> Date {
        self.calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    private func run(day: Int = 19) -> CompletedAgentRun {
        CompletedAgentRun(startedAt: self.date(day: day, hour: 11), completedAt: self.date(day: day, hour: 12))
    }

    private var projects: [ProjectRecord] {
        [
            ProjectRecord(name: "Zeta", dailyRunTarget: 10),
            ProjectRecord(name: "Alpha", dailyRunTarget: 10, completedRuns: [self.run()],
                          activeRun: ActiveAgentRun(startedAt: self.date(hour: 12))),
            ProjectRecord(name: "Café", dailyRunTarget: 7, cadencePeriod: .weekly,
                          completedRuns: [self.run(day: 18)]),
            ProjectRecord(name: "Done", dailyRunTarget: 1, completedRuns: [self.run()]),
        ]
    }

    @Test("Period summaries keep prior-day weekly completions out of daily totals")
    func separatePeriodSummaries() {
        let board = ProjectBoardPresentation(projects: self.projects, now: self.date(), calendar: self.calendar)
        #expect(board.summaries == [
            ProjectPeriodSummary(period: .daily, projectCount: 3, completed: 2, target: 21),
            ProjectPeriodSummary(period: .weekly, projectCount: 1, completed: 1, target: 7),
        ])
        #expect(board.runsBehind == 6)
        #expect(board.runningCount == 1)
        #expect(board.statusItemTitle == "6 behind pace · 1 running")
    }

    @Test("Search intersects status filters without sorting stored project order")
    func filterAndSearch() {
        let board = ProjectBoardPresentation(projects: self.projects, now: self.date(), calendar: self.calendar)
        #expect(board.projects().map(\.name) == ["Zeta", "Alpha", "Café", "Done"])
        #expect(board.projects(filter: .behind).map(\.name) == ["Zeta", "Alpha", "Café"])
        #expect(board.projects(filter: .running).map(\.name) == ["Alpha"])
        #expect(board.projects(filter: .complete).map(\.name) == ["Done"])
        #expect(board.projects(matching: "  ALP  ", filter: .behind).map(\.name) == ["Alpha"])
        #expect(board.projects(matching: "cafe").map(\.name) == ["Café"])
        #expect(board.projects(matching: "Alpha", filter: .complete).isEmpty)
        #expect(board.projects(matching: "missing").isEmpty)
    }

    @Test("All preserves card positions when a run starts or completes")
    func stableOrderAcrossRunChanges() {
        var projects = self.projects
        let originalIDs = projects.map(\.id)
        projects[0].activeRun = ActiveAgentRun(startedAt: self.date())
        projects[1].activeRun = nil
        projects[1].completedRuns.append(self.run())
        let board = ProjectBoardPresentation(projects: projects, now: self.date(), calendar: self.calendar)
        #expect(board.projects().map(\.id) == originalIDs)
        #expect(board.projects(filter: .running).map(\.id) == [originalIDs[0]])
    }

    @Test("Pins group stably after filtering without changing summaries")
    func pinnedGrouping() {
        let projects = self.projects
        let pins: Set<UUID> = [projects[1].id, projects[3].id]
        let board = ProjectBoardPresentation(projects: projects, now: self.date(), calendar: self.calendar)
        #expect(board.projects(pinnedIDs: pins).map(\.name) == ["Alpha", "Done", "Zeta", "Café"])
        #expect(board.projects(filter: .behind, pinnedIDs: pins).map(\.name) == ["Alpha", "Zeta", "Café"])
        #expect(board.projects(matching: "zeta", pinnedIDs: pins).map(\.name) == ["Zeta"])
        #expect(board.projects(filter: .running, pinnedIDs: pins).map(\.name) == ["Alpha"])
        #expect(board.projects(filter: .complete, pinnedIDs: pins).map(\.name) == ["Done"])
        #expect(board.projects(pinnedIDs: [UUID()]).map(\.id) == projects.map(\.id))
        #expect(board.summaries.map(\.completed) == [2, 1])
    }

    @Test("Empty and on-pace status items never invent combined period totals")
    func emptyAndOnPace() {
        let empty = ProjectBoardPresentation(projects: [], now: self.date(), calendar: self.calendar)
        #expect(empty.statusItemTitle.isEmpty)
        #expect(empty.summaries.isEmpty)
        for filter in ProjectBoardFilter.allCases { #expect(empty.projects(filter: filter).isEmpty) }
        let projects = [
            ProjectRecord(name: "Daily", dailyRunTarget: 1, completedRuns: [self.run()]),
            ProjectRecord(name: "Weekly", dailyRunTarget: 1, cadencePeriod: .weekly, completedRuns: [self.run(day: 18)]),
        ]
        let board = ProjectBoardPresentation(projects: projects, now: self.date(), calendar: self.calendar)
        #expect(board.statusItemTitle == "1/1 today · 1/1 this week")
    }

    @Test("One, sixteen and fifty projects retain every matching card", arguments: [1, 16, 50])
    func projectCounts(count: Int) {
        let projects = (0..<count).map { ProjectRecord(name: "Project \($0)") }
        let board = ProjectBoardPresentation(projects: projects, now: self.date(), calendar: self.calendar)
        #expect(board.projects().map(\.id) == projects.map(\.id))
        #expect(board.projects(filter: .behind).count == count)
    }

    @Test("Popover and columns fit normal and constrained screens")
    func adaptiveLayout() {
        #expect(ProjectBoardLayout.columnCount(for: 812) == 3)
        #expect(ProjectBoardLayout.columnCount(for: 536) == 2)
        #expect(ProjectBoardLayout.columnCount(for: 320) == 1)
        #expect(ProjectBoardLayout.popoverSize(available: CGSize(width: 1440, height: 875), isEmpty: false)
            == CGSize(width: 812, height: 720))
        #expect(ProjectBoardLayout.popoverSize(available: CGSize(width: 640, height: 480), isEmpty: false)
            == CGSize(width: 616, height: 448))
        #expect(ProjectBoardLayout.popoverSize(available: CGSize(width: 320, height: 400), isEmpty: true)
            == CGSize(width: 296, height: 368))
    }

    @Test("Targets accept exact integer bounds and reject incomplete or invalid input")
    func targetInput() {
        #expect(ProjectTargetInput.value(from: "1") == 1)
        #expect(ProjectTargetInput.value(from: "200") == 200)
        #expect(ProjectTargetInput.value(from: " 37 ") == 37)
        for input in ["", "0", "201", "-1", "1.5", "ten", "99999999999999999999999"] {
            #expect(ProjectTargetInput.value(from: input) == nil)
        }
    }
}
