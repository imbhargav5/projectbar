import Foundation
@testable import ProjectBar
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
        #expect(store.project(withID: projectID)?.dailyRunTarget == ProjectStore.dailyTargetRange.upperBound)

        store.setDailyTarget(-1, forProjectID: projectID)
        #expect(store.project(withID: projectID)?.dailyRunTarget == ProjectStore.dailyTargetRange.lowerBound)
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
