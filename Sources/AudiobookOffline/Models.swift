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

struct AuthorWithCount: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int
}

struct GenreWithCount: Codable, Identifiable, Hashable {
    let genre: String
    let count: Int

    var id: String { genre }
}

struct LongestItemStat: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let duration: Double
}

struct LargestItemStat: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let size: Double
}

/// Mirrors the Audiobookshelf server's GET /api/libraries/{id}/stats response.
/// `totalAuthors`/`authorsWithCount` are absent for podcast libraries.
struct LibraryStats: Codable {
    let totalItems: Int
    let totalSize: Double
    let totalDuration: Double
    let numAudioTracks: Int
    let totalAuthors: Int?
    let authorsWithCount: [AuthorWithCount]?
    let totalGenres: Int
    let genresWithCount: [GenreWithCount]
    let longestItems: [LongestItemStat]
    let largestItems: [LargestItemStat]
}

struct ABSCollection: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let books: [LibraryItem]
}

struct CollectionsResponse: Codable {
    let results: [ABSCollection]
}

/// A library item as it appears inside a series' `books` array — same shape as
/// `LibraryItem` plus the item's position within that series.
struct SeriesBookItem: Codable, Identifiable, Hashable {
    let id: String
    let libraryId: String
    let media: MediaSummary
    let sequence: String?

    var asLibraryItem: LibraryItem { LibraryItem(id: id, libraryId: libraryId, media: media) }
}

struct ABSSeries: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let books: [SeriesBookItem]
}

struct SeriesResponse: Codable {
    let results: [ABSSeries]
}
