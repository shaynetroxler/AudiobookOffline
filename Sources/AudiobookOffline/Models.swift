import Foundation

struct ABSLibrary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let mediaType: String
}

struct LibrariesResponse: Codable {
    let libraries: [ABSLibrary]
}

struct BookMetadata: Codable, Hashable {
    let title: String
    let subtitle: String?
    let authorName: String?
    let narratorName: String?
    let seriesName: String?
    let description: String?
    let publishedYear: String?
}

struct MediaSummary: Codable, Hashable {
    let metadata: BookMetadata
    let coverPath: String?
    let duration: Double?
    let numTracks: Int?
}

struct LibraryItem: Codable, Identifiable, Hashable {
    let id: String
    let libraryId: String
    let media: MediaSummary
}

struct ItemsPage: Codable {
    let results: [LibraryItem]
    let total: Int
    let limit: Int
    let page: Int
}

struct Chapter: Codable, Hashable, Identifiable {
    let id: Int
    let start: Double
    let end: Double
    let title: String
}

struct Track: Codable, Hashable, Identifiable {
    let index: Int
    let duration: Double
    let contentUrl: String
    let mimeType: String
    let title: String

    var id: Int { index }
}

struct MediaDetail: Codable, Hashable {
    let metadata: BookMetadata
    let coverPath: String?
    let duration: Double?
    let tracks: [Track]
    let chapters: [Chapter]
}

struct LibraryItemDetail: Codable, Identifiable, Hashable {
    let id: String
    let libraryId: String
    let media: MediaDetail
}

struct BookSearchResult: Codable {
    let libraryItem: LibraryItem
}

struct AuthorSearchResult: Codable {
    let id: String
    let name: String
}

struct SearchResponse: Codable {
    let book: [BookSearchResult]
    let authors: [AuthorSearchResult]
}

struct AuthorItemsResponse: Codable {
    let libraryItems: [LibraryItem]
}

struct MediaProgress: Codable, Hashable {
    let id: String?
    let libraryItemId: String
    let duration: Double
    let progress: Double
    let currentTime: Double
    let isFinished: Bool
    let lastUpdate: Double?
}

struct LoginUser: Codable {
    let id: String
    let username: String
    let token: String
    let mediaProgress: [MediaProgress]
}

struct LoginResponse: Codable {
    let user: LoginUser
}

struct ProgressPatchBody: Codable {
    let currentTime: Double
    let duration: Double
    let progress: Double
    let isFinished: Bool
}
