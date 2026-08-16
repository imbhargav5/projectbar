import Foundation
import Observation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    private let service = SMAppService.mainApp

    var status: LaunchAtLoginStatus {
        switch self.service.status {
        case .notRegistered: .disabled
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func register() throws {
        try self.service.register()
    }

    func unregister() throws {
        try self.service.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
@Observable
final class LaunchAtLoginManager {
    private(set) var status: LaunchAtLoginStatus
    private(set) var errorMessage: String?

    @ObservationIgnored private let service: any LaunchAtLoginServicing

    init(service: any LaunchAtLoginServicing = SystemLaunchAtLoginService()) {
        self.service = service
        self.status = service.status
    }

    var isRequested: Bool {
        self.status == .enabled || self.status == .requiresApproval
    }

    var canChange: Bool {
        self.status != .unavailable
    }

    var isInstalledInApplications: Bool {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        let fileManager = FileManager.default
        let applicationDirectories =
            fileManager.urls(for: .applicationDirectory, in: .localDomainMask) +
            fileManager.urls(for: .applicationDirectory, in: .userDomainMask)
        return applicationDirectories.contains { directory in
            bundleURL.path.hasPrefix(directory.standardizedFileURL.path + "/")
        }
    }

    func refresh() {
        self.status = self.service.status
    }

    func setEnabled(_ enabled: Bool) {
        self.errorMessage = nil
        do {
            if enabled {
                guard self.status != .enabled else { return }
                try self.service.register()
            } else {
                guard self.status != .disabled else { return }
                try self.service.unregister()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.refresh()
    }

    func openSystemSettings() {
        self.service.openSystemSettings()
    }
}
