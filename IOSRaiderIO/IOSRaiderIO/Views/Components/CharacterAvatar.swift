import SwiftUI

/// Round character portrait from Raider.IO's `thumbnail_url`; falls back to the class icon.
struct CharacterAvatar: View {
    let url: URL?
    let fallbackIcon: String?
    var tint: Color = .accentColor
    var size: CGFloat = 44

    var body: some View {
        CachedImage(url: url, pointSize: size) {
            WowIconView(name: fallbackIcon, size: size, cornerRadius: size / 2)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(tint, lineWidth: 2))
        .accessibilityHidden(true)
    }
}
