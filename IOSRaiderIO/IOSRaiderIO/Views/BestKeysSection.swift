import SwiftUI

/// "Best keys" list on the player screen: best run per dungeon this season (Raider.IO `mythic_plus_best_runs`).
struct BestKeysSection: View {
    let runs: [BestRun]
    var tint: Color = .accentColor

    private var sorted: [BestRun] {
        runs.sorted {
            if $0.mythicLevel != $1.mythicLevel { return $0.mythicLevel > $1.mythicLevel }
            return ($0.score ?? 0) > ($1.score ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Best keys this season")
                .font(.headline)
            if runs.isEmpty {
                Text("Raider.IO has no completed keys for this character this season.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted) { run in
                    BestKeyRow(run: run, tint: tint)
                    if run.id != sorted.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardBackground()
    }
}

private struct BestKeyRow: View {
    let run: BestRun
    let tint: Color

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 40

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedImage(url: run.iconUrl, pointSize: iconSize) {
                Image(systemName: "key.fill").foregroundStyle(.secondary)
            }
            .frame(width: iconSize, height: iconSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(run.dungeon)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("+\(run.mythicLevel)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(run.isTimed ? tint : .secondary)
                }
                HStack(spacing: 6) {
                    Text(Self.duration(run.clearTimeMs))
                        .monospacedDigit()
                    Text("/ \(Self.duration(run.parTimeMs))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(timing)
                        .foregroundStyle(run.isTimed ? .green : .red)
                }
                .font(.caption)
                HStack(spacing: 6) {
                    if let score = run.score {
                        Text("Score \(score.formatted(.number.precision(.fractionLength(1))))")
                    }
                    if let date = run.completedAt {
                        Text("· \(date.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let affixes = run.affixes, !affixes.isEmpty {
                    Text(affixes.map(\.name).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Timed +2 (−1:35)" or "Over time (+0:42)".
    private var timing: String {
        let margin = Self.duration(abs(run.marginMs))
        if run.isTimed {
            return "Timed " + String(repeating: "★", count: run.numKeystoneUpgrades) + " (−\(margin))"
        }
        return "Over time (+\(margin))"
    }

    /// Milliseconds → "m:ss" (or "h:mm:ss").
    static func duration(_ ms: Int) -> String {
        Duration.milliseconds(ms).formatted(.time(pattern: ms >= 3_600_000 ? .hourMinuteSecond : .minuteSecond))
    }
}

#Preview {
    NavigationStack {
        PlayerDetailView(player: .previewFixturePlayer)
    }
    .environment(BuildStore.preview())
}
