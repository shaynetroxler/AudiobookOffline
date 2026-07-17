import Foundation
import Observation

@Observable
@MainActor
final class LibraryListViewModel {
    private(set) var items: [LibraryItem] = []
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
