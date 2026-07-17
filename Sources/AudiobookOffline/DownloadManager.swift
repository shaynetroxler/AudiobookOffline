import Foundation
import Observation

@Observable
@MainActor
final class DownloadManager {
    struct ItemRecord: Codable {
        var trackFiles: [Int: String]
        var isComplete: Bool
    }

    private(set) var progress: [String: Double] = [:]
    private(set) var downloading: Set<String> = []
    private var manifest: [String: ItemRecord] = [:]

    private let baseDir: URL
    private let manifestURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseDir = appSupport.appendingPathComponent("AudiobookOffline", isDirectory: true)
        manifestURL = baseDir.appendingPathComponent("manifest.json")
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        loadManifest()
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        manifest = (try? JSONDecoder().decode([String: ItemRecord].self, from: data)) ?? [:]
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    func isDownloaded(_ itemId: String) -> Bool {
        manifest[itemId]?.isComplete ?? false
    }

    func isDownloading(_ itemId: String) -> Bool {
        downloading.contains(itemId)
    }

    func localTrackURLs(for itemId: String) -> [URL]? {
        guard let record = manifest[itemId], record.isComplete else { return nil }
        let itemDir = baseDir.appendingPathComponent(itemId, isDirectory: true)
        return record.trackFiles.sorted { $0.key < $1.key }.map { itemDir.appendingPathComponent($0.value) }
    }

    func cachedDetail(for itemId: String) -> LibraryItemDetail? {
        let detailURL = baseDir.appendingPathComponent(itemId, isDirectory: true).appendingPathComponent("detail.json")
        guard let data = try? Data(contentsOf: detailURL) else { return nil }
        return try? JSONDecoder().decode(LibraryItemDetail.self, from: data)
    }

    func delete(_ itemId: String) {
        let itemDir = baseDir.appendingPathComponent(itemId, isDirectory: true)
        try? FileManager.default.removeItem(at: itemDir)
        manifest.removeValue(forKey: itemId)
        progress.removeValue(forKey: itemId)
        saveManifest()
    }

    func download(item: LibraryItemDetail, client: ABSClient) async throws {
        guard !downloading.contains(item.id) else { return }
        downloading.insert(item.id)
        progress[item.id] = 0
        defer { downloading.remove(item.id) }

        let itemDir = baseDir.appendingPathComponent(item.id, isDirectory: true)
        try FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)

        if let detailData = try? JSONEncoder().encode(item) {
            try? detailData.write(to: itemDir.appendingPathComponent("detail.json"), options: .atomic)
        }

        let tracks = item.media.tracks
        var trackFiles: [Int: String] = [:]

        for (index, track) in tracks.enumerated() {
            guard let url = client.absoluteURL(forContentPath: track.contentUrl) else { continue }
            let ext = (track.contentUrl as NSString).pathExtension
            let filename = "track-\(track.index).\(ext.isEmpty ? "m4b" : ext)"
            let destination = itemDir.appendingPathComponent(filename)

            let trackCount = tracks.count
            let itemId = item.id
            let tmpURL = try await downloadFile(from: url) { [weak self] fraction in
                let overall = (Double(index) + fraction) / Double(trackCount)
                Task { @MainActor in
                    self?.progress[itemId] = overall
                }
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tmpURL, to: destination)
            trackFiles[track.index] = filename
        }

        manifest[item.id] = ItemRecord(trackFiles: trackFiles, isComplete: true)
        saveManifest()
        progress[item.id] = 1.0
    }
}
