import AppKit
import ProjectBarCore
import SwiftUI

@MainActor
struct ProjectCardView: View {
    let project: ProjectRecord
    let store: ProjectStore
    let onSettings: () -> Void
    let onRemove: () -> Void
    let density: ProjectCardDensity
    let isPinned: Bool
    let isSelected: Bool
    let onTogglePin: () -> Void
    let onRunAction: (ProjectRecord) -> Void
    let onRevealFolder: (String) -> Void
    let onCopyPath: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var cadence: CadenceSnapshot {
        ProjectCadence.snapshot(for: self.project, at: self.store.now)
    }

    private var presentation: ProjectCardPresentation {
        ProjectCardPresentation.make(
            project: self.project,
            cadence: self.cadence,
            relativeDescription: self.relativeDescription,
            elapsedDescription: self.elapsedDescription,
            timeDescription: self.timeDescription)
    }

    private var statusColor: Color {
        switch self.presentation.visualState {
        case .normal: .secondary
        case .overdue: ProjectStatusColor.behind(in: self.colorScheme)
        case .active: .accentColor
        case .complete: ProjectStatusColor.complete(in: self.colorScheme)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: self.density == .compact ? 8 : 14) {
            self.cardHeader
            Label(self.presentation.statusText, systemImage: self.presentation.statusSymbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.statusColor)
                .lineLimit(1)
                .help(self.presentation.statusText)

            VStack(alignment: .leading, spacing: self.density == .compact ? 4 : 6) {
                if self.density == .compact {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        self.progressLabel
                        Spacer(minLength: 0)
                        Text("\(self.cadence.expected) expected")
                            .foregroundStyle(.secondary)
                            .help(self.presentation.expectedText)
                            .accessibilityLabel(self.presentation.expectedText)
                    }
                    .font(.system(size: 12).monospacedDigit())
                } else {
                    self.progressLabel
                }
                CadenceProgressView(snapshot: self.cadence)
                if self.density == .comfortable {
                    Text(self.presentation.expectedText)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if self.density == .comfortable {
                Text(self.presentation.timingText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(self.presentation.timingText)
            }

            HStack(spacing: 6) {
                self.actionButton
                if let path = self.project.folderPath {
                    Button { self.onRevealFolder(path) } label: {
                        Image(systemName: "folder")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Reveal \(self.project.name) in Finder")
                    .help("Reveal in Finder")
                }
            }
        }
        .padding(self.density == .compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(ProjectSurface(emphasized: self.presentation.visualState == .active, selected: self.isSelected))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-card-\(self.project.id.uuidString)")
        .accessibilityLabel(self.project.name)
        .accessibilityValue(self.presentation.timingText)
        .accessibilityAddTraits(self.isSelected ? [.isSelected] : [])
        .help(self.presentation.timingText)
        .animation(self.reduceMotion ? nil : .easeInOut(duration: 0.18), value: self.presentation.visualState)
    }

    private var progressLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(self.cadence.completed)")
                .font(.system(size: self.density == .compact ? 17 : 22, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary)
            Text("/ \(self.cadence.target)")
                .font(.system(size: 12).monospacedDigit())
            Text(self.cadence.period == .daily ? "today" : "this week")
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.presentation.progressText)
    }

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: self.project.folderPath == nil ? "square.stack.3d.up" : "folder.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(self.project.folderPath == nil ? Color.secondary : Color.accentColor.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            Text(self.project.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(self.project.name)
                .accessibilityAddTraits(.isHeader)
            if self.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pinned project")
                    .padding(.top, 4)
            }
            Menu {
                Button(self.isPinned ? "Unpin Project" : "Pin Project", systemImage: self.isPinned ? "pin.slash" : "pin", action: self.onTogglePin)
                Divider()
                Button("Project Settings…", systemImage: "gearshape", action: self.onSettings)
                if let path = self.project.folderPath {
                    Button("Reveal in Finder", systemImage: "folder") {
                        self.onRevealFolder(path)
                    }
                    Button("Copy Folder Path", systemImage: "doc.on.doc") { self.onCopyPath(path) }
                }
                Divider()
                if self.project.activeRun != nil {
                    Button("Cancel Active Run", systemImage: "xmark.circle") {
                        self.store.cancelActiveRun(forProjectID: self.project.id)
                    }
                }
                if self.cadence.completed > 0 {
                    Button("Undo Last Completion", systemImage: "arrow.uturn.backward") {
                        self.store.undoLastCompletedRun(forProjectID: self.project.id)
                    }
                }
                Divider()
                Button("Remove Project", systemImage: "trash", role: .destructive, action: self.onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .foregroundStyle(.secondary)
            .fixedSize()
            .accessibilityLabel("Actions for \(self.project.name)")
            .help("Project actions")
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if self.presentation.isActionProminent {
            self.actionControl.buttonStyle(.borderedProminent)
        } else {
            self.actionControl.buttonStyle(.bordered)
        }
    }

    private var actionControl: some View {
        Button {
            self.onRunAction(self.project)
        } label: {
            Label(self.presentation.actionTitle, systemImage: self.presentation.actionSymbol)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 20)
        }
        .controlSize(.regular)
        .accessibilityLabel("\(self.presentation.actionTitle) for \(self.project.name)")
        .help(self.project.activeRun == nil
            ? "Record that you started a run yourself. ProjectBar does not launch an agent. Shortcut: ⌘Return on the focused card."
            : "Record that this manually tracked run has finished. Shortcut: ⌘Return on the focused card.")
    }

    private func relativeDescription(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: self.store.now)
    }

    private func elapsedDescription(_ date: Date) -> String {
        let elapsed = max(0, self.store.now.timeIntervalSince(date))
        if elapsed < 60 { return "just started" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m" }
        return "\(Int(elapsed / 3600))h"
    }

    private func timeDescription(_ date: Date) -> String {
        if !Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: self.store.now) {
            return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

enum ProjectStatusColor {
    static func behind(in scheme: ColorScheme) -> Color {
        scheme == .dark ? .orange : Color(red: 0.62, green: 0.29, blue: 0.02)
    }

    static func complete(in scheme: ColorScheme) -> Color {
        scheme == .dark ? .green : Color(red: 0.15, green: 0.43, blue: 0.26)
    }
}

private struct CadenceProgressView: View {
    let snapshot: CadenceSnapshot

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width)
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(.tint.opacity(0.12))
                    .frame(width: width * self.snapshot.expectedProgress)
                Capsule()
                    .fill(.tint)
                    .frame(width: width * self.snapshot.completionProgress)
                Rectangle()
                    .fill(.primary.opacity(0.65))
                    .frame(width: 1.5, height: 9)
                    .offset(x: max(0, min(width - 1.5, width * self.snapshot.expectedProgress - 0.75)))
            }
        }
        .frame(height: 6)
        .help("Filled: completed runs. Marker: expected by now.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Run progress")
        .accessibilityValue("\(self.snapshot.completed) of \(self.snapshot.target) completed; \(self.snapshot.expected) expected by now")
    }
}
