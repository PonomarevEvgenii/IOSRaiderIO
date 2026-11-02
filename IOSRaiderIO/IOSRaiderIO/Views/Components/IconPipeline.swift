import Foundation
import ImageIO
import CoreGraphics

/// Downloads, downsamples and caches icons once, off the main thread.
/// Replaces AsyncImage, which re-downloaded and decoded full-size images for every view.
actor IconPipeline {
    static let shared = IconPipeline()

    /// NSCache is thread-safe; wrapped so it can be read synchronously from views.
    nonisolated let memory = ImageMemoryCache()
    private var inFlight: [String: Task<CGImage?, Never>] = [:]
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        // Icons rarely change: keep them on disk between launches.
        configuration.urlCache = URLCache(memoryCapacity: 8 << 20, diskCapacity: 100 << 20)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    nonisolated static func key(url: URL, maxPixel: Int, grayscale: Bool) -> String {
        "\(url.absoluteString)#\(maxPixel)#\(grayscale)"
    }

    /// Returns a downsampled image (optionally grayscale), or nil if it can't be loaded.
    func image(url: URL, maxPixel: Int, grayscale: Bool) async -> CGImage? {
        let key = Self.key(url: url, maxPixel: maxPixel, grayscale: grayscale)
        if let cached = memory.image(for: key) { return cached }
        if let task = inFlight[key] { return await task.value }

        let session = session
        let task = Task.detached(priority: .utility) { () -> CGImage? in
            var request = URLRequest(url: url)
            request.setValue(LiveRaiderIOClient.userAgent, forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await session.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return Self.decode(data, maxPixel: maxPixel, grayscale: grayscale)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { memory.insert(image, for: key) }
        return image
    }

    private nonisolated static func decode(_ data: Data, maxPixel: Int, grayscale: Bool) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        guard grayscale else { return thumbnail }
        // Draw once into a gray color space instead of applying a live grayscale filter per frame.
        guard let context = CGContext(
            data: nil, width: thumbnail.width, height: thumbnail.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return thumbnail }
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height))
        return context.makeImage() ?? thumbnail
    }
}

nonisolated final class ImageMemoryCache: @unchecked Sendable {
    private final class Box {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 1500
        return cache
    }()

    func image(for key: String) -> CGImage? { cache.object(forKey: key as NSString)?.image }
    func insert(_ image: CGImage, for key: String) { cache.setObject(Box(image), forKey: key as NSString) }
}
