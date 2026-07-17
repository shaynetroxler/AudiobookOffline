import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    let itemId: String
    let title: String
    let chapters: [Chapter]
    let totalDuration: Double
    let isOfflinePlayback: Bool

    private(set) var isPlaying = false
    private(set) var currentTrackIndex = 0
    private(set) var currentTimeInTrack: Double = 0
    private(set) var rate: Float = 1.0

    var globalCurrentTime: Double {
        (trackOffsets[safe: currentTrackIndex] ?? 0) + currentTimeInTrack
    }

    private let player = AVPlayer()
    private let trackURLs: [URL]
    private let trackDurations: [Double]
    private let trackOffsets: [Double]
    private var timeObserver: Any?
    private var reportTask: Task<Void, Never>?
    private var endObserver: NSObjectProtocol?

    private let client: ABSClient?
    private let progressQueue: ProgressSyncQueue

    init(
        itemId: String, title: String, chapters: [Chapter], tracks: [Track], trackURLs: [URL],
        isOfflinePlayback: Bool, resumeAt: Double, client: ABSClient?, progressQueue: ProgressSyncQueue
    ) {
        self.itemId = itemId
        self.title = title
        self.chapters = chapters
        self.trackURLs = trackURLs
        self.trackDurations = tracks.map(\.duration)
        self.isOfflinePlayback = isOfflinePlayback
        self.client = client
        self.progressQueue = progressQueue

        var offsets: [Double] = []
        var running: Double = 0
        for duration in trackDurations {
            offsets.append(running)
            running += duration
        }
        self.trackOffsets = offsets
        self.totalDuration = running > 0 ? running : (tracks.first?.duration ?? 0)

        observeTrackEnd()
        seekGlobal(resumeAt, autoplayAfter: false)
    }

    private func observeTrackEnd() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.advanceTrack() }
        }
    }

    private func loadTrack(_ index: Int, seekTo: Double = 0, thenPlay: Bool) {
        guard trackURLs.indices.contains(index) else { return }
        let item = AVPlayerItem(url: trackURLs[index])
        player.replaceCurrentItem(with: item)
        currentTrackIndex = index
        currentTimeInTrack = seekTo
        let time = CMTime(seconds: seekTo, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            guard thenPlay else { return }
            Task { @MainActor in
                guard let self else { return }
                self.player.rate = self.rate
                self.isPlaying = true
            }
        }
        installTimeObserverIfNeeded()
    }

    private func installTimeObserverIfNeeded() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            let seconds = time.seconds.isFinite ? time.seconds : 0
            Task { @MainActor in self?.currentTimeInTrack = seconds }
        }
    }

    private func advanceTrack() {
        let next = currentTrackIndex + 1
        if trackURLs.indices.contains(next) {
            loadTrack(next, seekTo: 0, thenPlay: isPlaying)
        } else {
            isPlaying = false
            reportProgress(isFinished: true)
        }
    }

    func play() {
        if player.currentItem == nil {
            loadTrack(currentTrackIndex, seekTo: currentTimeInTrack, thenPlay: true)
        } else {
            player.rate = rate
        }
        isPlaying = true
        startReportingLoop()
    }

    func pause() {
        player.pause()
        isPlaying = false
        reportTask?.cancel()
        reportProgress(isFinished: false)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying { player.rate = newRate }
    }

    func skip(_ seconds: Double) {
        seekGlobal(globalCurrentTime + seconds, autoplayAfter: isPlaying)
    }

    func seekGlobal(_ target: Double, autoplayAfter: Bool) {
        let clamped = max(0, min(target, totalDuration))
        var trackIndex = 0
        for (index, offset) in trackOffsets.enumerated() where offset <= clamped {
            trackIndex = index
        }
        let localOffset = clamped - (trackOffsets[safe: trackIndex] ?? 0)

        if trackIndex == currentTrackIndex, player.currentItem != nil {
            currentTimeInTrack = localOffset
            player.seek(to: CMTime(seconds: localOffset, preferredTimescale: 600)) { [weak self] _ in
                guard autoplayAfter else { return }
                Task { @MainActor in
                    guard let self else { return }
                    self.player.rate = self.rate
                    self.isPlaying = true
                }
            }
        } else {
            loadTrack(trackIndex, seekTo: localOffset, thenPlay: autoplayAfter)
        }
    }

    func jumpToChapter(_ chapter: Chapter) {
        seekGlobal(chapter.start, autoplayAfter: isPlaying)
    }

    private func startReportingLoop() {
        reportTask?.cancel()
        reportTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                self.reportProgress(isFinished: false)
            }
        }
    }

    private func reportProgress(isFinished: Bool) {
        let time = globalCurrentTime
        let duration = totalDuration
        Task { [progressQueue, client, itemId] in
            await progressQueue.report(itemId: itemId, currentTime: time, duration: duration, isFinished: isFinished, client: client)
        }
    }

    func teardown() {
        reportTask?.cancel()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        reportProgress(isFinished: false)
        player.pause()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
