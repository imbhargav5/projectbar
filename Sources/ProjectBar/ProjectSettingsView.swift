import ProjectBarCore
import SwiftUI

struct ProjectSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var targetText: String
    @State private var cadencePeriod: CadencePeriod

    let project: ProjectRecord
    let onSave: (String, Int, CadencePeriod) -> Void

    init(project: ProjectRecord, onSave: @escaping (String, Int, CadencePeriod) -> Void) {
        self.project = project
        self.onSave = onSave
        _name = State(initialValue: project.name)
        _targetText = State(initialValue: String(project.runTarget))
        _cadencePeriod = State(initialValue: project.cadencePeriod)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProjectSettingsHeading(
                title: "Project Settings", subtitle: "Cadence and project details", symbol: "slider.horizontal.3")

            VStack(alignment: .leading, spacing: 7) {
                Text("Name")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Project name", text: self.$name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cadence")
                            .font(.body.weight(.medium))
                        Text("Choose when this project's target resets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Cadence", selection: self.$cadencePeriod) {
                        ForEach(CadencePeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .accessibilityLabel("Cadence period")
                }

                Divider()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(self.cadencePeriod.displayName) agent target")
                            .font(.body.weight(.medium))
                        Text(self.targetDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("Target", text: self.$targetText)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .frame(width: 58)
                            .accessibilityLabel("\(self.cadencePeriod.displayName) run target")
                            .accessibilityHint("Enter a whole number from 1 to 200")
                        Stepper("Adjust target", value: self.targetBinding, in: ProjectTargetInput.range)
                            .labelsHidden()
                            .accessibilityLabel("Adjust run target")
                            .accessibilityValue(self.targetText)
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(self.targetBinding.wrappedValue) },
                        set: { self.targetText = String(Int($0.rounded())) }),
                    in: Double(ProjectStore.targetRange.lowerBound)...Double(ProjectStore.targetRange.upperBound),
                    step: 1)
                    .accessibilityLabel("\(self.cadencePeriod.displayName) agent run target")
                    .accessibilityValue(self.targetText)

                if self.target == nil {
                    Label("Enter a whole number from 1 to 200.", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(self.cadenceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .modifier(ProjectSurface())

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
                .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.target == nil)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(ProjectBarStyle.canvas)
    }

    private var targetDescription: String {
        switch self.cadencePeriod {
        case .daily:
            "Expected completed runs between 10:00 and 20:00 each day"
        case .weekly:
            "Expected runs across this local week, within 10:00–20:00 each day"
        }
    }

    private var target: Int? {
        ProjectTargetInput.value(from: self.targetText)
    }

    private var targetBinding: Binding<Int> {
        Binding(
            get: { self.target ?? min(ProjectTargetInput.range.upperBound, max(ProjectTargetInput.range.lowerBound, self.project.runTarget)) },
            set: { self.targetText = String($0) })
    }

    private var cadenceDescription: String {
        guard let target = self.target else { return "Choose a target to preview your cadence." }
        let workHours = self.cadencePeriod == .daily ? 10 : 70
        let secondsPerRun = workHours * 60 * 60 / target
        if secondsPerRun >= 3600 {
            let hours = max(1, Int((Double(secondsPerRun) / 3600).rounded()))
            return "ProjectBar will pace this at roughly one run every \(hours) working hour\(hours == 1 ? "" : "s")."
        }
        if secondsPerRun >= 60 {
            let minutes = max(1, Int((Double(secondsPerRun) / 60).rounded()))
            return "ProjectBar will pace this at roughly one run every \(minutes) working minute\(minutes == 1 ? "" : "s")."
        }
        return "ProjectBar will pace this at roughly one run every \(secondsPerRun) working seconds."
    }

    private func save() {
        let name = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let target = self.target else { return }
        self.onSave(name, target, self.cadencePeriod)
        self.dismiss()
    }
}
