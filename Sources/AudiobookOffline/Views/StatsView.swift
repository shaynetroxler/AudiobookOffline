import SwiftUI

struct StatsView: View {
    let libraryId: String
    let libraryName: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(libraryName)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
                .task {
                    guard let client = appState.client else { return }
                    await viewModel.load(libraryId: libraryId, client: client)
                }
        }
        .frame(minWidth: 640, minHeight: 560)
    }

    @ViewBuilder
    private var content: some View {
        if let stats = viewModel.stats {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    summaryTiles(stats)

                    HStack(alignment: .top, spacing: 32) {
                        genresSection(stats)
                        authorsSection(stats)
                    }

                    HStack(alignment: .top, spacing: 32) {
                        longestItemsSection(stats)
                        largestItemsSection(stats)
                    }
                }
                .padding(24)
            }
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Can't Load Stats",
                systemImage: "chart.bar.xaxis",
                description: Text(viewModel.errorMessage ?? "Unknown error")
            )
        }
    }

    // MARK: - Summary tiles

    private func summaryTiles(_ stats: LibraryStats) -> some View {
        let tiles: [(icon: String, value: String, label: String)] = [
            ("chart.bar", Self.groupedInt(stats.totalItems), "Items in Library"),
            ("chart.line.uptrend.xyaxis", Self.groupedInt(Int(stats.totalDuration / 3600)), "Overall Hours"),
            ("person", Self.groupedInt(stats.totalAuthors ?? 0), "Authors"),
            ("doc", Self.oneDecimal(stats.totalSize / 1_000_000_000), "Size (GB)"),
            ("doc.text", Self.groupedInt(stats.numAudioTracks), "Audio Tracks"),
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
            ForEach(tiles, id: \.label) { tile in
                VStack(alignment: .leading, spacing: 6) {
                    Label(tile.value, systemImage: tile.icon)
                        .font(.title2.bold())
                    Text(tile.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Genres / authors

    private func genresSection(_ stats: LibraryStats) -> some View {
        let top = Array(stats.genresWithCount.sorted { $0.count > $1.count }.prefix(5))
        let maxCount = max(top.map(\.count).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 16) {
            Text("Top 5 Genres").font(.title3.bold())
            ForEach(top) { genre in
                barRow(
                    leading: "\(percentage(genre.count, of: stats.totalItems))%",
                    label: genre.genre,
                    fraction: Double(genre.count) / Double(maxCount)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func authorsSection(_ stats: LibraryStats) -> some View {
        let top = stats.authorsWithCount ?? []
        let maxCount = max(top.map(\.count).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Top 10 Authors").font(.title3.bold())
            ForEach(Array(top.enumerated()), id: \.element.id) { index, author in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(author.name)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 100, alignment: .leading)
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * (Double(author.count) / Double(maxCount)))
                    }
                    .frame(height: 8)
                    Text("\(author.count)")
                        .font(.caption.bold())
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barRow(leading: String, label: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(leading).font(.title3.bold())
                Spacer()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(geo.size.width * fraction, 4))
            }
            .frame(height: 6)
        }
    }

    // MARK: - Longest / largest

    private func longestItemsSection(_ stats: LibraryStats) -> some View {
        let items = Array(stats.longestItems.prefix(5))
        let maxDuration = max(items.map(\.duration).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Longest Items (hrs)").font(.title3.bold())
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                rankedRow(
                    index: index,
                    title: item.title,
                    value: Self.oneDecimal(item.duration / 3600),
                    fraction: item.duration / maxDuration
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func largestItemsSection(_ stats: LibraryStats) -> some View {
        let items = Array(stats.largestItems.prefix(5))
        let maxSize = max(items.map(\.size).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Largest Items").font(.title3.bold())
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                rankedRow(
                    index: index,
                    title: item.title,
                    value: "\(Self.twoDecimal(item.size / 1_000_000_000)) GB",
                    fraction: item.size / maxSize
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rankedRow(index: Int, title: String, value: String, fraction: Double) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
            GeometryReader { geo in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(geo.size.width * fraction, 4))
            }
            .frame(height: 8)
            Text(value)
                .font(.caption.bold())
                .frame(width: 56, alignment: .trailing)
        }
    }

    // MARK: - Formatting

    private func percentage(_ count: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total) * 100).rounded())
    }

    private static func groupedInt(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func twoDecimal(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
