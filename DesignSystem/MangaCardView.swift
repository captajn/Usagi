import SwiftUI

struct MangaCardView: View {
    let manga: Manga

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MangaCoverView(urlString: manga.coverURL)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            Text(manga.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 32, alignment: .top)

            Text(manga.state.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct MangaRowView: View {
    let manga: Manga
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            MangaCoverView(urlString: manga.coverURL, cornerRadius: 8)
                .frame(width: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(subtitle ?? manga.authorsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label(manga.state.displayName, systemImage: "circle.fill")
                        .labelStyle(.titleOnly)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if manga.rating >= 0 {
                        Label(manga.ratingText, systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
