import SwiftUI
import UIKit

/// UIScrollView zoom/pan — maps Android SSIV.
struct ZoomablePageView: UIViewRepresentable {
    let urlString: String
    var onTap: (() -> Void)?
    var onDoubleTapZone: ((CGPoint, CGSize) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onDoubleTapZone: onDoubleTapZone)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .black
        scroll.bouncesZoom = true

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.tag = 100
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scroll

        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        single.numberOfTapsRequired = 1
        scroll.addGestureRecognizer(single)

        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        double.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(double)
        single.require(toFail: double)

        context.coordinator.load(urlString: urlString)
        return scroll
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onDoubleTapZone = onDoubleTapZone
        if context.coordinator.loadedURL != urlString {
            context.coordinator.load(urlString: urlString)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        var onTap: (() -> Void)?
        var onDoubleTapZone: ((CGPoint, CGSize) -> Void)?
        var loadedURL: String?

        init(onTap: (() -> Void)?, onDoubleTapZone: ((CGPoint, CGSize) -> Void)?) {
            self.onTap = onTap
            self.onDoubleTapZone = onDoubleTapZone
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func load(urlString: String) {
            loadedURL = urlString
            if urlString.hasPrefix("file://"), let url = URL(string: urlString),
               let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                apply(image)
                return
            }
            if !urlString.hasPrefix("http"), FileManager.default.fileExists(atPath: urlString),
               let image = UIImage(contentsOfFile: urlString) {
                apply(image)
                return
            }
            guard let url = URL(string: urlString) else { return }
            Task {
                let pipeline = await MainActor.run { ImagePipeline.shared }
                let image = await pipeline.load(urlString: url.absoluteString)
                await MainActor.run { if let image { self.apply(image) } }
            }
        }

        private func apply(_ image: UIImage) {
            guard let imageView, let scrollView else { return }
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: scrollView.bounds.size)
            if imageView.frame.size == .zero {
                imageView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            }
            scrollView.contentSize = imageView.bounds.size
            scrollView.zoomScale = 1
            layoutImage()
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            layoutImage()
        }

        private func layoutImage() {
            guard let imageView, let scrollView else { return }
            let bounds = scrollView.bounds.size
            let offsetX = max((bounds.width - imageView.frame.width) * 0.5, 0)
            let offsetY = max((bounds.height - imageView.frame.height) * 0.5, 0)
            imageView.center = CGPoint(
                x: imageView.frame.width * 0.5 + offsetX,
                y: imageView.frame.height * 0.5 + offsetY
            )
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let view = gr.view else { return }
            let point = gr.location(in: view)
            onDoubleTapZone?(point, view.bounds.size)
        }

        @objc func handleDoubleTap(_ gr: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > 1.1 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = gr.location(in: imageView)
                let rect = zoomRect(for: 2.5, center: point)
                scrollView.zoom(to: rect, animated: true)
            }
        }

        private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
            guard let scrollView else { return .zero }
            var rect = CGRect.zero
            rect.size.height = scrollView.frame.height / scale
            rect.size.width = scrollView.frame.width / scale
            rect.origin.x = center.x - rect.size.width / 2
            rect.origin.y = center.y - rect.size.height / 2
            return rect
        }
    }
}
