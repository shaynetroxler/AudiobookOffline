import SwiftUI

struct CollectionsListView: View {
    let libraryId: String
    @Binding var path: [LibraryRoute]
    @Environment(AppState.self) private var appState
    @State private var viewModel = CollectionsListViewModel()

    var body: some View {
        List(viewModel.collections) { collection in
            Button {
                path.append(.collection(collection))
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(collection.name).font(.body)
                        Text("\(collection.books.count) book\(collection.books.count == 1 ? "" : "s")")
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
            if viewModel.isLoading && viewModel.collections.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.collections.isEmpty {
                ContentUnavailableView("Can't Reach Server", systemImage: "wifi.slash", description: Text(error))
            } else if !viewModel.isLoading && viewModel.collections.isEmpty {
                ContentUnavailableView("No Collections", systemImage: "square.stack", description: Text("Collections are created on the server and will appear here once you make one."))
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
