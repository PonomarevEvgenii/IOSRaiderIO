import SwiftUI

extension View {
    /// Liquid Glass on iOS 26+, a material fallback on iOS 17–25.
    /// Use for small elements (tiles, chips, buttons); large scrolling cards use `cardBackground`.
    @ViewBuilder
    func liquidGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(tint?.opacity(0.6) ?? .white.opacity(0.2), lineWidth: 1))
        }
    }

    /// Cheap card look for large content (talent trees, key lists): a translucent fill
    /// instead of glass, which would re-blur the background on every scrolled frame.
    func cardBackground(tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return background {
            shape.fill(.background.opacity(0.75))
                .overlay(shape.fill((tint ?? .clear).opacity(0.12)))
                .overlay(shape.stroke(.primary.opacity(0.08), lineWidth: 1))
        }
    }

    /// Glass button style on iOS 26+, bordered on older systems.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Colorful backdrop so the glass has something to refract.
    func screenBackground(_ color: Color = .accentColor) -> some View {
        background {
            LinearGradient(
                colors: [color.opacity(0.45), color.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

/// Wraps content in a `GlassEffectContainer` on iOS 26+ (better rendering of many glass shapes).
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
