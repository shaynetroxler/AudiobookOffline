import SwiftUI

struct CollectionDetailView: View {
    let collection: ABSCollection
    @Binding var path: [LibraryRoute]

    var body: some View {
        List(collection.books) { item in
            Button {
                path.append(.item(item.id))
            } label: {
                ItemRow(item: item)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(collection.name)
    }
}
