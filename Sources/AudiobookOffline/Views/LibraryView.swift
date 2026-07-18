import SwiftUI

enum LibraryTab: String, CaseIterable, Identifiable {
    case books = "Books"
    case series = "Series"
    case collections = "Collections"
    var id: String { rawValue }
}

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LibraryListViewModel()
    @State private var path: [LibraryRoute] = []
    @State private var showingStats = false
    @State private var selectedTab: LibraryTab = .books

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
                tabContent
                    .navigationDestination(for: LibraryRoute.self) { route in
                        switch route {
                        case .item(let itemId):
                            PlayerHostView(itemId: itemId)
                        case .series(let series):
                            SeriesDetailView(series: series, path: $path)
                        case .collection(let collection):
                            CollectionDetailView(collection: collection, path: $path)
                        }
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
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .books:
                itemsList
            case .series:
                if let library = appState.selectedLibrary {
                    SeriesListView(libraryId: library.id, path: $path)
                }
            case .collections:
                if let library = appState.selectedLibrary {
                    CollectionsListView(libraryId: library.id, path: $path)
                }
            }
        }
        .navigationTitle(appState.selectedLibrary?.name ?? "Library")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showingStats = true
                } label: {
                    Label("Stats", systemImage: "chart.bar.xaxis")
                }
                .disabled(appState.selectedLibrary == nil)
            }
        }
        .sheet(isPresented: $showingStats) {
            if let library = appState.selectedLibrary {
                StatsView(libraryId: library.id, libraryName: library.name)
            }
        }
    }

    @ViewBuilder
    private var itemsList: some View {
        @Bindable var viewModel = viewModel
        List {
            ForEach(viewModel.items) { item in
                Button {
                    path.append(.item(item.id))
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
