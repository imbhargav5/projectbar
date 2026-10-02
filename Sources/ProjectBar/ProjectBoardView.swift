import AppKit
import ProjectBarCore
import SwiftUI

@MainActor
struct ProjectBoardView: View {
    let store: ProjectStore
    let launchAtLogin: LaunchAtLoginManager
    let onClose: () -> Void
    let onShow: () -> Void
    let preferences: ProjectBoardPreferences
    let folderActions: ProjectFolderActions
    @State private var interaction: ProjectBoardInteraction

    @State private var nameEditor: ProjectNameEditorRequest?
    @State private var settingsProject: ProjectRecord?
    @State private var pendingRemoval: ProjectRecord?
    @State private var showingAppSettings = false

    @State private var showingFilePanel = false
    @State private var addedProjectToFocus: UUID?
    @FocusState private var focusedField: BoardFocus?

    private enum BoardFocus: Hashable {
        case search
        case project(UUID)
    }

    init(
        store: ProjectStore, launchAtLogin: LaunchAtLoginManager,
        preferences: ProjectBoardPreferences = ProjectBoardPreferences(),
        interaction: ProjectBoardInteraction = ProjectBoardInteraction(),
        folderActions: ProjectFolderActions = ProjectFolderActions(),
        onShow: @escaping () -> Void = {}, onClose: @escaping () -> Void)
    {
        self.store = store
        self.launchAtLogin = launchAtLogin
        self.preferences = preferences
        self.folderActions = folderActions
        self.onShow = onShow
        self.onClose = onClose
        _interaction = State(initialValue: interaction)
    }

    private var gridFocused: Bool {
        if case .project = self.focusedField { return true }
        return false
    }

    private var shortcutsEnabled: Bool {
        self.nameEditor == nil && self.settingsProject == nil && self.pendingRemoval == nil &&
            !self.showingAppSettings && !self.showingFilePanel
    }
    @Environment(\.colorScheme) private var colorScheme

    private var board: ProjectBoardPresentation {
        ProjectBoardPresentation(projects: self.store.projects, now: self.store.now)
    }

    private var visibleProjects: [ProjectRecord] {
        self.board.projects(matching: self.interaction.query, filter: self.interaction.filter, pinnedIDs: self.preferences.pinnedProjectIDs)
    }

    var body: some View {
        GeometryReader { geometry in
            let renderedProjects = self.visibleProjects
            VStack(spacing: 0) {
                self.header(width: geometry.size.width)
                if !self.store.projects.isEmpty {
                    self.navigation
                }
                Divider()
                Group {
                    if self.store.projects.isEmpty {
                        self.emptyState
                    } else if self.visibleProjects.isEmpty {
                        self.noMatches
                    } else {
                        self.projectGrid(width: geometry.size.width)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ProjectBarStyle.canvas)
                self.feedback
                Divider()
                self.footer
            }
            .background(.bar)
            .background {
                ProjectBoardKeyboard(enabled: self.shortcutsEnabled, gridFocused: self.gridFocused) { command in
                    self.handle(command, width: geometry.size.width, renderedProjects: renderedProjects)
                }
                .frame(width: 0, height: 0)
            }
        }
        .onAppear {
            self.cleanUpPins()
            self.focusedField = self.interaction.selectedProjectID.map(BoardFocus.project) ?? .search
        }
        .onChange(of: self.store.projects.map(\.id)) { _, _ in self.cleanUpPins() }
        .onChange(of: self.focusedField) { _, focus in
            if case let .project(id) = focus { self.interaction.selectedProjectID = id }
        }
        .onChange(of: self.visibleProjects.map(\.id)) { previous, current in
            let selectedWasRemoved = self.interaction.selectedProjectID.map { previous.contains($0) && !current.contains($0) } ?? false
            let restoreGridFocus = self.shortcutsEnabled &&
                (self.gridFocused || (self.focusedField == nil && selectedWasRemoved))
            self.interaction.reconcileSelection(previous: previous, current: current)
            if restoreGridFocus {
                self.focusedField = self.interaction.selectedProjectID.map(BoardFocus.project) ?? .search
            }
        }
        .sheet(item: self.$nameEditor, onDismiss: self.focusAddedProject) { request in
            ProjectNameEditorView(
                title: request.title,
                actionTitle: request.actionTitle,
                initialName: request.initialName)
            { name in
                if let projectID = request.projectID {
                    self.store.renameProject(id: projectID, to: name)
                } else {
                    self.revealNewProjects { self.store.addProject(name: name) }
                }
            }
        }
        .sheet(item: self.$settingsProject) { project in
            ProjectSettingsView(project: project) { name, target, cadencePeriod in
                self.store.renameProject(id: project.id, to: name)
                self.store.setCadence(cadencePeriod, target: target, forProjectID: project.id)
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

    private func header(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if width >= 400 {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ProjectBar")
                        .font(.system(size: 17, weight: .semibold))
                        .fixedSize()
                    if width >= 400 {
                        Text("Your project workspace")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                self.addProjectMenu
                Menu {
                    Menu("Card density") {
                        ForEach(ProjectCardDensity.allCases) { density in
                            Button {
                                self.preferences.density = density
                            } label: {
                                if self.preferences.density == density {
                                    Label(density.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(density.rawValue)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Settings…", systemImage: "gearshape") {
                        self.showingAppSettings = true
                    }
                    Button("About ProjectBar") {
                        NSApp.orderFrontStandardAboutPanel(options: [
                            .applicationName: "ProjectBar",
                            .applicationVersion: "0.1.0",
                            .credits: NSAttributedString(string: "A calm cadence for agent work."),
                        ])
                    }
                    Divider()
                    Button("Quit ProjectBar") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: 26, height: 28)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .foregroundStyle(.secondary)
                .fixedSize()
                .accessibilityLabel("ProjectBar options")
                .help("Settings and application options")
                Button(action: self.onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Close ProjectBar")
                .help("Close ProjectBar")
            }

            if !self.store.projects.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 20) {
                        self.periodSummaries
                        Spacer(minLength: 0)
                        self.activitySummary
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        self.periodSummaries
                        self.activitySummary
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var addProjectMenu: some View {
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
            Label("Add", systemImage: "plus")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .modifier(ProjectSurface(radius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Add project")
    }

    private var periodSummaries: some View {
        HStack(spacing: 20) {
            ForEach(self.board.summaries) { summary in
                HStack(spacing: 9) {
                    Image(systemName: summary.period == .daily ? "sun.max" : "calendar")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.period == .daily ? "Today" : "This week")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(summary.completed)")
                                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                            Text("/ \(summary.target)")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(summary.period.displayName) projects: \(summary.completed) of \(summary.target) runs completed \(summary.intervalLabel)")
            }
        }
    }

    private var activitySummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            if self.board.runsBehind > 0 {
                Button { self.interaction.filter = .behind } label: {
                    Label("\(self.board.runsBehind) behind pace", systemImage: "clock.badge.exclamationmark")
                }
                    .buttonStyle(.plain)
                    .accessibilityHint("Show projects behind pace")
                    .foregroundStyle(ProjectStatusColor.behind(in: self.colorScheme))
                    .help("Completed runs below the expected cadence. Runs in progress are not completed yet.")
            }
            if self.board.runningCount > 0 {
                Button { self.interaction.filter = .running } label: {
                    Label("\(self.board.runningCount) running", systemImage: "bolt.horizontal.circle")
                }
                    .buttonStyle(.plain)
                    .accessibilityHint("Show running projects")
                    .foregroundStyle(.tint)
            }
            if self.board.runsBehind == 0 && self.board.runningCount == 0 {
                Label("On pace", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .fixedSize()
    }

    private var navigation: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                self.filterControls
                self.searchField.frame(minWidth: 170)
            }
            VStack(alignment: .leading, spacing: 10) {
                self.searchField
                ViewThatFits(in: .horizontal) {
                    self.filterControls
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
                        ForEach(ProjectBoardFilter.allCases) { self.filterButton($0) }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var filterControls: some View {
        HStack(spacing: 2) {
            ForEach(ProjectBoardFilter.allCases) { self.filterButton($0) }
        }
        .padding(3)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        .fixedSize()
    }

    private func filterButton(_ candidate: ProjectBoardFilter) -> some View {
        let count = self.board.projects(matching: self.interaction.query, filter: candidate).count
        return Button {
            self.interaction.filter = candidate
        } label: {
            HStack(spacing: 5) {
                Text(candidate.rawValue)
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(self.interaction.filter == candidate ? .primary : .secondary)
                    .opacity(0.65)
            }
            .font(.system(size: 12, weight: self.interaction.filter == candidate ? .semibold : .regular))
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                self.interaction.filter == candidate ? ProjectBarStyle.surface : .clear,
                in: RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(self.interaction.filter == candidate ? 0.08 : 0), radius: 1, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(candidate.rawValue), \(count) projects")
        .help("\(candidate.rawValue) projects · ⌘\((ProjectBoardFilter.allCases.firstIndex(of: candidate) ?? 0) + 1)")
        .accessibilityAddTraits(self.interaction.filter == candidate ? [.isSelected] : [])
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search projects", text: self.$interaction.query)
                .textFieldStyle(.plain)
                .focused(self.$focusedField, equals: .search)
                .onSubmit(self.focusFirstResult)
                .accessibilityLabel("Search projects")
            if !self.interaction.query.isEmpty {
                Button {
                    self.interaction.query = ""
                    self.focusedField = .search
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(ProjectBarStyle.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(self.focusedField == .search ? Color.accentColor.opacity(0.65) : .primary.opacity(0.12), lineWidth: 1)
        }
    }

    private func projectGrid(width: CGFloat) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
            count: ProjectBoardLayout.columnCount(for: width))
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(self.visibleProjects) { project in
                        ProjectCardView(
                            project: project, store: self.store,
                            onSettings: { self.settingsProject = project },
                            onRemove: { self.pendingRemoval = project },
                            density: self.preferences.density,
                            isPinned: self.preferences.pinnedProjectIDs.contains(project.id),
                            isSelected: self.focusedField == .project(project.id),
                            onTogglePin: { self.preferences.togglePin(for: project.id) },
                            onRunAction: self.performRunAction,
                            onRevealFolder: self.revealFolder,
                            onCopyPath: self.copyFolderPath)
                            .id(project.id)
                            .focusable()
                            .focusEffectDisabled()
                            .focused(self.$focusedField, equals: .project(project.id))
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollPosition(id: self.$interaction.scrollAnchor, anchor: .top)
            .scrollIndicators(.visible)
            .onChange(of: self.interaction.selectedProjectID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
            .onChange(of: self.preferences.density) { _, _ in
                let anchor = self.interaction.scrollAnchor ?? self.interaction.selectedProjectID
                Task { @MainActor in
                    await Task.yield()
                    if let anchor { proxy.scrollTo(anchor, anchor: .top) }
                }
            }
            .onAppear {
                if let id = self.interaction.selectedProjectID { proxy.scrollTo(id) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("Make room for your next run")
                    .font(.title3.weight(.semibold))
                Text("Add projects, set daily or weekly targets, and mark runs as you work.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Add Project Folders…", systemImage: "folder.badge.plus") {
                self.chooseProjectFolders()
            }
            .buttonStyle(.borderedProminent)
            Button("Add by Name…") { self.nameEditor = .newProject }
                .buttonStyle(.link)
        }
        .padding(24)
    }

    private var noMatches: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No matching projects")
                .font(.title3.weight(.semibold))
            Text("Try another name or show all projects.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("Show all projects") {
                self.interaction.query = ""
                self.interaction.filter = .all
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }

    @ViewBuilder
    private var feedback: some View {
        if let error = self.store.lastPersistenceError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let message = self.interaction.folderMessage {
                Text(message).lineLimit(1).help(message)
                Spacer(minLength: 0)
                Button { self.interaction.folderMessage = nil } label: {
                    Image(systemName: "xmark").frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss folder message")
            } else if let notice = self.interaction.completionNotice,
                      self.store.project(withID: notice.projectID)?.completedRuns.contains(where: { $0.id == notice.runID }) == true
            {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ProjectStatusColor.complete(in: self.colorScheme))
                    .accessibilityHidden(true)
                Text("Run completed · \(notice.projectName)").lineLimit(1)
                    .help("Run completed for \(notice.projectName)")
                Spacer(minLength: 0)
                Button("Undo") {
                    self.store.undoCompletedRun(id: notice.runID, forProjectID: notice.projectID)
                    self.interaction.completionNotice = nil
                }
                .accessibilityLabel("Undo completion for \(notice.projectName)")
                Button { self.interaction.completionNotice = nil } label: {
                    Image(systemName: "xmark").frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss completion message")
            } else {
                Image(systemName: "clock").accessibilityHidden(true)
                Text("10:00–20:00 local")
                    .fixedSize()
                    .help("Cadence runs daily from 10:00 to 20:00. Weekly targets span all seven days.")
                Spacer()
                ViewThatFits(in: .horizontal) {
                    Text("⌘F Search · ⌘1–4 Filter · ⌘↩ Mark run").fixedSize()
                    Text("⌘F Search").fixedSize()
                    Text("⌘F").fixedSize()
                }
                .help("Return in search focuses the first result. Arrow keys move between cards. ⌘Return marks a run. Escape clears search or closes the board.")
                Spacer()
                Text("\(self.visibleProjects.count) of \(self.store.projects.count)")
                    .fixedSize()
                    .accessibilityLabel("\(self.visibleProjects.count) of \(self.store.projects.count) projects")
            }
        }
        .font(.system(size: 11))
        .controlSize(.small)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 36)
    }

    private func handle(_ command: ProjectBoardCommand, width: CGFloat, renderedProjects: [ProjectRecord]) {
        switch command {
        case .search: self.focusedField = .search
        case let .filter(filter): self.interaction.filter = filter
        case .escape:
            if !self.interaction.query.isEmpty {
                self.interaction.query = ""
                self.focusedField = .search
            } else { self.onClose() }
        case .activate:
            guard let id = self.interaction.selectedProjectID,
                  let project = renderedProjects.first(where: { $0.id == id }) else { return }
            self.performRunAction(project)
        case let .move(direction):
            self.interaction.move(direction, in: self.visibleProjects.map(\.id),
                                  columns: ProjectBoardLayout.columnCount(for: width))
            self.focusedField = self.interaction.selectedProjectID.map(BoardFocus.project) ?? .search
        }
    }

    private func focusFirstResult() {
        self.interaction.selectedProjectID = self.visibleProjects.first?.id
        self.focusedField = self.interaction.selectedProjectID.map(BoardFocus.project) ?? .search
    }

    private func performRunAction(_ project: ProjectRecord) {
        let runID = project.activeRun?.id
        guard self.store.performRunAction(forProjectID: project.id, expectedActiveRunID: runID) else { return }
        self.interaction.selectedProjectID = project.id
        if let runID {
            self.interaction.folderMessage = nil
            self.interaction.completionNotice = ProjectBoardInteraction.CompletionNotice(projectID: project.id, runID: runID, projectName: project.name)
            self.announce("Run completed for \(project.name). Undo is available in the footer.")
        }
    }

    private func revealFolder(_ path: String) {
        self.interaction.folderMessage = self.folderActions.revealFolder(at: path)
        if let message = self.interaction.folderMessage { self.announce(message) }
    }

    private func copyFolderPath(_ path: String) {
        self.folderActions.copy(path)
        self.interaction.folderMessage = "Folder path copied"
        self.announce("Folder path copied")
    }

    private func announce(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    private func cleanUpPins() {
        guard self.store.lastPersistenceError == nil else { return }
        self.preferences.retainPins(for: Set(self.store.projects.map(\.id)))
    }

    private func revealNewProjects(_ add: () -> Void) {
        let previous = Set(self.store.projects.map(\.id))
        add()
        if let id = self.interaction.revealAddedProjects(previous: previous, current: self.store.projects.map(\.id)) {
            self.addedProjectToFocus = id
            if self.nameEditor == nil { self.focusAddedProject() }
            self.onShow()
        }
    }

    private func focusAddedProject() {
        guard let id = self.addedProjectToFocus else { return }
        self.addedProjectToFocus = nil
        self.focusedField = .project(id)
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
        self.showingFilePanel = true
        panel.begin { response in
            self.showingFilePanel = false
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in
                self.revealNewProjects { self.store.addProjectFolders(urls) }
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
        self.showingFilePanel = true
        panel.begin { response in
            self.showingFilePanel = false
            guard response == .OK, let parentURL = panel.url else { return }
            Task { @MainActor in
                self.revealNewProjects { self.store.addChildProjectFolders(from: parentURL) }
            }
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
