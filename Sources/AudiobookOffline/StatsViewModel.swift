import Foundation
import Observation

@Observable
@MainActor
final class StatsViewModel {
    private(set) var stats: LibraryStats?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load(libraryId: String, client: ABSClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            stats = try await client.stats(libraryId: libraryId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
