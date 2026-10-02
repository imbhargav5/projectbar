import AppKit
import SwiftUI

/// Semantic macOS surfaces shared by the board and its sheets.
enum ProjectBarStyle {
    static let canvas = adaptiveGray(light: 0.96, dark: 0.12)
    static let surface = adaptiveGray(light: 1, dark: 0.17)

    private static func adaptiveGray(light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(
                calibratedWhite: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light,
                alpha: 1)
        })
    }
}

struct ProjectSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    var radius: CGFloat = 10
    var emphasized = false
    var selected = false

    func body(content: Content) -> some View {
        content
            .background(ProjectBarStyle.surface, in: RoundedRectangle(cornerRadius: self.radius))
            .overlay {
                RoundedRectangle(cornerRadius: self.radius)
                    .strokeBorder(
                        self.selected ? Color.accentColor : Color.primary.opacity(self.contrast == .increased ? 0.3 : 0.1),
                        lineWidth: self.selected ? 2 : 0.5)
            }
            .shadow(color: .black.opacity(self.colorScheme == .dark ? 0.12 : 0.045), radius: 3, x: 0, y: 2)
            .overlay {
                if self.emphasized && !self.selected {
                    RoundedRectangle(cornerRadius: self.radius)
                        .strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 1)
                }
            }
    }
}

struct ProjectSettingsHeading: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(self.title).font(.system(size: 18, weight: .semibold))
                Text(self.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
