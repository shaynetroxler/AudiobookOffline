import Foundation
import Observation

@Observable
@MainActor
final class LibraryListViewModel {
    private(set) var items: [LibraryItem] = []
    private(set) var continueListening: [LibraryItem] = []
    private(set) var isLoading = false
    private(set) var total = 0
    private(set) var errorMessage: String?

    var searchText: String = "" {
        didSet { searchDidChange() }
    }

    private var currentPage = 0
    private let pageSize = 50
    private var searchTask: Task<Void, Never>?
    private var libraryId: String?
    private var client: ABSClient?

    func configure(libraryId: String, client: ABSClient) {
        guard self.libraryId != libraryId else { return }
        self.libraryId = libraryId
        self.client = client
        items = []
        currentPage = 0
        Task { await loadNextPage() }
        Task { await loadContinueListening() }
    }

    /// Re-fetches the Continue Listening shelf without touching the paginated
    /// full list — cheap enough to call every time the library screen appears,
    /// so progress made on another device (e.g. an iPhone) surfaces immediately.
    func refreshContinueListening() async {
        await loadContinueListening()
    }

    private func loadContinueListening() async {
        guard let libraryId, let client else { return }
        do {
            continueListening = try await client.continueListeningShelf(libraryId: libraryId)
        } catch {
            // Non-critical: the full list below still works, just without the shelf.
        }
    }

    /// Removes an item from the Continue Listening shelf. Optimistic: the row disappears
    /// immediately, and if the server call fails it'll simply reappear on the next refresh.
    func removeFromContinueListening(_ item: LibraryItem) async {
        guard let client else { return }
        continueListening.removeAll { $0.id == item.id }
        do {
            try await client.removeFromContinueListening(itemId: item.id)
        } catch {
            print("AudiobookOffline: failed to remove \(item.id) from continue listening: \(error)")
        }
    }

    private func searchDidChange() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            if searchText.isEmpty {
                items = []
                currentPage = 0
                await loadNextPage()
            } else {
                await performSearch()
            }
        }
    }

    private func performSearch() async {
        guard let libraryId, let client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await client.search(libraryId: libraryId, query: searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPage() async {
        guard !isLoading, searchText.isEmpty, let libraryId, let client else { return }
        if !items.isEmpty && items.count >= total { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await client.items(libraryId: libraryId, page: currentPage, limit: pageSize)
            items.append(contentsOf: page.results)
            total = page.total
            currentPage += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
