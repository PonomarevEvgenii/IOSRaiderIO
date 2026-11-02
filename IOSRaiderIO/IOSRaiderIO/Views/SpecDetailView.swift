import SwiftUI

struct SpecDetailView: View {
    let selection: SpecSelection

    @Environment(BuildStore.self) private var store
    @State private var tab: SpecTab = .players
    /// Bumped by "Retry" so the `.task(id:)` below restarts (and stays cancellable).
    @State private var reloadToken = 0

    private enum SpecTab: String, CaseIterable, Identifiable {
        case players = "Top players"
        case build = "Popular build"
        var id: String { rawValue }
    }

    private struct LoadKey: Hashable {
        let query: SpecQuery
        let reloadToken: Int
    }

    var body: some View {
        // The query includes the filters, and states are stored per query,
        // so changing spec or filters can never show the previous selection's data.
        let query = store.query(for: selection)

        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(SpecTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            Text("\(query.region.title) · top \(query.playerCount) players")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .liquidGlass(in: Capsule())
                .padding(.bottom, 8)

            content(for: store.specState(for: query), query: query)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .screenBackground(selection.gameClass.color)
        .navigationTitle("\(selection.spec.name) \(selection.gameClass.name)")
        // Cancelled automatically when the screen disappears or the query changes.
        .task(id: LoadKey(query: query, reloadToken: reloadToken)) {
            await store.loadSpec(query)
        }
    }

    @ViewBuilder
    private func content(for state: SpecLoadState, query: SpecQuery) -> some View {
        switch state {
        case .idle:
            LoadingStateView(progress: LoadProgress(message: "Starting…", completed: 0, total: 0))
        case .loading(let progress):
            LoadingStateView(progress: progress)
        case .failed(let error):
            ErrorStateView(error: error) { reloadToken += 1 }
        case .loaded(let result):
            switch tab {
            case .players:
                TopPlayersView(selection: selection, result: result, region: query.region)
            case .build:
                PopularBuildView(selection: selection, result: result)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SpecDetailView(selection: .previewHolyPaladin)
    }
    .environment(BuildStore.preview())
}
