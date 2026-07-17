import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LibraryListViewModel()
    @State private var path: [String] = []

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(appState.libraries, selection: $appState.selectedLibrary) { library in
                Label(library.name, systemImage: "books.vertical")
                    .tag(library)
            }
            .navigationTitle("Libraries")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Log Out") { appState.logout() }
                }
            }
        } detail: {
            NavigationStack(path: $path) {
                itemsList
                    .navigationDestination(for: String.self) { itemId in
                        PlayerHostView(itemId: itemId)
                    }
            }
        }
        .onChange(of: appState.selectedLibrary) { _, newValue in
            guard let newValue, let client = appState.client else { return }
            viewModel.configure(libraryId: newValue.id, client: client)
        }
        .onAppear {
            guard let library = appState.selectedLibrary, let client = appState.client else { return }
            viewModel.configure(libraryId: library.id, client: client)
        }
    }

    @ViewBuilder
    private var itemsList: some View {
        @Bindable var viewModel = viewModel
        List {
            ForEach(viewModel.items) { item in
                Button {
                    path.append(item.id)
                } label: {
                    ItemRow(item: item)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if item.id == viewModel.items.last?.id {
                        Task { await viewModel.loadNextPage() }
                    }
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search books")
        .navigationTitle(appState.selectedLibrary?.name ?? "Library")
        .overlay {
            if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                ContentUnavailableView(
                    "Can't Reach Server",
                    systemImage: "wifi.slash",
                    description: Text(error)
                )
            }
        }
    }
}
