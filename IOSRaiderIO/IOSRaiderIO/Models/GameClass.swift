import SwiftUI

/// A playable class from the bundled `classes.json`.
/// `id` and `name` match Raider.IO's `character.class.id` / `character.class.name`.
nonisolated struct GameClass: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let colorHex: String
    let icon: String
    let specs: [Spec]

    var color: Color { Color(hex: colorHex) }
    /// Raider.IO slug, e.g. "death-knight".
    var slug: String { RaiderIOSlug.make(name) }
}

nonisolated enum RaiderIOSlug {
    /// "Death Knight" → "death-knight", "Beast Mastery" → "beast-mastery" (verified against the API).
    static func make(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

/// A specialization. `id` and `name` match Raider.IO's `character.spec.id` / `character.spec.name`.
nonisolated struct Spec: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let role: Role
    let icon: String

    var slug: String { RaiderIOSlug.make(name) }
}

nonisolated enum Role: String, Codable, Hashable, Sendable {
    case tank, healer, dps

    var title: String {
        switch self {
        case .tank: "Tank"
        case .healer: "Healer"
        case .dps: "Damage"
        }
    }

    var systemImage: String {
        switch self {
        case .tank: "shield.fill"
        case .healer: "cross.fill"
        case .dps: "flame.fill"
        }
    }
}

/// The class + spec the user picked; used as a navigation value.
nonisolated struct SpecSelection: Hashable, Identifiable, Sendable {
    let gameClass: GameClass
    let spec: Spec

    var id: Int { spec.id }
}

nonisolated enum ClassCatalog {
    enum LoadError: Error {
        case missingFile
    }

    /// Decodes `classes.json` from the given bundle.
    static func load(from bundle: Bundle) throws -> [GameClass] {
        guard let url = bundle.url(forResource: "classes", withExtension: "json") else {
            throw LoadError.missingFile
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> [GameClass] {
        try JSONDecoder().decode([GameClass].self, from: data)
    }
}

extension Color {
    /// Creates a color from a `RRGGBB` hex string. Invalid input yields gray.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
