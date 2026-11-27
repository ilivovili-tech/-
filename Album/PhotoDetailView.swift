import SwiftUI
import Photos
import PhotosUI
import AVKit

struct PhotoDetailView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset
    @State private var feedbackMessage: String?
    @State private var player: AVPlayer?
    @State private var videoLoadingFailed = false
    @State private var livePhotoLoadingFailed = false

    private var isLivePhoto: Bool {
        asset.mediaType == .image && asset.mediaSubtypes.contains(.photoLive)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 18) {
                    Group {
                        if asset.mediaType == .video {
                            if let player {
                                VideoPlayer(player: player)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else if videoLoadingFailed {
                                ContentUnavailableView("视频暂时无法播放", systemImage: "video.slash", description: Text("请检查网络连接或稍后重试。"))
                                    .foregroundStyle(.white)
                            } else {
                                VStack(spacing: 12) {
                                    ProgressView().tint(.white)
                                    Text("正在加载视频…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        } else if isLivePhoto && !livePhotoLoadingFailed {
                            LivePhotoPlayerView(asset: asset) {
                                livePhotoLoadingFailed = true
                            }
                            .overlay(alignment: .bottom) {
                                Label("按住照片播放实况", systemImage: "livephoto")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.black.opacity(0.55), in: Capsule())
                                    .padding(.bottom, 14)
                                    .allowsHitTesting(false)
                            }
                        } else {
                            AssetThumbnail(asset: asset, contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    VStack(spacing: 7) {
                        Text(asset.creationDate?.formatted(date: .long, time: .shortened) ?? "拍摄日期未知")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        HStack(spacing: 14) {
                            Label(asset.mediaType == .video ? "视频" : "照片", systemImage: asset.mediaType == .video ? "video" : "photo")
                            if isLivePhoto {
                                Label("实况", systemImage: "livephoto")
                            }
                            Text("\(Int(asset.pixelWidth)) × \(Int(asset.pixelHeight))")
                        }
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 14)
            }
            .task { loadVideoIfNeeded() }
            .onDisappear { player?.pause() }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("相簿操作", isPresented: Binding(get: { feedbackMessage != nil }, set: { if !$0 { feedbackMessage = nil } })) { Button("好", role: .cancel) { feedbackMessage = nil } } message: { Text(feedbackMessage ?? "") }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if library.albums.isEmpty {
                            Text("请先在“相册”页面创建相簿")
                        } else {
                            ForEach(library.albums, id: \.localIdentifier) { album in
                                Button(album.localizedTitle ?? "未命名相簿") {
                                    Task {
                                        do {
                                            try await library.add(asset, to: album)
                                            feedbackMessage = "已添加到 \(album.localizedTitle ?? "相簿")"
                                        } catch {
                                            feedbackMessage = "添加失败：\(error.localizedDescription)"
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "folder.badge.plus").foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }

    private func loadVideoIfNeeded() {
        guard asset.mediaType == .video, player == nil else { return }
        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                if let avAsset {
                    player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                } else {
                    videoLoadingFailed = true
                }
            }
        }
    }
}

private struct LivePhotoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFailure: onFailure)
    }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFit
        context.coordinator.requestLivePhoto(for: asset, in: view)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        context.coordinator.onFailure = onFailure
    }

    static func dismantleUIView(_ uiView: PHLivePhotoView, coordinator: Coordinator) {
        if coordinator.requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(coordinator.requestID)
        }
        uiView.livePhoto = nil
    }

    final class Coordinator {
        var requestID: PHImageRequestID = PHInvalidImageRequestID
        var onFailure: () -> Void

        init(onFailure: @escaping () -> Void) {
            self.onFailure = onFailure
        }

        func requestLivePhoto(for asset: PHAsset, in view: PHLivePhotoView) {
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            // A screen-sized Live Photo is sufficient for the detail viewer.
            // Avoid requesting the full original dimensions, which can create large
            // transient memory spikes on high-resolution camera captures.
            let screenTarget = CGSize(width: 2048, height: 2048)
            requestID = PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: screenTarget,
                contentMode: .aspectFit,
                options: options
            ) { [weak view, weak self] livePhoto, info in
                DispatchQueue.main.async {
                    guard let self, let view else { return }
                    if let livePhoto {
                        view.livePhoto = livePhoto
                    } else if (info?[PHImageCancelledKey] as? Bool) != true {
                        self.onFailure()
                    }
                }
            }
        }
    }
}
