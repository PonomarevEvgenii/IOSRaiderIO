import SwiftUI

struct FavoritesView: View {
    @Environment(BuildStore.self) private var store

    var body: some View {
        // Displayed sorted by name; deletion maps offsets of *this* array to ids.
        let sorted = store.favorites.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        Group {
            if sorted.isEmpty {
                ContentUnavailableView(
                    "No favorites",
                    systemImage: "star",
                    description: Text("Tap the star next to a player to keep them here.")
                )
            } else {
                List {
                    ForEach(sorted) { player in
                        let color = store.gameClass(id: player.classId)?.color ?? .gray
                        NavigationLink(value: Route.player(player)) {
                            FavoriteRow(player: player, classIcon: store.gameClass(id: player.classId)?.icon, color: color)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [color.opacity(0.75), color.opacity(0.25), color.opacity(0.05)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(color.opacity(0.6), lineWidth: 1))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                        )
                    }
                    .onDelete { offsets in
                        store.removeFavorites(ids: offsets.map { sorted[$0].id })
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .screenBackground(.yellow)
        .navigationTitle("Favorites")
    }
}

private struct FavoriteRow: View {
    let player: TopPlayer
    let classIcon: String?
    let color: Color

    @Environment(BuildStore.self) private var store
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 46

    /// Score saved with the favorite, or the fresher one if the profile was loaded this session.
    private var score: Double? {
        store.cachedProfile(for: player.key)?.score ?? player.score
    }

    var body: some View {
        HStack(spacing: 12) {
            WowIconView(name: classIcon, size: iconSize, cornerRadius: iconSize / 2)
                .overlay(Circle().stroke(color, lineWidth: 2))
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.headline)
                Text("\(player.specName) \(player.className) · \(player.realmName) · \(player.regionShortName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let score {
                        Label("RIO \(score.formatted(.number.precision(.fractionLength(1))))", systemImage: "chart.bar.fill")
                    }
                    Text("Best +\(player.bestKeyLevel)")
                    if let rank = player.rank {
                        Text("#\(rank)")
                    }
                }
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview("With favorites") {
    NavigationStack {
        FavoritesView()
    }
    .environment(BuildStore.preview(favorites: [.previewFixturePlayer]))
}

#Preview("Empty") {
    NavigationStack {
        FavoritesView()
    }
    .environment(BuildStore.preview())
}
