import Foundation
@testable import ProjectBar
import Testing

@MainActor
struct LaunchAtLoginManagerTests {
    @Test("Enabling launch at login registers the main app service")
    func enable() {
        let service = FakeLaunchAtLoginService(status: .disabled)
        let manager = LaunchAtLoginManager(service: service)

        manager.setEnabled(true)

        #expect(service.registerCallCount == 1)
        #expect(manager.status == .enabled)
        #expect(manager.isRequested == true)
        #expect(manager.errorMessage == nil)
    }

    @Test("Disabling launch at login unregisters the main app service")
    func disable() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let manager = LaunchAtLoginManager(service: service)

        manager.setEnabled(false)

        #expect(service.unregisterCallCount == 1)
        #expect(manager.status == .disabled)
        #expect(manager.isRequested == false)
    }

    @Test("Approval-required status remains requested and can open System Settings")
    func requiresApproval() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)
        let manager = LaunchAtLoginManager(service: service)

        manager.openSystemSettings()

        #expect(manager.isRequested == true)
        #expect(service.openSettingsCallCount == 1)
    }

    @Test("Registration errors are presented without reporting startup as enabled")
    func registrationError() {
        let service = FakeLaunchAtLoginService(status: .disabled)
        service.registerError = FakeLaunchAtLoginError.registrationFailed
        let manager = LaunchAtLoginManager(service: service)

        manager.setEnabled(true)

        #expect(manager.status == .disabled)
        #expect(manager.isRequested == false)
        #expect(manager.errorMessage == "Registration failed")
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus
    var registerError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var openSettingsCallCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func register() throws {
        self.registerCallCount += 1
        if let registerError {
            throw registerError
        }
        self.status = .enabled
    }

    func unregister() throws {
        self.unregisterCallCount += 1
        self.status = .disabled
    }

    func openSystemSettings() {
        self.openSettingsCallCount += 1
    }
}

private enum FakeLaunchAtLoginError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        "Registration failed"
    }
}
