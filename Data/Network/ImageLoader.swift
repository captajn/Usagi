import Foundation
import UIKit

actor ImageDiskCache {
    private let directory: URL
    private let memory = NSCache<NSString, UIImage>()

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.directory = base.appendingPathComponent("UsagiImages", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        memory.countLimit = 200
    }

    func image(for url: URL) -> UIImage? {
        let key = keyFor(url)
        if let mem = memory.object(forKey: key as NSString) { return mem }
        let file = directory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    func store(_ image: UIImage, for url: URL) {
        let key = keyFor(url)
        memory.setObject(image, forKey: key as NSString)
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: directory.appendingPathComponent(key), options: .atomic)
        }
    }

    func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func keyFor(_ url: URL) -> String {
        let base = url.absoluteString.data(using: .utf8) ?? Data()
        return base.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(120) + ".jpg"
    }
}

@MainActor
final class ImagePipeline: ObservableObject {
    static let shared = ImagePipeline()
    private let cache = ImageDiskCache()
    private let client = HTTPClient()

    func load(urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        if let cached = await cache.image(for: url) { return cached }
        do {
            let response = try await client.data(for: HTTPRequest(url: url))
            guard let image = UIImage(data: response.data) else { return nil }
            await cache.store(image, for: url)
            return image
        } catch {
            AppLog.error("Image load failed", error: error)
            return nil
        }
    }

    func clearCache() async {
        await cache.clear()
    }
}
