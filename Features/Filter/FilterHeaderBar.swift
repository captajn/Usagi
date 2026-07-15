import SwiftUI

struct FilterHeaderBar: View {
    @Binding var filter: MangaListFilter
    var onFilterTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: onFilterTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        if filter.isNotEmpty {
                            Text("\(activeFilterCount) đang bật")
                                .font(.caption)
                        } else {
                            Text("Bộ lọc")
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(filter.isNotEmpty ? UsagiTheme.accent.opacity(0.15) : Color(.systemGray6))
                    .foregroundStyle(filter.isNotEmpty ? UsagiTheme.accent : .secondary)
                    .clipShape(Capsule())
                }

                if filter.sortOrder != .popular {
                    FilterChip(label: filter.sortOrder.displayName) {
                        filter.sortOrder = .popular
                    }
                }

                ForEach(filter.tags) { tag in
                    FilterChip(label: tag.title) {
                        filter.tags.removeAll { $0.id == tag.id }
                    }
                }

                ForEach(filter.contentRating) { rating in
                    FilterChip(label: rating.displayName) {
                        filter.contentRating.removeAll { $0 == rating }
                    }
                }

                ForEach(filter.states) { state in
                    FilterChip(label: state.displayName) {
                        filter.states.removeAll { $0 == state }
                    }
                }

                if !filter.query.isEmpty {
                    FilterChip(label: "\"\(filter.query)\"") {
                        filter.query = ""
                    }
                }

                if !filter.author.isEmpty {
                    FilterChip(label: filter.author) {
                        filter.author = ""
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if !filter.query.isEmpty { count += 1 }
        count += filter.tags.count
        count += filter.contentRating.count
        count += filter.states.count
        if !filter.author.isEmpty { count += 1 }
        if filter.year != nil { count += 1 }
        return count
    }
}

struct FilterChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            Image(systemName: "xmark")
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .onTapGesture { onRemove() }
    }
}
