import SwiftUI

struct TopPlayersView: View {
    let selection: SpecSelection
    let result: SpecResult
    let region: RegionFilter

    var body: some View {
        if result.players.isEmpty {
            ContentUnavailableView(
                "No players found",
                systemImage: "person.slash",
                description: Text("The \(region.title) Mythic+ leaderboard has no \(selection.spec.name) \(selection.gameClass.name) this season.")
            )
        } else {
            ScrollView {
                GlassGroup(spacing: 10) {
                    VStack(spacing: 10) {
                        ForEach(result.players) { player in
                            NavigationLink(value: Route.player(player)) {
                                PlayerRow(player: player, rank: player.rank, tint: selection.gameClass.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    private var footer: String {
        let base = "Top \(result.players.count) \(selection.spec.name) \(selection.gameClass.name) players by Mythic+ score in \(region.title)."
        return result.players.count < result.requestedCount
            ? base + " The leaderboard has only \(result.players.count) this season."
            : base
    }
}

struct PlayerRow: View {
    let player: TopPlayer
    var rank: Int?
    var tint: Color = .accentColor

    @Environment(BuildStore.self) private var store
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 48

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .frame(minWidth: 28)
                    .foregroundStyle(tint)
            }
            CharacterAvatar(
                url: store.cachedProfile(for: player.key)?.thumbnailUrl,
                fallbackIcon: store.gameClass(id: player.classId)?.icon,
                tint: tint,
                size: avatarSize
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.headline)
                Text("\(player.realmName) · \(player.regionShortName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("+\(player.bestKeyLevel)")
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tint.opacity(0.3), in: Capsule())
                    if let score = player.score ?? store.cachedProfile(for: player.key)?.score {
                        Text("Score \(score.formatted(.number.precision(.fractionLength(1))))")
                    }
                }
                .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 8)
            FavoriteButton(player: player)
        }
        .padding(14)
        .liquidGlass()
    }
}

/// Toggles the favorite in the store (not in a local copy).
struct FavoriteButton: View {
    let player: TopPlayer

    @Environment(BuildStore.self) private var store

    var body: some View {
        let isFavorite = store.isFavorite(player.id)
        Button {
            store.toggleFavorite(player)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? .yellow : .secondary)
                .imageScale(.large)
        }
        // Borderless so tapping the star doesn't trigger the row's NavigationLink.
        .buttonStyle(.borderless)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

#Preview {
    NavigationStack {
        SpecDetailView(selection: .previewHolyPaladin)
    }
    .environment(BuildStore.preview())
}
