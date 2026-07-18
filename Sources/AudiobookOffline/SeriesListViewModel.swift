import Foundation
import Observation

@Observable
@MainActor
final class SeriesListViewModel {
    private(set) var series: [ABSSeries] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var libraryId: String?

    func configure(libraryId: String, client: ABSClient) {
        guard self.libraryId != libraryId else { return }
        self.libraryId = libraryId
        series = []
        Task { await load(client: client) }
    }

    private func load(client: ABSClient) async {
        guard let libraryId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            series = try await client.series(libraryId: libraryId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
