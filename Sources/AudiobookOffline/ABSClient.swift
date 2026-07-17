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
