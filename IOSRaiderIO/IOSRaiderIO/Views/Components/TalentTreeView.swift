import SwiftUI

/// One node to draw in the tree.
struct TalentTreeNode: Identifiable {
    let id: Int
    let name: String
    let icon: String?
    let posX: Int
    let posY: Int
    /// Ids of connected nodes (lines are drawn from this node to them).
    let next: [Int]
    let kind: TalentNodeShape.Kind
    /// Selected nodes are in color and connected by light lines; others are gray.
    let isSelected: Bool
    /// 0…1 extra fade for selected nodes (pick rate); 1 for a player's own talents.
    var emphasis: Double = 1
    /// Small text under the icon, e.g. "85%" or "2/2".
    var badge: String?
    /// Shown when the node is tapped.
    var detail: String?
}

/// Builds tree nodes by merging the full tree (Raidbots) with a player's picks or pick rates.
/// Without the full tree, only chosen talents are shown and there are no lines.
enum TalentTreeBuilder {
    static func playerNodes(
        tree: TalentTree, picks: [TalentPick], fullTree: SpecTalentTree?, heroTreeId: Int?
    ) -> [TalentTreeNode] {
        let picksByNode = Dictionary(picks.map { ($0.nodeId, $0) }, uniquingKeysWith: { first, _ in first })
        guard let fullTree else {
            return picks.map { pick in
                TalentTreeNode(
                    id: pick.nodeId, name: pick.name, icon: pick.icon, posX: pick.posX, posY: pick.posY, next: [],
                    kind: pick.isChoiceNode ? .choice : pick.isActive ? .active : .passive,
                    isSelected: true, badge: rankBadge(pick.rank, pick.maxRank), detail: nil
                )
            }
        }
        return fullTree.nodes(for: tree, heroTreeId: heroTreeId).map { node in
            if let pick = picksByNode[node.id] {
                let badge = rankBadge(pick.rank, pick.maxRank)
                return TalentTreeNode(
                    id: node.id, name: pick.name, icon: pick.icon, posX: node.posX, posY: node.posY,
                    next: node.next ?? [], kind: kind(of: node), isSelected: true,
                    badge: badge, detail: badge.map { "Rank \($0)" } ?? "Selected"
                )
            }
            let granted = node.freeNode == true
            return TalentTreeNode(
                id: node.id, name: name(of: node), icon: node.entries.first?.icon, posX: node.posX, posY: node.posY,
                next: node.next ?? [], kind: kind(of: node), isSelected: granted,
                badge: granted ? nil : rankBadge(0, node.maxRanks ?? 1),
                detail: granted ? "Granted automatically" : "Not selected"
            )
        }
    }

    /// A node counts as part of the popular build when at least half of the players pick it.
    static func popularNodes(
        tree: TalentTree, rates: [TalentPickRate], fullTree: SpecTalentTree?, heroTreeId: Int?
    ) -> [TalentTreeNode] {
        var best: [Int: TalentPickRate] = [:]
        var options: [Int: [TalentPickRate]] = [:]
        for rate in rates {
            options[rate.talent.nodeId, default: []].append(rate)
            if let current = best[rate.talent.nodeId], current.count >= rate.count { continue }
            best[rate.talent.nodeId] = rate
        }
        func detail(for rate: TalentPickRate) -> String {
            let others = (options[rate.talent.nodeId] ?? []).filter { $0.id != rate.id }
                .map { "\($0.talent.name) \(percent($0.rate))" }
            let base = "Picked by \(rate.count) of \(rate.total) players (\(percent(rate.rate)))"
            return others.isEmpty ? base : base + " · Alternative: " + others.joined(separator: ", ")
        }

        guard let fullTree else {
            return best.values.map { rate in
                let pick = rate.talent
                return TalentTreeNode(
                    id: pick.nodeId, name: pick.name, icon: pick.icon, posX: pick.posX, posY: pick.posY, next: [],
                    kind: pick.isChoiceNode ? .choice : pick.isActive ? .active : .passive,
                    isSelected: rate.rate >= 0.5, emphasis: rate.rate, badge: percent(rate.rate), detail: detail(for: rate)
                )
            }
        }
        return fullTree.nodes(for: tree, heroTreeId: heroTreeId).map { node in
            if let rate = best[node.id] {
                return TalentTreeNode(
                    id: node.id, name: rate.talent.name, icon: rate.talent.icon, posX: node.posX, posY: node.posY,
                    next: node.next ?? [], kind: kind(of: node), isSelected: rate.rate >= 0.5,
                    emphasis: rate.rate, badge: percent(rate.rate), detail: detail(for: rate)
                )
            }
            let granted = node.freeNode == true
            return TalentTreeNode(
                id: node.id, name: name(of: node), icon: node.entries.first?.icon, posX: node.posX, posY: node.posY,
                next: node.next ?? [], kind: kind(of: node), isSelected: granted,
                badge: granted ? nil : "0%",
                detail: granted ? "Granted automatically" : "Not picked by any of these players"
            )
        }
    }

    private static func kind(of node: TreeNodeDTO) -> TalentNodeShape.Kind {
        if node.type == "choice" { return .choice }
        return node.entries.first?.type == "active" ? .active : .passive
    }

    private static func name(of node: TreeNodeDTO) -> String {
        let names = node.entries.compactMap(\.name)
        return names.isEmpty ? (node.name ?? "Talent") : names.joined(separator: " / ")
    }

    private static func rankBadge(_ rank: Int, _ maxRank: Int) -> String? {
        maxRank > 1 ? "\(rank)/\(maxRank)" : nil
    }

    private static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

/// Draws a talent tree at in-game positions (~600 units per cell), scaled to fit the width and centered.
/// Lines between selected nodes use the tint color; lines to unselected nodes are dim gray.
struct TalentTreeView: View {
    let nodes: [TalentTreeNode]
    var tint: Color = .accentColor

    @State private var selectedId: Int?

    private static let cellUnits = 600.0
    private static let maxCellSize: CGFloat = 54

    private struct Bounds {
        let minX: Double
        let minY: Double
        let columns: Double
        let rows: Double
    }

    private var bounds: Bounds {
        let xs = nodes.map { Double($0.posX) }
        let ys = nodes.map { Double($0.posY) }
        let minX = xs.min() ?? 0, minY = ys.min() ?? 0
        return Bounds(
            minX: minX,
            minY: minY,
            columns: ((xs.max() ?? 0) - minX) / Self.cellUnits + 1,
            rows: ((ys.max() ?? 0) - minY) / Self.cellUnits + 1
        )
    }

    var body: some View {
        let bounds = bounds
        VStack(spacing: 10) {
            caption
            if !nodes.isEmpty {
                GeometryReader { geometry in
                    let cell = min(geometry.size.width / bounds.columns, Self.maxCellSize)
                    // Center horizontally when the tree is narrower than the available width.
                    let originX = (geometry.size.width - cell * bounds.columns) / 2
                    let centers = Dictionary(nodes.map { node in
                        (node.id, CGPoint(
                            x: originX + ((Double(node.posX) - bounds.minX) / Self.cellUnits + 0.5) * cell,
                            y: ((Double(node.posY) - bounds.minY) / Self.cellUnits + 0.5) * cell
                        ))
                    }, uniquingKeysWith: { first, _ in first })
                    ZStack(alignment: .topLeading) {
                        TreeLines(segments: segments(centers: centers, selected: false))
                            .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        TreeLines(segments: segments(centers: centers, selected: true))
                            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        ForEach(nodes) { node in
                            if let center = centers[node.id] {
                                nodeView(node, size: cell * 0.72)
                                    .position(center)
                            }
                        }
                    }
                    // Flatten the tree into one layer so scrolling composites a single texture.
                    .drawingGroup(opaque: false)
                }
                .aspectRatio(bounds.columns / bounds.rows, contentMode: .fit)
                .frame(maxWidth: Self.maxCellSize * bounds.columns)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var caption: some View {
        if let selected = nodes.first(where: { $0.id == selectedId }) {
            VStack(spacing: 2) {
                Text(selected.name).font(.subheadline.weight(.semibold))
                if let detail = selected.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .liquidGlass(tint: tint.opacity(0.25), in: Capsule())
        } else {
            Text("Tap a talent to see its name")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// A line is "selected" when both ends are selected.
    private func segments(centers: [Int: CGPoint], selected: Bool) -> [(CGPoint, CGPoint)] {
        let selectedIds = Set(nodes.filter(\.isSelected).map(\.id))
        return nodes.flatMap { node in
            node.next.compactMap { target -> (CGPoint, CGPoint)? in
                guard let from = centers[node.id], let to = centers[target] else { return nil }
                let isSelectedLine = selectedIds.contains(node.id) && selectedIds.contains(target)
                return isSelectedLine == selected ? (from, to) : nil
            }
        }
    }

    private func nodeView(_ node: TalentTreeNode, size: CGFloat) -> some View {
        let shape = TalentNodeShape(kind: node.kind)
        let isTapped = node.id == selectedId
        return Button {
            selectedId = isTapped ? nil : node.id
        } label: {
            // Gray icons are pre-rendered by IconPipeline; no per-frame filters or shadows here.
            WowIconView(name: node.icon, size: size, cornerRadius: 0, grayscale: !node.isSelected)
                .clipShape(shape)
                .opacity(node.isSelected ? 0.55 + 0.45 * node.emphasis : 0.45)
                .background(shape.fill(Color.black.opacity(0.6)))
                .overlay(
                    shape.stroke(
                        isTapped ? Color.primary : node.isSelected ? tint : Color.secondary.opacity(0.5),
                        lineWidth: isTapped ? 2.5 : node.isSelected ? 2 : 1
                    )
                )
                .overlay(alignment: .bottom) {
                    if let badge = node.badge {
                        Text(badge)
                            .font(.system(size: max(8, size * 0.24), weight: .heavy).monospacedDigit())
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 3)
                            .background(.black.opacity(0.7), in: Capsule())
                            .foregroundStyle(node.isSelected ? .white : .gray)
                            .offset(y: size * 0.3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel([node.name, node.detail].compactMap { $0 }.joined(separator: ", "))
    }
}

private struct TreeLines: Shape {
    let segments: [(CGPoint, CGPoint)]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (from, to) in segments {
            path.move(to: from)
            path.addLine(to: to)
        }
        return path
    }
}

/// Game-like node shapes: circle = passive, rounded square = active, octagon = choice node.
struct TalentNodeShape: Shape {
    enum Kind { case passive, active, choice }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .passive:
            return Circle().path(in: rect)
        case .active:
            return RoundedRectangle(cornerRadius: rect.width * 0.2).path(in: rect)
        case .choice:
            let inset = rect.width * 0.29
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + inset))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - inset))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - inset))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + inset))
            path.closeSubpath()
            return path
        }
    }
}
