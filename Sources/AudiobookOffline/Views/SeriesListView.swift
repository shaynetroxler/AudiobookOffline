import SwiftUI

struct SeriesListView: View {
    let libraryId: String
    @Binding var path: [LibraryRoute]
    @Environment(AppState.self) private var appState
    @State private var viewModel = SeriesListViewModel()

    var body: some View {
        List(viewModel.series) { series in
            Button {
                path.append(.series(series))
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(series.name).font(.body)
                        Text("\(series.books.count) book\(series.books.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .overlay {
            if viewModel.isLoading && viewModel.series.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.series.isEmpty {
                ContentUnavailableView("Can't Reach Server", systemImage: "wifi.slash", description: Text(error))
            } else if !viewModel.isLoading && viewModel.series.isEmpty {
                ContentUnavailableView("No Series", systemImage: "books.vertical", description: Text("Series are detected from book metadata on the server and will appear here once books are tagged with one."))
            }
        }
        .onAppear {
            guard let client = appState.client else { return }
            viewModel.configure(libraryId: libraryId, client: client)
        }
        .onChange(of: libraryId) { _, newValue in
            guard let client = appState.client else { return }
            viewModel.configure(libraryId: newValue, client: client)
        }
    }
}
