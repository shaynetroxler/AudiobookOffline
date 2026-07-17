import SwiftUI

struct ItemRow: View {
    @Environment(AppState.self) private var appState
    let item: LibraryItem

    @State private var isDownloadingLocally = false
    @State private var downloadError: String?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: appState.client?.coverURL(itemId: item.id)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.media.metadata.title)
                    .font(.body)
                    .lineLimit(1)
                if let author = item.media.metadata.authorName {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let duration = item.media.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            downloadControl
        }
        .padding(.vertical, 4)
        .alert("Download failed", isPresented: .constant(downloadError != nil), actions: {
            Button("OK") { downloadError = nil }
        }, message: {
            Text(downloadError ?? "")
        })
    }

    @ViewBuilder
    private var downloadControl: some View {
        if appState.downloadManager.isDownloaded(item.id) {
            Button(role: .destructive) {
                appState.downloadManager.delete(item.id)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Downloaded — click to remove")
        } else if appState.downloadManager.isDownloading(item.id) {
            ProgressView(value: appState.downloadManager.progress[item.id] ?? 0)
                .frame(width: 60)
        } else {
            Button {
                startDownload()
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.plain)
            .help("Download for offline playback")
        }
    }

    private func startDownload() {
        guard let client = appState.client else { return }
        Task {
            do {
                let detail = try await client.itemDetail(itemId: item.id)
                try await appState.downloadManager.download(item: detail, client: client)
            } catch {
                downloadError = error.localizedDescription
            }
        }
    }
}

func formatDuration(_ seconds: Double) -> String {
    let totalMinutes = Int(seconds) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return "\(hours)h \(minutes)m"
}
