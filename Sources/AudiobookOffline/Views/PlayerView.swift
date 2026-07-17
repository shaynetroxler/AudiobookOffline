import SwiftUI

struct PlayerHostView: View {
    @Environment(AppState.self) private var appState
    let itemId: String

    @State private var viewModel: PlayerViewModel?
    @State private var loadError: String?
    @State private var detail: LibraryItemDetail?

    var body: some View {
        Group {
            if let viewModel {
                PlayerView(viewModel: viewModel, detail: detail)
            } else if let loadError {
                ContentUnavailableView("Can't Load Book", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ProgressView("Loading…")
            }
        }
        .task { await load() }
        .onDisappear { viewModel?.teardown() }
    }

    private func load() async {
        let downloadManager = appState.downloadManager
        let isDownloaded = downloadManager.isDownloaded(itemId)

        var detail: LibraryItemDetail?
        if isDownloaded {
            detail = downloadManager.cachedDetail(for: itemId)
        }
        if detail == nil, let client = appState.client {
            detail = try? await client.itemDetail(itemId: itemId)
        }
        guard let detail else {
            loadError = isDownloaded
                ? "Downloaded book metadata is missing or corrupted."
                : "Couldn't reach the server, and this book isn't downloaded for offline playback."
            return
        }
        self.detail = detail

        let localURLs = downloadManager.localTrackURLs(for: itemId)
        let urls: [URL]
        if let localURLs, localURLs.count == detail.media.tracks.count {
            urls = localURLs
        } else if let client = appState.client {
            urls = detail.media.tracks.compactMap { client.absoluteURL(forContentPath: $0.contentUrl) }
        } else {
            loadError = "This book isn't downloaded, and there's no server connection to stream it."
            return
        }

        var resumeAt: Double = 0
        if let client = appState.client {
            do {
                if let serverProgress = try await client.mediaProgress().first(where: { $0.libraryItemId == itemId }) {
                    resumeAt = serverProgress.currentTime
                }
            } catch {
                print("AudiobookOffline: failed to fetch server progress for \(itemId): \(error)")
            }
        }
        if let cached = appState.progressQueue.lastPosition(for: itemId) {
            resumeAt = max(resumeAt, cached.currentTime)
        }

        viewModel = PlayerViewModel(
            itemId: itemId,
            title: detail.media.metadata.title,
            chapters: detail.media.chapters,
            tracks: detail.media.tracks,
            trackURLs: urls,
            isOfflinePlayback: localURLs != nil,
            resumeAt: resumeAt,
            client: appState.client,
            progressQueue: appState.progressQueue
        )
    }
}

struct PlayerView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PlayerViewModel
    let detail: LibraryItemDetail?

    @State private var downloadError: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        HSplitView {
            VStack(spacing: 20) {
                Text(viewModel.title)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if viewModel.isOfflinePlayback {
                    Label("Playing from downloaded file", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    downloadControl
                }

                Slider(
                    value: Binding(
                        get: { viewModel.globalCurrentTime },
                        set: { viewModel.seekGlobal($0, autoplayAfter: viewModel.isPlaying) }
                    ),
                    in: 0...max(viewModel.totalDuration, 1)
                )
                .padding(.horizontal)

                HStack {
                    Text(formatClock(viewModel.globalCurrentTime))
                    Spacer()
                    Text(formatClock(viewModel.totalDuration))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal)

                HStack(spacing: 28) {
                    Button { viewModel.skip(-30) } label: {
                        Image(systemName: "gobackward.30").font(.title)
                    }
                    Button { viewModel.togglePlayPause() } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                    }
                    Button { viewModel.skip(30) } label: {
                        Image(systemName: "goforward.30").font(.title)
                    }
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                        Button {
                            viewModel.setRate(Float(speed))
                        } label: {
                            if Double(viewModel.rate) == speed {
                                Label("\(speed, specifier: "%.2g")×", systemImage: "checkmark")
                            } else {
                                Text("\(speed, specifier: "%.2g")×")
                            }
                        }
                    }
                } label: {
                    Text("\(viewModel.rate, specifier: "%.2g")× speed")
                }

                sleepTimerMenu

                Spacer()
            }
            .padding(24)
            .frame(minWidth: 340)

            if !viewModel.chapters.isEmpty {
                List(viewModel.chapters) { chapter in
                    Button {
                        viewModel.jumpToChapter(chapter)
                    } label: {
                        HStack {
                            Text(chapter.title)
                            Spacer()
                            Text(formatClock(chapter.start))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        chapterContains(chapter, time: viewModel.globalCurrentTime) ? Color.accentColor.opacity(0.15) : Color.clear
                    )
                }
                .frame(minWidth: 220)
            }
        }
        .navigationTitle(viewModel.title)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.space) {
            viewModel.togglePlayPause()
            return .handled
        }
        .alert("Download failed", isPresented: .constant(downloadError != nil), actions: {
            Button("OK") { downloadError = nil }
        }, message: {
            Text(downloadError ?? "")
        })
    }

    @ViewBuilder
    private var downloadControl: some View {
        if appState.downloadManager.isDownloaded(viewModel.itemId) {
            Label("Downloaded for offline playback", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else if appState.downloadManager.isDownloading(viewModel.itemId) {
            HStack(spacing: 6) {
                ProgressView(value: appState.downloadManager.progress[viewModel.itemId] ?? 0)
                    .frame(width: 80)
                Text("Downloading…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                startDownload()
            } label: {
                Label("Download for offline playback", systemImage: "arrow.down.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var sleepTimerMenu: some View {
        Menu {
            Button("Off") { viewModel.setSleepTimer(.off) }
            Divider()
            ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                Button("\(minutes) min") { viewModel.setSleepTimer(.duration(minutes: minutes)) }
            }
            Divider()
            Button("End of Chapter") { viewModel.setSleepTimer(.endOfChapter) }
        } label: {
            Label(sleepTimerLabel, systemImage: "moon.zzz")
        }
    }

    private var sleepTimerLabel: String {
        switch viewModel.sleepTimerOption {
        case .off:
            return "Sleep Timer"
        case .endOfChapter:
            return "Sleep at chapter end"
        case .duration:
            guard let remaining = viewModel.sleepTimerRemaining else { return "Sleep Timer" }
            let m = Int(remaining) / 60
            let s = Int(remaining) % 60
            return String(format: "Sleep in %d:%02d", m, s)
        }
    }

    private func startDownload() {
        guard let client = appState.client, let detail else { return }
        Task {
            do {
                try await appState.downloadManager.download(item: detail, client: client)
            } catch {
                downloadError = error.localizedDescription
            }
        }
    }

    private func chapterContains(_ chapter: Chapter, time: Double) -> Bool {
        time >= chapter.start && time < chapter.end
    }
}

func formatClock(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return String(format: "%d:%02d:%02d", h, m, s)
}
