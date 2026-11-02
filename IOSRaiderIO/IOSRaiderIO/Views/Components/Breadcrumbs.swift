import SwiftUI

/// Every screen that can be pushed onto a navigation stack.
enum Route: Hashable {
    case gameClass(GameClass)
    case spec(SpecSelection)
    case player(TopPlayer)

    var title: String {
        switch self {
        case .gameClass(let gameClass): gameClass.name
        case .spec(let selection): selection.spec.name
        case .player(let player): player.name
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .gameClass(let gameClass): SpecListView(gameClass: gameClass)
        case .spec(let selection): SpecDetailView(selection: selection)
        case .player(let player): PlayerDetailView(player: player)
        }
    }
}

/// "Classes › Warrior › Arms › Crimsfeel". One instance per stack (see `breadcrumbOverlay`), so it stays
/// in place while screens change and crumbs slide in/out instead of the whole bar jumping.
/// Tapping a crumb pops back to that level.
struct BreadcrumbBar: View {
    let rootTitle: String
    /// Binding because tapping a crumb must change the stack's path, which `RootTabView` owns.
    @Binding var path: [Route]

    private var crumbs: [(level: Int, title: String)] {
        [(0, rootTitle)] + path.enumerated().map { ($0.offset + 1, $0.element.title) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(crumbs, id: \.level) { crumb in
                        HStack(spacing: 4) {
                            if crumb.level > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            crumbButton(crumb.title, level: crumb.level)
                        }
                        .id(crumb.level)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading))
                        ))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            // Content starts at the left edge; only when the path is too long does it scroll
            // to keep the current screen visible.
            .onChange(of: path.count) { _, count in
                withAnimation(.snappy) { proxy.scrollTo(count, anchor: .trailing) }
            }
        }
        .liquidGlass(in: Capsule())
        .fixedSize(horizontal: false, vertical: true)
        .animation(.snappy(duration: 0.3), value: path)
    }

    private func crumbButton(_ title: String, level: Int) -> some View {
        let isCurrent = level == path.count
        return Button {
            path.removeLast(path.count - level)
        } label: {
            Text(title)
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
        .accessibilityLabel(isCurrent ? "\(title), current screen" : "Back to \(title)")
    }
}

extension View {
    /// Compact (inline) navigation bar without a title: the shared `BreadcrumbBar` shows where we are.
    func breadcrumbHeader() -> some View {
        self
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            // Back button shows only the chevron.
            .toolbarRole(.editor)
            .toolbar {
                // Empty principal item hides the per-screen title under the shared bar.
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
            }
    }

    /// Pins one `BreadcrumbBar` in the navigation bar row of a stack, between the back button
    /// and the trailing toolbar buttons.
    func breadcrumbOverlay(rootTitle: String, path: Binding<[Route]>) -> some View {
        overlay(alignment: .top) {
            BreadcrumbBar(rootTitle: rootTitle, path: path)
                .padding(.horizontal, 70)
                .frame(height: 44)
        }
    }
}

#Preview("Path to a player") {
    @Previewable @State var path: [Route] = [
        .gameClass(SpecSelection.previewHolyPaladin.gameClass),
        .spec(.previewHolyPaladin),
        .player(.previewFixturePlayer),
    ]
    NavigationStack(path: $path) {
        Text("Classes")
            .breadcrumbHeader()
            .navigationDestination(for: Route.self) { route in
                route.destination.breadcrumbHeader()
            }
    }
    .breadcrumbOverlay(rootTitle: "Classes", path: $path)
    .environment(BuildStore.preview())
}
