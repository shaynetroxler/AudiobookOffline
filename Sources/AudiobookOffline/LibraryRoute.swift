import Foundation

enum LibraryRoute: Hashable {
    case item(String)
    case series(ABSSeries)
    case collection(ABSCollection)
}
