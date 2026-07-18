import Foundation

enum ABSError: Error, LocalizedError {
    case badResponse(Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "Server responded with status \(code)"
        case .invalidURL: return "Invalid URL"
        }
    }
}

struct ABSClient {
    let baseURL: URL
    let token: String

    private var decoder: JSONDecoder {
        JSONDecoder()
    }

    static func login(serverURL: URL, username: String, password: String) async throws -> LoginResponse {
        var request = URLRequest(url: serverURL.appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["username": username, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    private static func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ABSError.badResponse(code)
        }
    }

    private func authedRequest(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw ABSError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw ABSError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    func libraries() async throws -> [ABSLibrary] {
        let request = try authedRequest(path: "api/libraries")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(LibrariesResponse.self, from: data).libraries
    }

    func items(libraryId: String, page: Int, limit: Int = 50) async throws -> ItemsPage {
        let request = try authedRequest(
            path: "api/libraries/\(libraryId)/items",
            query: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "sort", value: "media.metadata.title"),
            ]
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(ItemsPage.self, from: data)
    }

    func search(libraryId: String, query: String) async throws -> [LibraryItem] {
        let request = try authedRequest(
            path: "api/libraries/\(libraryId)/search",
            query: [URLQueryItem(name: "q", value: query)]
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        let result = try JSONDecoder().decode(SearchResponse.self, from: data)

        var items = result.book.map(\.libraryItem)
        var seenIds = Set(items.map(\.id))

        // The server's `book` matches are title/metadata substring matches only; an
        // author-name search (e.g. surname with no title overlap) comes back solely
        // in `authors`, so fetch each matched author's books and merge them in.
        for author in result.authors {
            guard let authorItems = try? await authorItems(authorId: author.id) else { continue }
            for item in authorItems where !seenIds.contains(item.id) {
                items.append(item)
                seenIds.insert(item.id)
            }
        }
        return items
    }

    func authorItems(authorId: String) async throws -> [LibraryItem] {
        let request = try authedRequest(path: "api/authors/\(authorId)", query: [URLQueryItem(name: "include", value: "items")])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(AuthorItemsResponse.self, from: data).libraryItems
    }

    func itemDetail(itemId: String) async throws -> LibraryItemDetail {
        let request = try authedRequest(path: "api/items/\(itemId)", query: [URLQueryItem(name: "expanded", value: "1")])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(LibraryItemDetail.self, from: data)
    }

    func mediaProgress() async throws -> [MediaProgress] {
        let request = try authedRequest(path: "api/me")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        struct MeResponse: Codable { let mediaProgress: [MediaProgress] }
        return try JSONDecoder().decode(MeResponse.self, from: data).mediaProgress
    }

    /// The same "Continue Listening" shelf shown on the ABS server's own home page —
    /// unlike `/api/me/items-in-progress` (Android Auto's endpoint), this one respects
    /// a book being hidden via `removeFromContinueListening`, so removal actually sticks.
    /// The personalized-shelves response mixes several shelf types with different entity
    /// shapes, so we pick out just the "continue-listening" shelf's entities by hand
    /// rather than decoding the whole heterogeneous payload as one Codable type.
    func continueListeningShelf(libraryId: String, limit: Int = 25) async throws -> [LibraryItem] {
        let request = try authedRequest(
            path: "api/libraries/\(libraryId)/personalized", query: [URLQueryItem(name: "limit", value: String(limit))]
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        guard let shelves = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        guard let shelf = shelves.first(where: { $0["id"] as? String == "continue-listening" }) else { return [] }
        guard let entities = shelf["entities"] else { return [] }
        let entitiesData = try JSONSerialization.data(withJSONObject: entities)
        return try JSONDecoder().decode([LibraryItem].self, from: entitiesData)
    }

    /// Hides a book from the Continue Listening shelf without altering its saved
    /// position — matches the ABS server's own "remove from continue listening" affordance.
    func removeFromContinueListening(itemId: String) async throws {
        guard let progressId = try await mediaProgress().first(where: { $0.libraryItemId == itemId })?.id else { return }
        let request = try authedRequest(path: "api/me/progress/\(progressId)/remove-from-continue-listening")
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
    }

    func updateProgress(itemId: String, currentTime: Double, duration: Double, isFinished: Bool) async throws {
        var request = try authedRequest(path: "api/me/progress/\(itemId)")
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let progress = duration > 0 ? currentTime / duration : 0
        let body = ProgressPatchBody(currentTime: currentTime, duration: duration, progress: progress, isFinished: isFinished)
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
    }

    /// Collections and series a user has curated on the server. Fetched with no
    /// limit/page — the server treats an absent limit as "return everything",
    /// which is fine since these lists are small compared to the full item list.
    func collections(libraryId: String) async throws -> [ABSCollection] {
        let request = try authedRequest(path: "api/libraries/\(libraryId)/collections")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(CollectionsResponse.self, from: data).results
    }

    func series(libraryId: String) async throws -> [ABSSeries] {
        // Unlike /collections (which slices in JS and treats a missing/zero limit as
        // "no limit"), /series applies `limit` as a literal Sequelize LIMIT clause —
        // an omitted or zero limit produces `LIMIT 0`, i.e. zero rows. Pass a limit
        // generously above any realistic series count to fetch everything in one call.
        let request = try authedRequest(
            path: "api/libraries/\(libraryId)/series",
            query: [
                URLQueryItem(name: "sort", value: "name"),
                URLQueryItem(name: "limit", value: "5000"),
            ]
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(SeriesResponse.self, from: data).results
    }

    func stats(libraryId: String) async throws -> LibraryStats {
        let request = try authedRequest(path: "api/libraries/\(libraryId)/stats")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response)
        return try JSONDecoder().decode(LibraryStats.self, from: data)
    }

    func coverURL(itemId: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/items/\(itemId)/cover"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        return components?.url
    }

    /// contentUrl from a Track is a server-relative path like "/api/items/{id}/file/{ino}"
    func absoluteURL(forContentPath contentPath: String) -> URL? {
        var path = contentPath
        if path.hasPrefix("/") { path.removeFirst() }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        return components?.url
    }
}
