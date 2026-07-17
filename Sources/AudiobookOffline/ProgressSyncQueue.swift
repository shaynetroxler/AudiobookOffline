import Foundation
import Observation

/// Buffers progress updates that fail to reach the server (e.g. offline while reading)
/// and flushes them once connectivity returns.
@Observable
@MainActor
final class ProgressSyncQueue {
    struct PendingUpdate: Codable {
        let itemId: String
        let currentTime: Double
        let duration: Double
        let isFinished: Bool
        let timestamp: Date
    }

    private(set) var pendingCount: Int = 0
    private var pending: [String: PendingUpdate] = [:] // keyed by itemId, latest wins
    private var lastKnown: [String: PendingUpdate] = [:] // resume-position cache, updated regardless of sync success

    private let fileURL: URL
    private let lastKnownURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("AudiobookOffline", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("pending-progress.json")
        lastKnownURL = dir.appendingPathComponent("last-known-progress.json")
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL) {
            pending = (try? JSONDecoder().decode([String: PendingUpdate].self, from: data)) ?? [:]
        }
        pendingCount = pending.count
        if let data = try? Data(contentsOf: lastKnownURL) {
            lastKnown = (try? JSONDecoder().decode([String: PendingUpdate].self, from: data)) ?? [:]
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: fileURL, options: .atomic)
        pendingCount = pending.count
    }

    private func saveLastKnown() {
        guard let data = try? JSONEncoder().encode(lastKnown) else { return }
        try? data.write(to: lastKnownURL, options: .atomic)
    }

    func lastPosition(for itemId: String) -> PendingUpdate? {
        lastKnown[itemId]
    }

    func report(itemId: String, currentTime: Double, duration: Double, isFinished: Bool, client: ABSClient?) async {
        let update = PendingUpdate(itemId: itemId, currentTime: currentTime, duration: duration, isFinished: isFinished, timestamp: Date())
        lastKnown[itemId] = update
        saveLastKnown()

        guard let client else {
            pending[itemId] = update
            save()
            return
        }

        do {
            try await client.updateProgress(itemId: itemId, currentTime: currentTime, duration: duration, isFinished: isFinished)
            pending.removeValue(forKey: itemId)
            save()
        } catch {
            pending[itemId] = update
            save()
        }
    }

    func flush(client: ABSClient) async {
        guard !pending.isEmpty else { return }
        for (itemId, update) in pending {
            do {
                try await client.updateProgress(
                    itemId: itemId, currentTime: update.currentTime, duration: update.duration, isFinished: update.isFinished
                )
                pending.removeValue(forKey: itemId)
            } catch {
                // stays queued, try again next flush
            }
        }
        save()
    }
}
