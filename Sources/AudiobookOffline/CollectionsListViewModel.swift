import Foundation
import Observation

@Observable
@MainActor
final class CollectionsListViewModel {
    private(set) var collections: [ABSCollection] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var libraryId: String?

    func configure(libraryId: String, client: ABSClient) {
        guard self.libraryId != libraryId else { return }
        self.libraryId = libraryId
        collections = []
        Task { await load(client: client) }
    }

    private func load(client: ABSClient) async {
        guard let libraryId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            collections = try await client.collections(libraryId: libraryId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
