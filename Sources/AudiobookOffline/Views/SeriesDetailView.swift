import SwiftUI

struct SeriesDetailView: View {
    let series: ABSSeries
    @Binding var path: [LibraryRoute]

    var body: some View {
        List(series.books) { entry in
            Button {
                path.append(.item(entry.id))
            } label: {
                HStack(spacing: 12) {
                    if let sequence = entry.sequence, !sequence.isEmpty {
                        Text("#\(sequence)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .leading)
                    }
                    ItemRow(item: entry.asLibraryItem)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(series.name)
    }
}
