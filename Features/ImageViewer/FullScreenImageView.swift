import SwiftUI

/// Full-screen image viewer for manga pages / cover art — mirrors Android image/ module.
struct FullScreenImageView: View {
    let imageURL: String
    let title: String?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1 { scale = 1; lastScale = 1 }
                                    if scale > 5 { scale = 5; lastScale = 5 }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture {
                            dismiss()
                        }
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Không thể tải ảnh")
                            .foregroundStyle(.secondary)
                    }
                default:
                    ProgressView()
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let title {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            if scale > 1 {
                Text("\(Int(scale * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
            }
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
    }
}
