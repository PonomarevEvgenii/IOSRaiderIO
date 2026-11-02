import SwiftUI

struct SpecListView: View {
    let gameClass: GameClass

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 48

    var body: some View {
        ScrollView {
            GlassGroup(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(gameClass.specs) { spec in
                        NavigationLink(value: Route.spec(SpecSelection(gameClass: gameClass, spec: spec))) {
                            HStack(spacing: 14) {
                                WowIconView(name: spec.icon, size: iconSize, cornerRadius: iconSize / 2)
                                    .overlay(Circle().stroke(gameClass.color, lineWidth: 2))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(spec.name)
                                        .font(.headline)
                                    Label(spec.role.title, systemImage: spec.role.systemImage)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .liquidGlass(tint: gameClass.color.opacity(0.25))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .screenBackground(gameClass.color)
        .navigationTitle(gameClass.name)
    }
}

#Preview {
    NavigationStack {
        SpecListView(gameClass: SpecSelection.previewHolyPaladin.gameClass)
    }
}
