import AppKit
import Foundation
import Observation
import ProjectBarCore

@MainActor
@Observable
final class ProjectStore {
    static let dailyTargetRange = 1...200

    private(set) var projects: [ProjectRecord] = []
    private(set) var now = Date()
    private(set) var lastPersistenceError: String?

    @ObservationIgnored private let persistenceURL: URL
    @ObservationIgnored var onDashboardChanged: (() -> Void)?

    init(persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL ?? Self.defaultPersistenceURL()
        self.load()
    }

    var totalDailyTarget: Int {
        self.projects.reduce(0) { $0 + $1.dailyRunTarget }
    }

    var completedToday: Int {
        let calendar = Calendar.autoupdatingCurrent
        return self.projects.reduce(0) { total, project in
            total + project.completedRunCount(on: self.now, calendar: calendar)
        }
    }

    var expectedToday: Int {
        let calendar = Calendar.autoupdatingCurrent
        return self.projects.reduce(0) { total, project in
            total + ProjectCadence.snapshot(for: project, at: self.now, calendar: calendar).expected
        }
    }

    var runsBehind: Int {
        let calendar = Calendar.autoupdatingCurrent
        return self.projects.reduce(0) { total, project in
            total + ProjectCadence.snapshot(for: project, at: self.now, calendar: calendar).behind
        }
    }

    var activeRunCount: Int {
        self.projects.count { $0.activeRun != nil }
    }

    func tick(at date: Date = Date()) {
        self.now = date
        self.onDashboardChanged?()
    }

    func project(withID id: UUID) -> ProjectRecord? {
        self.projects.first { $0.id == id }
    }

    func addProject(name: String, folderPath: String? = nil, dailyTarget: Int = 10) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let folderPath {
            let standardizedPath = URL(fileURLWithPath: folderPath).standardizedFileURL.path
            guard !self.projects.contains(where: { project in
                project.folderPath.map { URL(fileURLWithPath: $0).standardizedFileURL.path } == standardizedPath
            }) else { return }
        }

        self.projects.append(ProjectRecord(
            name: trimmedName,
            folderPath: folderPath,
            dailyRunTarget: Self.clampTarget(dailyTarget)))
        self.commitChange()
    }

    func addProjectFolders(_ urls: [URL]) {
        for url in urls where url.isFileURL {
            self.addProject(name: url.lastPathComponent, folderPath: url.standardizedFileURL.path)
        }
    }

    func addChildProjectFolders(from parentURL: URL) {
        do {
            let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
            let children = try FileManager.default.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles])
            let folders = try children.filter { url in
                let values = try url.resourceValues(forKeys: resourceKeys)
                return values.isDirectory == true && values.isHidden != true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            self.addProjectFolders(folders)
        } catch {
            self.lastPersistenceError = "Could not import folders: \(error.localizedDescription)"
            self.onDashboardChanged?()
        }
    }

    func renameProject(id: UUID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let index = self.projects.firstIndex(where: { $0.id == id }) else { return }
        self.projects[index].name = trimmedName
        self.commitChange()
    }

    func setDailyTarget(_ target: Int, forProjectID id: UUID) {
        guard let index = self.projects.firstIndex(where: { $0.id == id }) else { return }
        let target = Self.clampTarget(target)
        guard self.projects[index].dailyRunTarget != target else { return }
        self.projects[index].dailyRunTarget = target
        self.commitChange()
    }

    func startOrCompleteRun(forProjectID id: UUID, at date: Date? = nil) {
        guard let index = self.projects.firstIndex(where: { $0.id == id }) else { return }
        let eventDate = date ?? Date()
        if let activeRun = self.projects[index].activeRun {
            self.projects[index].completedRuns.append(CompletedAgentRun(
                id: activeRun.id,
                startedAt: activeRun.startedAt,
                completedAt: eventDate))
            self.projects[index].activeRun = nil
        } else {
            self.projects[index].activeRun = ActiveAgentRun(startedAt: eventDate)
        }
        self.now = eventDate
        self.commitChange()
    }

    func cancelActiveRun(forProjectID id: UUID) {
        guard let index = self.projects.firstIndex(where: { $0.id == id }) else { return }
        guard self.projects[index].activeRun != nil else { return }
        self.projects[index].activeRun = nil
        self.commitChange()
    }

    func undoLastCompletedRun(forProjectID id: UUID) {
        guard let index = self.projects.firstIndex(where: { $0.id == id }) else { return }
        let calendar = Calendar.autoupdatingCurrent
        guard let run = self.projects[index].lastCompletedRun(on: self.now, calendar: calendar),
              let runIndex = self.projects[index].completedRuns.firstIndex(where: { $0.id == run.id })
        else { return }
        self.projects[index].completedRuns.remove(at: runIndex)
        self.commitChange()
    }

    func removeProject(id: UUID) {
        let previousCount = self.projects.count
        self.projects.removeAll { $0.id == id }
        guard previousCount != self.projects.count else { return }
        self.commitChange()
    }

    private static func clampTarget(_ target: Int) -> Int {
        min(Self.dailyTargetRange.upperBound, max(Self.dailyTargetRange.lowerBound, target))
    }

    private static func defaultPersistenceURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return applicationSupport
            .appendingPathComponent("ProjectBar", isDirectory: true)
            .appendingPathComponent("state.json", isDirectory: false)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: self.persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: self.persistenceURL)
            let state = try JSONDecoder.projectBar.decode(ProjectBarState.self, from: data)
            self.projects = state.projects
        } catch {
            self.lastPersistenceError = "Could not load saved projects: \(error.localizedDescription)"
        }
    }

    private func commitChange() {
        self.persist()
        self.onDashboardChanged?()
    }

    private func persist() {
        do {
            let directory = self.persistenceURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let state = ProjectBarState(projects: self.projects)
            let data = try JSONEncoder.projectBar.encode(state)
            try data.write(to: self.persistenceURL, options: .atomic)
            self.lastPersistenceError = nil
        } catch {
            self.lastPersistenceError = "Could not save projects: \(error.localizedDescription)"
        }
    }
}

private extension JSONEncoder {
    static var projectBar: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var projectBar: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
