import AppKit
import SwiftUI

@MainActor
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ProjectBar Settings")
                        .font(.title3.weight(.semibold))
                    Text("Application behavior")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Launch ProjectBar at login", isOn: self.launchAtLoginBinding)
                    .disabled(!self.launchAtLogin.canChange)

                Text(self.launchAtLoginDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if self.launchAtLogin.status == .requiresApproval {
                    Button("Open Login Items Settings…") {
                        self.launchAtLogin.openSystemSettings()
                    }
                }

                if let errorMessage = self.launchAtLogin.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Installed build")
                        .font(.body.weight(.medium))
                    Spacer()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                    .buttonStyle(.link)
                }

                Text(Bundle.main.bundleURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if !self.launchAtLogin.isInstalledInApplications {
                    Label(
                        "Run `make install` before enabling startup so macOS has a stable application path.",
                        systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    self.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 480)
        .onAppear {
            self.launchAtLogin.refresh()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.launchAtLogin.isRequested },
            set: { self.launchAtLogin.setEnabled($0) })
    }

    private var launchAtLoginDescription: String {
        switch self.launchAtLogin.status {
        case .disabled:
            "ProjectBar will only run when you open it."
        case .enabled:
            "ProjectBar will open automatically when you sign in to this Mac."
        case .requiresApproval:
            "macOS requires approval in System Settings before ProjectBar can launch automatically."
        case .unavailable:
            "Launch at login is available from a signed ProjectBar.app build."
        }
    }
}
