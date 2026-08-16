import AppKit
import ProjectBarCore
import SwiftUI

@MainActor
struct ProjectBoardView: View {
    let store: ProjectStore
    let launchAtLogin: LaunchAtLoginManager
    let onClose: () -> Void

    @State private var nameEditor: ProjectNameEditorRequest?
    @State private var settingsProject: ProjectRecord?
    @State private var pendingRemoval: ProjectRecord?
    @State private var showingAppSettings = false

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 220, maximum: 260), spacing: 12, alignment: .top),
        count: 3)

    var body: some View {
        VStack(spacing: 0) {
            self.header
            Divider()
            Group {
                if self.store.projects.isEmpty {
                    self.emptyState
                } else {
                    self.projectGrid
                }
            }
            Divider()
            self.footer
        }
        .frame(width: 812, height: self.store.projects.isEmpty ? 420 : 640)
        .background(.ultraThinMaterial)
        .sheet(item: self.$nameEditor) { request in
            ProjectNameEditorView(
                title: request.title,
                actionTitle: request.actionTitle,
                initialName: request.initialName)
            { name in
                if let projectID = request.projectID {
                    self.store.renameProject(id: projectID, to: name)
                } else {
                    self.store.addProject(name: name)
                }
            }
        }
        .sheet(item: self.$settingsProject) { project in
            ProjectSettingsView(project: project) { name, dailyTarget in
                self.store.renameProject(id: project.id, to: name)
                self.store.setDailyTarget(dailyTarget, forProjectID: project.id)
            }
        }
        .sheet(isPresented: self.$showingAppSettings) {
            AppSettingsView(launchAtLogin: self.launchAtLogin)
        }
        .alert(item: self.$pendingRemoval) { project in
            Alert(
                title: Text("Remove \(project.name)?"),
                message: Text("Its ProjectBar run history will be removed. The project folder is not changed."),
                primaryButton: .destructive(Text("Remove")) {
                    self.store.removeProject(id: project.id)
                },
                secondaryButton: .cancel())
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.tint)
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ProjectBar")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Keep every project moving")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(self.store.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Menu {
                    Button("Add Multiple Project Folders…", systemImage: "folder.badge.plus") {
                        self.chooseProjectFolders()
                    }
                    Button("Import Child Folders…", systemImage: "square.stack.3d.up") {
                        self.chooseParentFolderToImport()
                    }
                    Divider()
                    Button("Add Project by Name…", systemImage: "square.and.pencil") {
                        self.nameEditor = ProjectNameEditorRequest.newProject
                    }
                } label: {
                    Label("Add Project", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button(action: self.onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close ProjectBar")
            }

            HStack(spacing: 14) {
                TodaySummaryMetric(
                    value: "\(self.store.completedToday)",
                    label: "completed",
                    color: .green)
                TodaySummaryMetric(
                    value: "\(self.store.expectedToday)",
                    label: "expected now",
                    color: .blue)
                TodaySummaryMetric(
                    value: "\(self.store.totalDailyTarget)",
                    label: "daily target",
                    color: .secondary)

                Spacer(minLength: 20)

                if self.store.runsBehind > 0 {
                    Label("\(self.store.runsBehind) due", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.12), in: Capsule())
                } else if self.store.activeRunCount > 0 {
                    Label("\(self.store.activeRunCount) running", systemImage: "bolt.horizontal.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.indigo.opacity(0.12), in: Capsule())
                } else {
                    Label("On cadence", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var projectGrid: some View {
        ScrollView {
            LazyVGrid(columns: self.columns, alignment: .center, spacing: 12) {
                ForEach(self.store.projects) { project in
                    ProjectCardView(
                        project: project,
                        store: self.store,
                        onSettings: {
                            self.settingsProject = project
                        },
                        onRemove: {
                            self.pendingRemoval = project
                        })
                }
            }
            .padding(14)
        }
        .scrollIndicators(.visible)
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 5) {
                Text("Add your projects")
                    .font(.title3.weight(.semibold))
                Text("Choose one or more folders, then set an agent-run target for each project.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                Button("Add Multiple Folders…", systemImage: "folder.badge.plus") {
                    self.chooseProjectFolders()
                }
                .buttonStyle(.borderedProminent)
                Button("Import Parent…") {
                    self.chooseParentFolderToImport()
                }
                .buttonStyle(.bordered)
                Button("Add by Name…") {
                    self.nameEditor = .newProject
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
            Text("Local day · Work cadence 10:00–20:00")
            Spacer()
            if let error = self.store.lastPersistenceError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .help(error)
            }
            Button("About") {
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationName: "ProjectBar",
                    .applicationVersion: "0.1.0",
                    .credits: NSAttributedString(string: "A calm daily cadence for agent work."),
                ])
            }
            .buttonStyle(.plain)
            Button("Settings…") {
                self.showingAppSettings = true
            }
            .buttonStyle(.plain)
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 38)
    }

    private func chooseProjectFolders() {
        let panel = NSOpenPanel()
        panel.title = "Add Multiple Projects to ProjectBar"
        panel.message = "Choose one or more folders. Use Command-click or Shift-click to select several."
        panel.prompt = "Add Projects"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in
                self.store.addProjectFolders(urls)
            }
        }
    }

    private func chooseParentFolderToImport() {
        let panel = NSOpenPanel()
        panel.title = "Import Child Folders"
        panel.message = "Choose a parent folder. Every immediate folder inside it will be added as a project."
        panel.prompt = "Import Folders"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let parentURL = panel.url else { return }
            Task { @MainActor in
                self.store.addChildProjectFolders(from: parentURL)
            }
        }
    }
}

@MainActor
private struct ProjectCardView: View {
    let project: ProjectRecord
    let store: ProjectStore
    let onSettings: () -> Void
    let onRemove: () -> Void

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

    private var tint: Color {
        switch self.presentation.visualState {
        case .normal: .accentColor
        case .overdue: .red
        case .active: .indigo
        case .complete: .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.cardHeader
            self.statusLine
            CadenceProgressView(snapshot: self.cadence, tint: self.tint)
            self.actionButton
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(self.tint.opacity(self.presentation.visualState == .normal ? 0.02 : 0.09))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    self.tint.opacity(self.presentation.visualState == .normal ? 0.12 : 0.44),
                    lineWidth: 1)
        }
        .shadow(
            color: self.presentation.visualState == .overdue ? .red.opacity(0.10) : .black.opacity(0.045),
            radius: 4,
            y: 1)
        .animation(.spring(response: 0.35, dampingFraction: 1), value: self.presentation.visualState)
    }

    private var cardHeader: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(self.projectColor.gradient)
                Text(self.projectInitials)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)

            Text(self.project.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .help(self.project.name)

            Spacer(minLength: 2)

            Text("\(self.cadence.completed)/\(self.cadence.target)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)

            Menu {
                Button("Project Settings…", systemImage: "gearshape", action: self.onSettings)
                Divider()
                if let path = self.project.folderPath {
                    Button("Reveal in Finder", systemImage: "folder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    Divider()
                }
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
                    .frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Project actions")
        }
    }

    private var statusLine: some View {
        HStack(spacing: 5) {
            Image(systemName: self.presentation.statusSymbol)
                .symbolRenderingMode(.hierarchical)
            Text(self.presentation.statusText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(self.tint)
        .help(self.presentation.statusText)
    }

    @ViewBuilder
    private var actionButton: some View {
        if self.presentation.isActionProminent {
            self.actionControl
                .buttonStyle(.borderedProminent)
        } else {
            self.actionControl
                .buttonStyle(.bordered)
        }
    }

    private var actionControl: some View {
        Button {
            self.store.startOrCompleteRun(forProjectID: self.project.id)
        } label: {
            Label(self.presentation.actionTitle, systemImage: self.presentation.actionSymbol)
                .frame(maxWidth: .infinity)
                .contentTransition(.symbolEffect(.replace))
        }
        .controlSize(.small)
        .tint(self.presentation.visualState == .active ? .green : self.tint)
        .animation(.spring(response: 0.3, dampingFraction: 1), value: self.presentation.actionTitle)
        .help(self.project.activeRun == nil
            ? "Start an agent run. Tap again when it is complete."
            : "Confirm this agent run is complete.")
    }

    private var projectInitials: String {
        let words = self.project.name.split(separator: " ").prefix(2)
        let initials = words.compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "P" : initials.uppercased()
    }

    private var projectColor: Color {
        let palette: [Color] = [.blue, .purple, .teal, .indigo, .orange, .pink, .mint]
        let value = self.project.id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 997 }
        return palette[value % palette.count]
    }

    private func relativeDescription(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: self.store.now)
    }

    private func elapsedDescription(_ date: Date) -> String {
        let elapsed = max(0, self.store.now.timeIntervalSince(date))
        if elapsed < 60 {
            return "now"
        }
        if elapsed < 3600 {
            return "\(Int(elapsed / 60))m"
        }
        return "\(Int(elapsed / 3600))h"
    }

    private func timeDescription(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private struct CadenceProgressView: View {
    let snapshot: CadenceSnapshot
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let completedWidth = width * self.snapshot.completionProgress
            let expectedX = width * self.snapshot.expectedProgress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.08))
                if self.snapshot.behind > 0 {
                    Capsule()
                        .fill(.red.opacity(0.20))
                        .frame(width: max(0, expectedX - completedWidth))
                        .offset(x: completedWidth)
                }
                if completedWidth > 0 {
                    Capsule()
                        .fill(self.tint.gradient)
                        .frame(width: completedWidth)
                }
                Rectangle()
                    .fill(.primary.opacity(0.58))
                    .frame(width: 1.5, height: 9)
                    .offset(x: max(0, min(width - 1.5, expectedX - 0.75)))
            }
        }
        .frame(height: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(self.snapshot.completed) of \(self.snapshot.target) completed; \(self.snapshot.expected) expected now")
    }
}

private struct TodaySummaryMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(self.value)
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(self.color)
            Text(self.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProjectNameEditorRequest: Identifiable {
    let id = UUID()
    let projectID: UUID?
    let title: String
    let actionTitle: String
    let initialName: String

    static let newProject = ProjectNameEditorRequest(
        projectID: nil,
        title: "New Project",
        actionTitle: "Add Project",
        initialName: "")

}

private struct ProjectNameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    let title: String
    let actionTitle: String
    let onSave: (String) -> Void

    init(title: String, actionTitle: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(self.title)
                .font(.title3.weight(.semibold))
            TextField("Project name", text: self.$name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(self.save)
            HStack {
                Spacer()
                Button("Cancel") {
                    self.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(self.actionTitle, action: self.save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func save() {
        let name = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        self.onSave(name)
        self.dismiss()
    }
}

private struct ProjectSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var dailyTarget: Double

    let project: ProjectRecord
    let onSave: (String, Int) -> Void

    init(project: ProjectRecord, onSave: @escaping (String, Int) -> Void) {
        self.project = project
        self.onSave = onSave
        _name = State(initialValue: project.name)
        _dailyTarget = State(initialValue: Double(project.dailyRunTarget))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project Settings")
                        .font(.title3.weight(.semibold))
                    Text("Cadence and project details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Name")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Project name", text: self.$name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily agent target")
                            .font(.body.weight(.medium))
                        Text("Expected completed runs between 10:00 and 20:00")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(self.dailyTarget))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                        .frame(minWidth: 38)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                Slider(
                    value: self.$dailyTarget,
                    in: Double(ProjectStore.dailyTargetRange.lowerBound)...Double(ProjectStore.dailyTargetRange.upperBound),
                    step: 1)
                    .accessibilityLabel("Daily agent run target")
                    .accessibilityValue("\(Int(self.dailyTarget))")

                Text(self.cadenceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let folderPath = self.project.folderPath {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Project folder")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(folderPath)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    self.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    self.save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 460)
    }

    private var cadenceDescription: String {
        let secondsPerRun = 10 * 60 * 60 / max(1, Int(self.dailyTarget))
        if secondsPerRun >= 60 {
            let minutes = max(1, Int((Double(secondsPerRun) / 60).rounded()))
            return "ProjectBar will pace this at roughly one run every \(minutes) minute\(minutes == 1 ? "" : "s")."
        }
        return "ProjectBar will pace this at roughly one run every \(secondsPerRun) seconds."
    }

    private func save() {
        let name = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        self.onSave(name, Int(self.dailyTarget.rounded()))
        self.dismiss()
    }
}
