import AppKit
import Foundation

/// Caches thumbnails and app icons for performance
@MainActor
final class ImageCacheService {
    static let shared = ImageCacheService()

    private var thumbnailCache = NSCache<NSString, NSImage>()
    private var appIconCache = NSCache<NSString, NSImage>()
    private var faviconCache = NSCache<NSString, NSImage>()
    private var linkImageCache = NSCache<NSString, NSImage>()

    private init() {
        // Limit cache size
        thumbnailCache.countLimit = 200
        appIconCache.countLimit = 50
        faviconCache.countLimit = 100
        linkImageCache.countLimit = 100
    }

    // MARK: - Thumbnails

    /// Get or create a thumbnail for an image item
    func thumbnail(for itemID: UUID, imageData: Data, maxSize: CGSize = CGSize(width: 200, height: 150)) -> NSImage? {
        let key = itemID.uuidString as NSString

        // Check cache first
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        // Create thumbnail
        guard let original = NSImage(data: imageData) else { return nil }
        let thumbnail = createThumbnail(from: original, maxSize: maxSize)

        if let thumbnail = thumbnail {
            thumbnailCache.setObject(thumbnail, forKey: key)
        }

        return thumbnail
    }

    private func createThumbnail(from image: NSImage, maxSize: CGSize) -> NSImage? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        // Calculate scale to fit within maxSize
        let widthRatio = maxSize.width / originalSize.width
        let heightRatio = maxSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0) // Don't upscale

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()

        return thumbnail
    }

    // MARK: - App Icons

    /// Get cached app icon for bundle ID
    func appIcon(for bundleID: String) -> NSImage? {
        let key = bundleID as NSString

        // Check cache first
        if let cached = appIconCache.object(forKey: key) {
            return cached
        }

        // Load and cache
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        appIconCache.setObject(icon, forKey: key)

        return icon
    }

    // MARK: - Link Images

    /// Get cached favicon
    func favicon(for itemID: UUID, data: Data) -> NSImage? {
        let key = itemID.uuidString as NSString

        if let cached = faviconCache.object(forKey: key) {
            return cached
        }

        guard let image = NSImage(data: data) else { return nil }
        faviconCache.setObject(image, forKey: key)

        return image
    }

    /// Get cached link preview image (og:image)
    func linkImage(for itemID: UUID, data: Data, maxSize: CGSize = CGSize(width: 200, height: 120)) -> NSImage? {
        let key = itemID.uuidString as NSString

        if let cached = linkImageCache.object(forKey: key) {
            return cached
        }

        guard let original = NSImage(data: data) else { return nil }
        let thumbnail = createThumbnail(from: original, maxSize: maxSize)

        if let thumbnail = thumbnail {
            linkImageCache.setObject(thumbnail, forKey: key)
        }

        return thumbnail
    }

    // MARK: - Cache Management

    func clearCache() {
        thumbnailCache.removeAllObjects()
        appIconCache.removeAllObjects()
        faviconCache.removeAllObjects()
        linkImageCache.removeAllObjects()
    }

    func removeItem(_ itemID: UUID) {
        let key = itemID.uuidString as NSString
        thumbnailCache.removeObject(forKey: key)
        faviconCache.removeObject(forKey: key)
        linkImageCache.removeObject(forKey: key)
    }
}
