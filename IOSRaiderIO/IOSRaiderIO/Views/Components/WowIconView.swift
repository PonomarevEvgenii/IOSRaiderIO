import SwiftUI

/// Icon from the public Wowhead CDN, with a placeholder for missing or failed icons.
struct WowIconView: View {
    let name: String?
    var size: CGFloat = 40
    /// Defaults to a slightly rounded square.
    var cornerRadius: CGFloat?
    /// Pre-rendered gray version (for unselected talents).
    var grayscale = false

    private var url: URL? {
        guard let name, !name.isEmpty else { return nil }
        return URL(string: "https://wow.zamimg.com/images/wow/icons/large/\(name).jpg")
    }

    var body: some View {
        CachedImage(url: url, pointSize: size, grayscale: grayscale) {
            Image(systemName: "questionmark.square.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(size * 0.15)
                .background(.quaternary)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.18))
        .accessibilityHidden(true)
    }
}

/// Shows an image from `IconPipeline` (cached, downsampled). While loading, a flat fill
/// is shown instead of a spinner, so screens with many icons don't animate dozens of spinners.
struct CachedImage<Failure: View>: View {
    let url: URL?
    let pointSize: CGFloat
    var grayscale = false
    @ViewBuilder let failure: Failure

    @Environment(\.displayScale) private var displayScale
    @State private var loaded: CGImage?
    @State private var failed = false

    private var maxPixel: Int { max(1, Int((pointSize * displayScale).rounded(.up))) }

    var body: some View {
        let cached = url.flatMap {
            IconPipeline.shared.memory.image(for: IconPipeline.key(url: $0, maxPixel: maxPixel, grayscale: grayscale))
        }
        Group {
            if let image = loaded ?? cached {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .scaledToFill()
            } else if failed || url == nil {
                failure
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: "\(url?.absoluteString ?? "")#\(maxPixel)#\(grayscale)") {
            guard let url, cached == nil else { return }
            let image = await IconPipeline.shared.image(url: url, maxPixel: maxPixel, grayscale: grayscale)
            loaded = image
            failed = image == nil
        }
    }
}

#Preview {
    HStack {
        WowIconView(name: "classicon_paladin")
        WowIconView(name: "classicon_paladin", grayscale: true)
        WowIconView(name: "this_icon_does_not_exist")
        WowIconView(name: nil)
    }
    .padding()
}
