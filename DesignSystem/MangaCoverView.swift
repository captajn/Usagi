import SwiftUI

struct MangaCoverView: View {
    let urlString: String?
    var cornerRadius: CGFloat = UsagiTheme.cardCorner

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder.overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder.overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder.overlay {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(UsagiTheme.coverAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemFill))
    }
}
