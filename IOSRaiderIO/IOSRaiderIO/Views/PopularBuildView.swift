import SwiftUI

struct PopularBuildView: View {
    let selection: SpecSelection
    let result: SpecResult

    @Environment(BuildStore.self) private var store
    @State private var copiedBuild = false

    private var build: PopularBuild { result.build }
    private var tint: Color { selection.gameClass.color }

    var body: some View {
        if build.playersCounted == 0 {
            ContentUnavailableView(
                "No talent data",
                systemImage: "list.bullet.rectangle",
                description: Text(emptyDescription)
            )
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    treeStatus
                    ForEach(build.groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.tree == .heroTree ? (build.heroTrees.first?.name ?? group.tree.title) : group.tree.title)
                                .font(.headline)
                            TalentTreeView(
                                nodes: TalentTreeBuilder.popularNodes(
                                    tree: group.tree,
                                    rates: group.rates,
                                    fullTree: store.talentTrees[selection.spec.id],
                                    heroTreeId: build.mostCommonHeroTreeId
                                ),
                                tint: tint
                            )
                        }
                        .padding()
                        .cardBackground()
                    }
                }
                .padding()
            }
            .task { await store.loadTalentTrees() }
            .task(id: copiedBuild) {
                guard copiedBuild else { return }
                try? await Task.sleep(for: .seconds(2))
                copiedBuild = false
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary)
                .font(.subheadline)
            ForEach(build.heroTrees) { hero in
                LabeledContent(hero.name, value: "\(hero.count) of \(build.playersCounted)")
                    .font(.subheadline)
            }
            if let string = build.mostCommonImportString {
                Text("Most common exact build: \(build.mostCommonImportStringCount) of \(build.playersCounted) players")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Clipboard.copy(string)
                    copiedBuild = true
                } label: {
                    Label(copiedBuild ? "Copied" : "Copy this talent string",
                          systemImage: copiedBuild ? "checkmark" : "doc.on.doc")
                }
                .glassButtonStyle(prominent: true)
                .tint(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardBackground(tint: tint)
    }

    @ViewBuilder
    private var treeStatus: some View {
        if let error = store.talentTreesError {
            Label("Full talent trees unavailable (\(Text(error.title))). Showing picked talents only.",
                  systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .padding()
                .cardBackground(tint: .orange)
        } else if store.talentTrees.isEmpty {
            ProgressView("Loading talent trees…")
                .font(.footnote)
        }
    }

    private var summary: String {
        var text = "Pick rates from \(build.playersCounted) of \(result.players.count) players. Colored talents and lines = picked by at least half of them."
        if build.playersSkipped > 0 {
            text += " \(build.playersSkipped) skipped: no talent data, or their current talents are for another spec."
        }
        return text
    }

    private var emptyDescription: String {
        if result.players.isEmpty {
            return "The leaderboard has no \(selection.spec.name) players for this region."
        }
        return "None of the \(result.players.count) players has current \(selection.spec.name) talent data on Raider.IO (\(build.playersSkipped) skipped)."
    }
}

#Preview {
    NavigationStack {
        SpecDetailView(selection: .previewHolyPaladin)
    }
    .environment(BuildStore.preview())
}
