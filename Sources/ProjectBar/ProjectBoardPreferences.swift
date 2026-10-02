import Foundation
import Observation

enum ProjectCardDensity: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case comfortable = "Comfortable"

    var id: Self { self }
}

@MainActor
@Observable
final class ProjectBoardPreferences {
    var density: ProjectCardDensity {
        didSet { self.defaults.set(self.density.rawValue, forKey: Self.densityKey) }
    }
    private(set) var pinnedProjectIDs: Set<UUID>

    @ObservationIgnored private let defaults: UserDefaults
    private static let densityKey = "board.cardDensity"
    private static let pinsKey = "board.pinnedProjectIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.density = defaults.string(forKey: Self.densityKey).flatMap(ProjectCardDensity.init(rawValue:)) ?? .compact
        self.pinnedProjectIDs = Set((defaults.stringArray(forKey: Self.pinsKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    func togglePin(for id: UUID) {
        if !self.pinnedProjectIDs.insert(id).inserted { self.pinnedProjectIDs.remove(id) }
        self.savePins()
    }

    func retainPins(for projectIDs: Set<UUID>) {
        let retained = self.pinnedProjectIDs.intersection(projectIDs)
        guard retained != self.pinnedProjectIDs else { return }
        self.pinnedProjectIDs = retained
        self.savePins()
    }

    private func savePins() {
        self.defaults.set(self.pinnedProjectIDs.map(\.uuidString).sorted(), forKey: Self.pinsKey)
    }
}
