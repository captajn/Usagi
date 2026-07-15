import Foundation
import Compression
import UIKit

enum CBZImporterError: LocalizedError {
    case invalidArchive
    case noImages
    case io

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return String(localized: "Invalid CBZ/ZIP archive")
        case .noImages: return String(localized: "No images found in archive")
        case .io: return String(localized: "Could not read archive")
        }
    }
}

/// Minimal ZIP/CBZ importer (store-only + deflate via Compression framework for small archives).
/// For production, consider ZIPFoundation; this keeps pure Apple frameworks.
actor CBZImporter {
    private let db: AppDatabase

    init(db: AppDatabase = .shared) {
        self.db = db
    }

    func importCBZ(from fileURL: URL, title: String? = nil) async throws -> LocalChapterPackage {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: fileURL)
        let entries = try ZipReader.extractImageEntries(from: data)
        guard !entries.isEmpty else { throw CBZImporterError.noImages }

        let mangaID = Int64(abs(fileURL.lastPathComponent.hashValue) % 1_000_000) + 10_000
        let chapterID = mangaID * 10 + 1
        let dir = try await db.importsDirectory()
            .appendingPathComponent("\(mangaID)", isDirectory: true)
            .appendingPathComponent("\(chapterID)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var paths: [String] = []
        for (index, entry) in entries.enumerated() {
            let ext = (entry.name as NSString).pathExtension.isEmpty ? "jpg" : (entry.name as NSString).pathExtension
            let dest = dir.appendingPathComponent(String(format: "%03d.\(ext)", index))
            try entry.data.write(to: dest, options: .atomic)
            paths.append(dest.path)
        }

        let package = LocalChapterPackage(
            id: "\(mangaID)-\(chapterID)",
            mangaID: mangaID,
            chapterID: chapterID,
            mangaTitle: title ?? fileURL.deletingPathExtension().lastPathComponent,
            chapterTitle: String(localized: "Imported"),
            pagePaths: paths,
            importedAt: Date(),
            source: .cbzImport
        )
        try await db.upsertLocalChapter(package)

        // Synthetic manga for library/detail
        let pages = paths.enumerated().map { Page(id: Int64($0.offset), index: $0.offset, url: "file://\($0.element)") }
        let chapter = Chapter(
            id: chapterID,
            mangaID: mangaID,
            name: String(localized: "Imported"),
            number: 1,
            volume: nil,
            branch: nil,
            uploadDate: Date(),
            scanlator: nil,
            url: fileURL.absoluteString,
            sourceID: "local.cbz",
            pages: pages
        )
        let manga = Manga(
            id: mangaID,
            title: package.mangaTitle,
            altTitles: [],
            url: "local://\(mangaID)",
            publicURL: fileURL.absoluteString,
            rating: -1,
            isNSFW: false,
            contentRating: .safe,
            coverURL: paths.first.map { "file://\($0)" },
            largeCoverURL: nil,
            state: .unknown,
            authors: [],
            sourceID: "local.cbz",
            description: String(localized: "Imported from CBZ/ZIP."),
            tags: [Tag(id: 0, title: "Local", key: "local", sourceID: "local.cbz")],
            chapters: [chapter]
        )
        try await db.cacheManga(manga)
        return package
    }
}

// MARK: - Minimal ZIP reader (stored + deflate)

enum ZipReader {
    struct Entry {
        var name: String
        var data: Data
    }

    static func extractImageEntries(from data: Data) throws -> [Entry] {
        var entries: [Entry] = []
        var offset = 0
        let bytes = [UInt8](data)

        while offset + 30 < bytes.count {
            // Local file header signature 0x04034b50
            let sig = u32(bytes, offset)
            if sig != 0x04034b50 { break }

            let compression = u16(bytes, offset + 8)
            let compSize = Int(u32(bytes, offset + 18))
            let uncompSize = Int(u32(bytes, offset + 22))
            let nameLen = Int(u16(bytes, offset + 26))
            let extraLen = Int(u16(bytes, offset + 28))
            let nameStart = offset + 30
            guard nameStart + nameLen <= bytes.count else { break }
            let nameData = Data(bytes[nameStart ..< nameStart + nameLen])
            let name = String(data: nameData, encoding: .utf8) ?? "file"
            let dataStart = nameStart + nameLen + extraLen
            guard dataStart + compSize <= bytes.count else { break }
            let payload = Data(bytes[dataStart ..< dataStart + compSize])

            if !name.hasSuffix("/"), isImage(name) {
                let fileData: Data
                switch compression {
                case 0:
                    fileData = payload
                case 8:
                    fileData = try inflate(payload, expectedSize: uncompSize)
                default:
                    offset = dataStart + compSize
                    continue
                }
                entries.append(Entry(name: name, data: fileData))
            }
            offset = dataStart + compSize
        }

        return entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func isImage(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png")
            || lower.hasSuffix(".webp") || lower.hasSuffix(".gif")
    }

    private static func u16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) | (UInt16(b[i + 1]) << 8)
    }

    private static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i + 1]) << 8) | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        let dstSize = max(expectedSize, data.count * 4)
        var destination = Data(count: dstSize)
        let result = try destination.withUnsafeMutableBytes { destPtr -> Int in
            try data.withUnsafeBytes { srcPtr -> Int in
                guard let src = srcPtr.bindMemory(to: UInt8.self).baseAddress,
                      let dst = destPtr.bindMemory(to: UInt8.self).baseAddress else {
                    throw CBZImporterError.io
                }
                let written = compression_decode_buffer(
                    dst, dstSize,
                    src, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
                if written == 0 { throw CBZImporterError.invalidArchive }
                return written
            }
        }
        destination.count = result
        return destination
    }
}
