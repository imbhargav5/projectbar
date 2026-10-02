import Foundation
@testable import ProjectBar
import ProjectBarCore
import Testing

@MainActor
struct ProjectStoreTests {
    @Test("Two taps persist a started run and then complete it")
    func twoTapRunLifecycle() throws {
        let fixture = try PersistenceFixture()
        defer { fixture.remove() }
        let store = ProjectStore(persistenceURL: fixture.stateURL)
        let start = Date(timeIntervalSince1970: 1_787_000_000)
        let completion = start.addingTimeInterval(90)

        store.addProject(name: "ProjectBar", dailyTarget: 10)
        let projectID = try #require(store.projects.first?.id)

        store.startOrCompleteRun(forProjectID: projectID, at: start)
        #expect(store.project(withID: projectID)?.activeRun?.startedAt == start)
        #expect(store.project(withID: projectID)?.completedRuns.isEmpty == true)

        let storeAfterStart = ProjectStore(persistenceURL: fixture.stateURL)
        #expect(storeAfterStart.project(withID: projectID)?.activeRun?.startedAt == start)

        storeAfterStart.startOrCompleteRun(forProjectID: projectID, at: completion)
        #expect(storeAfterStart.project(withID: projectID)?.activeRun == nil)
        #expect(storeAfterStart.project(withID: projectID)?.completedRuns.count == 1)
        #expect(storeAfterStart.project(withID: projectID)?.completedRuns.first?.completedAt == completion)

        let storeAfterCompletion = ProjectStore(persistenceURL: fixture.stateURL)
        #expect(storeAfterCompletion.project(withID: projectID)?.completedRuns.count == 1)
    }

    @Test("Daily target is clamped to the slider range")
    func targetClamping() throws {
        let fixture = try PersistenceFixture()
        defer { fixture.remove() }
        let store = ProjectStore(persistenceURL: fixture.stateURL)

        store.addProject(name: "ProjectBar", dailyTarget: 10_000)
        let projectID = try #require(store.projects.first?.id)
        #expect(store.project(withID: projectID)?.runTarget == ProjectStore.targetRange.upperBound)

        store.setDailyTarget(-1, forProjectID: projectID)
        #expect(store.project(withID: projectID)?.runTarget == ProjectStore.targetRange.lowerBound)
    }

    @Test("Repeated run intents cannot toggle a run twice or complete a different run")
    func duplicateRunActions() throws {
        let fixture = try PersistenceFixture()
        defer { fixture.remove() }
        let store = ProjectStore(persistenceURL: fixture.stateURL)
        store.addProject(name: "ProjectBar")
        let id = try #require(store.projects.first?.id)
        #expect(store.performRunAction(forProjectID: id, expectedActiveRunID: nil))
        let runID = try #require(store.project(withID: id)?.activeRun?.id)
        #expect(!store.performRunAction(forProjectID: id, expectedActiveRunID: nil))
        #expect(!store.performRunAction(forProjectID: id, expectedActiveRunID: UUID()))
        #expect(store.performRunAction(forProjectID: id, expectedActiveRunID: runID))
        #expect(!store.performRunAction(forProjectID: id, expectedActiveRunID: runID))
        #expect(store.project(withID: id)?.activeRun == nil)
        #expect(store.project(withID: id)?.completedRuns.count == 1)
        #expect(store.performRunAction(forProjectID: id, expectedActiveRunID: nil))
        #expect(!store.performRunAction(forProjectID: id, expectedActiveRunID: runID))
        #expect(store.project(withID: id)?.activeRun != nil)
        #expect(!store.performRunAction(forProjectID: UUID(), expectedActiveRunID: nil))
    }

    @Test("Completion notice undo targets the named run and preserves newer work")
    func undoSpecificCompletion() throws {
        let fixture = try PersistenceFixture()
        defer { fixture.remove() }
        let store = ProjectStore(persistenceURL: fixture.stateURL)
        store.addProject(name: "ProjectBar")
        let projectID = try #require(store.projects.first?.id)
        let start = Date(timeIntervalSince1970: 1_787_000_000)
        store.startOrCompleteRun(forProjectID: projectID, at: start)
        let firstRunID = try #require(store.project(withID: projectID)?.activeRun?.id)
        store.startOrCompleteRun(forProjectID: projectID, at: start.addingTimeInterval(60))
        store.startOrCompleteRun(forProjectID: projectID, at: start.addingTimeInterval(120))
        store.startOrCompleteRun(forProjectID: projectID, at: start.addingTimeInterval(180))
        let newerRunID = try #require(store.project(withID: projectID)?.completedRuns.last?.id)
        store.startOrCompleteRun(forProjectID: projectID, at: start.addingTimeInterval(240))
        let activeRun = store.project(withID: projectID)?.activeRun
        store.tick(at: start.addingTimeInterval(8 * 86400))

        store.undoCompletedRun(id: firstRunID, forProjectID: projectID)
        store.undoCompletedRun(id: firstRunID, forProjectID: projectID)

        let reloaded = ProjectStore(persistenceURL: fixture.stateURL)
        #expect(reloaded.project(withID: projectID)?.completedRuns.map(\.id) == [newerRunID])
        #expect(reloaded.project(withID: projectID)?.activeRun == activeRun)
    }

    @Test("Exact target bounds survive settings and reload", arguments: [1, 200])
    func exactTargetBounds(target: Int) throws {
        let fixture = try PersistenceFixture()
        defer { fixture.remove() }
        let store = ProjectStore(persistenceURL: fixture.stateURL)
        store.addProject(name: "ProjectBar")
        let projectID = try #require(store.projects.first?.id)
        store.setCadence(.weekly, target: target, forProjectID: projectID)
        let reloaded = ProjectStore(persistenceURL: fixture.stateURL)
        #expect(reloaded.project(withID: projectID)?.runTarget == target)
        #expect(reloaded.project(withID: projectID)?.cadencePeriod == .weekly)
    }

    @Test("Weekly cadence settings persist across launches")
    func weeklyCadencePersistence() throws {
        let fixture = try PersistenceFixture()
        defer { fixture.remove() }
        let store = ProjectStore(persistenceURL: fixture.stateURL)
        store.addProject(name: "Weekly Project", dailyTarget: 10)
        let projectID = try #require(store.projects.first?.id)

        store.setCadence(.weekly, target: 6, forProjectID: projectID)

        let reloadedStore = ProjectStore(persistenceURL: fixture.stateURL)
        let project = try #require(reloadedStore.project(withID: projectID))
        #expect(project.cadencePeriod == .weekly)
        #expect(project.runTarget == 6)
    }

    @Test("A parent folder imports all immediate child folders")
    func bulkChildFolderImport() throws {
        let fixture = try PersistenceFixture()
        defer { fixture.remove() }
        let parentURL = fixture.directoryURL.appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(
            at: parentURL.appendingPathComponent("Beta", isDirectory: true),
            withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: parentURL.appendingPathComponent("Alpha", isDirectory: true),
            withIntermediateDirectories: true)
        try Data("not a project".utf8).write(to: parentURL.appendingPathComponent("README.txt"))
        let store = ProjectStore(persistenceURL: fixture.stateURL)

        store.addChildProjectFolders(from: parentURL)

        #expect(store.projects.map(\.name) == ["Alpha", "Beta"])
    }
}

private struct PersistenceFixture {
    let directoryURL: URL
    let stateURL: URL

    init() throws {
        self.directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectBarTests-\(UUID().uuidString)", isDirectory: true)
        self.stateURL = self.directoryURL.appendingPathComponent("state.json")
        try FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: self.directoryURL)
    }
}
