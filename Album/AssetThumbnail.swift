import SwiftUI
import Photos

/// A reusable PhotoKit thumbnail view. The image is requested at the
/// rendered size instead of decoding the full-resolution asset.
struct AssetThumbnail: View {
    let asset: PHAsset
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.12))
                        .overlay {
                            Image(systemName: asset.mediaType == .video ? "video" : "photo")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                requestThumbnail(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                requestThumbnail(for: newSize)
            }
            .onDisappear {
                cancelRequest()
            }
        }
    }

    private func requestThumbnail(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        cancelRequest()
        image = nil

        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: max(1, size.width * scale),
            height: max(1, size.height * scale)
        )

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode == .fill ? .aspectFill : .aspectFit,
            options: options
        ) { result, info in
            if (info?[PHImageCancelledKey] as? Bool) == true { return }
            DispatchQueue.main.async {
                if let result {
                    image = result
                }
            }
        }
    }

    private func cancelRequest() {
        guard requestID != PHInvalidImageRequestID else { return }
        PHImageManager.default().cancelImageRequest(requestID)
        requestID = PHInvalidImageRequestID
    }
}
