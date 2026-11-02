import SwiftUI

struct ClassGridView: View {
    @Environment(BuildStore.self) private var store
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 52

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 14)]

    var body: some View {
        Group {
            if store.classes.isEmpty {
                ContentUnavailableView(
                    "Class data unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(store.classesLoadError ?? "classes.json is empty.")
                )
            } else {
                ScrollView {
                    GlassGroup(spacing: 14) {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(store.classes) { gameClass in
                                NavigationLink(value: Route.gameClass(gameClass)) {
                                    ClassTile(gameClass: gameClass, iconSize: iconSize)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .screenBackground(.purple)
        .navigationTitle("Classes")
    }
}

private struct ClassTile: View {
    let gameClass: GameClass
    let iconSize: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            WowIconView(name: gameClass.icon, size: iconSize, cornerRadius: iconSize / 2)
                .overlay(Circle().stroke(gameClass.color, lineWidth: 2))
            Text(gameClass.name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .liquidGlass(tint: gameClass.color.opacity(0.35))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    NavigationStack {
        ClassGridView()
    }
    .environment(BuildStore.preview())
}
