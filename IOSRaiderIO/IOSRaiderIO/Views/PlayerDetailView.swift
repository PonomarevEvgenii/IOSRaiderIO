import SwiftUI

struct PlayerDetailView: View {
    let player: TopPlayer

    @Environment(BuildStore.self) private var store
    @State private var showCopiedConfirmation = false
    /// Bumped by "Retry" so the `.task(id:)` below restarts.
    @State private var reloadToken = 0

    private struct LoadKey: Hashable {
        let playerId: String
        let reloadToken: Int
    }

    private var tint: Color { store.gameClass(id: player.classId)?.color ?? .accentColor }

    var body: some View {
        content
            .screenBackground(tint)
            .navigationTitle(player.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    FavoriteButton(player: player)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showCopiedConfirmation {
                    Label("Talent string copied", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .liquidGlass(tint: .green.opacity(0.3), in: Capsule())
                        .padding(.bottom, 8)
                }
            }
            .task(id: LoadKey(playerId: player.id, reloadToken: reloadToken)) {
                await store.loadProfile(for: player.key)
            }
            .task { await store.loadTalentTrees() }
            .task(id: showCopiedConfirmation) {
                guard showCopiedConfirmation else { return }
                try? await Task.sleep(for: .seconds(2))
                showCopiedConfirmation = false
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.profileState(for: player.key) {
        case .idle, .loading:
            LoadingStateView(progress: LoadProgress(message: "Loading talents…", completed: 0, total: 0))
        case .failed(let error):
            ErrorStateView(error: error) { reloadToken += 1 }
        case .loaded(let profile):
            loaded(profile)
        }
    }

    private func loaded(_ profile: CharacterProfile) -> some View {
        let talents = profile.talents
        return ScrollView {
            // Lazy: trees below the fold aren't built until scrolled to.
            LazyVStack(spacing: 16) {
                CharacterAvatar(url: profile.thumbnailUrl, fallbackIcon: store.gameClass(id: player.classId)?.icon,
                                tint: tint, size: 96)
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Realm", value: "\(player.realmName) · \(player.regionShortName)")
                    LabeledContent("Spec", value: "\(player.specName) \(player.className)")
                    LabeledContent("Best key", value: "+\(player.bestKeyLevel)")
                    if let score = profile.score {
                        LabeledContent("M+ score", value: score.formatted(.number.precision(.fractionLength(1))))
                    }
                    if let hero = talents.heroTreeName {
                        LabeledContent("Hero talents", value: hero)
                    }
                }
                .font(.subheadline)
                .padding()
                .cardBackground(tint: tint)

                GlassGroup(spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { actionButtons(talents: talents, profile: profile) }
                        VStack(spacing: 12) { actionButtons(talents: talents, profile: profile) }
                    }
                }
                if talents.importString == nil {
                    Text("Raider.IO has no talent string for this character.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !talents.hasTalents {
                    ContentUnavailableView(
                        "No talent data",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Raider.IO has no talent data for this character.")
                    )
                } else {
                    if talents.specId != player.specId, let currentSpec = profile.activeSpecName {
                        Label("These are the character's current talents, which are for \(currentSpec), not \(player.specName).",
                              systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .padding()
                            .cardBackground(tint: .orange)
                    }
                    ForEach(TalentTree.allCases) { tree in
                        let picks = talents.picks(in: tree)
                        if !picks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(tree == .heroTree ? (talents.heroTreeName ?? tree.title) : tree.title)
                                    .font(.headline)
                                TalentTreeView(
                                    nodes: TalentTreeBuilder.playerNodes(
                                        tree: tree,
                                        picks: picks,
                                        fullTree: store.talentTrees[talents.specId ?? player.specId],
                                        heroTreeId: talents.heroTreeId
                                    ),
                                    tint: tint
                                )
                            }
                            .padding()
                            .cardBackground()
                        }
                    }
                }

                BestKeysSection(runs: profile.mythicPlusBestRuns ?? [], tint: tint)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func actionButtons(talents: PlayerTalents, profile: CharacterProfile) -> some View {
        Button {
            if let string = talents.importString {
                Clipboard.copy(string)
                showCopiedConfirmation = true
            }
        } label: {
            Label("Copy talent string", systemImage: "doc.on.doc")
                .frame(maxWidth: .infinity)
        }
        .glassButtonStyle(prominent: true)
        .tint(tint)
        .disabled(talents.importString == nil)

        if let url = profile.profileUrl ?? player.key.raiderIOURL {
            Link(destination: url) {
                Label("Open on Raider.IO", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .glassButtonStyle()
        }
    }
}

#Preview {
    NavigationStack {
        PlayerDetailView(player: .previewFixturePlayer)
    }
    .environment(BuildStore.preview())
}
