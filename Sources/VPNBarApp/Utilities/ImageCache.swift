import AppKit

/// Provides cached access to system images.
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: NSImage] = [:]
    
    private init() {}
    
    /// Gets or creates a cached system image.
    /// - Parameters:
    ///   - systemSymbolName: SF Symbol name.
    ///   - isTemplate: Whether the image should be treated as a template.
    /// - Returns: Cached or newly created image.
    func image(systemSymbolName: String, isTemplate: Bool = true) -> NSImage? {
        let cacheKey = "\(systemSymbolName)_\(isTemplate)"
        
        if let cached = cache[cacheKey] {
            return cached
        }
        
        guard let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil) else {
            return nil
        }
        
        image.isTemplate = isTemplate
        cache[cacheKey] = image
        return image
    }
    
    /// Caches a custom image with the specified key.
    /// - Parameters:
    ///   - image: Image to cache.
    ///   - key: Cache key.
    func cacheImage(_ image: NSImage, forKey key: String) {
        cache[key] = image
    }
    
    /// Gets a cached image by key.
    /// - Parameter key: Cache key.
    /// - Returns: Cached image if available.
    func cachedImage(forKey key: String) -> NSImage? {
        return cache[key]
    }
    
    /// Clears the image cache.
    func clearCache() {
        cache.removeAll()
    }
}
