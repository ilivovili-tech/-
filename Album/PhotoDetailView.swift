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
    @State private var isPressingLivePhoto = false
    @State private var livePhotoLoaded = false
    @State private var videoRequestID: PHImageRequestID = PHInvalidImageRequestID

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
                            LivePhotoPlayerView(asset: asset, isPressing: $isPressingLivePhoto, onLoaded: {
                                livePhotoLoaded = true
                            }, onFailure: {
                                livePhotoLoadingFailed = true
                            })
                            .id(asset.localIdentifier)
                            .onLongPressGesture(minimumDuration: 0.22, pressing: { pressing in
                                isPressingLivePhoto = pressing
                            }, perform: {})
                            .overlay {
                                if !livePhotoLoaded {
                                    VStack(spacing: 9) {
                                        ProgressView().tint(.white)
                                        Text("正在加载实况照片…")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.75))
                                    }
                                    .allowsHitTesting(false)
                                }
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
                        } else if isLivePhoto && livePhotoLoadingFailed {
                            ZStack(alignment: .bottom) {
                                PhotoDetailImageView(asset: asset)
                                    .id(asset.localIdentifier)
                                Button {
                                    livePhotoLoaded = false
                                    livePhotoLoadingFailed = false
                                    isPressingLivePhoto = false
                                } label: {
                                    Label("重新加载实况", systemImage: "livephoto")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(.black.opacity(0.65), in: Capsule())
                                }
                                .padding(.bottom, 18)
                            }
                        } else {
                            PhotoDetailImageView(asset: asset)
                                .id(asset.localIdentifier)
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
            .onDisappear {
                player?.pause()
                player = nil
                if videoRequestID != PHInvalidImageRequestID {
                    PHImageManager.default().cancelImageRequest(videoRequestID)
                    videoRequestID = PHInvalidImageRequestID
                }
            }
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
        videoRequestID = PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                guard videoRequestID != PHInvalidImageRequestID else { return }
                videoRequestID = PHInvalidImageRequestID
                if let avAsset {
                    player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                } else {
                    videoLoadingFailed = true
                }
            }
        }
    }
}



/// Full-size PhotoKit viewer. Keeps the request alive through SwiftUI layout changes
/// and displays degraded previews while the final/iCloud image is being delivered.
private struct PhotoDetailImageView: View {
    let asset: PHAsset
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var failed = false
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID
    @State private var requestToken = UUID()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if failed {
                    VStack(spacing: 12) {
                        Image(systemName: "icloud.slash")
                            .font(.system(size: 32, weight: .light))
                        Text("照片加载失败")
                            .font(.system(size: 16, weight: .medium))
                        Text("原片可能尚未从 iCloud 下载，请检查网络后重试。")
                            .font(.system(size: 12))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.7))
                        Button("重新加载") { load(size: geometry.size, force: true) }
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                } else {
                    VStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("正在加载原始照片…")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear { load(size: geometry.size) }
            .onChange(of: geometry.size) { _, newSize in
                // Presentation animations can change GeometryReader size several times.
                // Never cancel a valid PhotoKit request just because layout is settling.
                if image == nil && requestID == PHInvalidImageRequestID && !failed {
                    load(size: newSize)
                }
            }
            .onDisappear { cancel() }
        }
    }

    private func load(size: CGSize, force: Bool = false) {
        guard size.width > 0, size.height > 0 else { return }
        if !force && requestID != PHInvalidImageRequestID { return }
        cancel()

        image = nil
        failed = false
        isLoading = true
        let token = requestToken
        let scale = max(1, displayScale)
        // Request enough pixels for a sharp full-screen image without depending on
        // transient zero/small geometry values during the cover transition.
        let target = CGSize(
            width: max(1200, size.width * scale),
            height: max(1600, size.height * scale)
        )

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.progressHandler = { _, error, _, _ in
            guard error == nil else {
                DispatchQueue.main.async {
                    guard token == requestToken else { return }
                    failed = true
                    isLoading = false
                    requestID = PHInvalidImageRequestID
                }
                return
            }
        }

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFit,
            options: options
        ) { result, info in
            DispatchQueue.main.async {
                guard token == requestToken else { return }
                if (info?[PHImageCancelledKey] as? Bool) == true { return }

                if let error = info?[PHImageErrorKey] as? Error {
                    _ = error
                    if image == nil {
                        failed = true
                    }
                    isLoading = false
                    requestID = PHInvalidImageRequestID
                    return
                }

                if let result {
                    // Opportunistic delivery may first provide a quick preview.
                    // Show it immediately instead of leaving the viewer black.
                    image = result
                    failed = false
                    if (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                        isLoading = false
                        requestID = PHInvalidImageRequestID
                    }
                } else if (info?[PHImageResultIsInCloudKey] as? Bool) != true {
                    failed = true
                    isLoading = false
                    requestID = PHInvalidImageRequestID
                }
            }
        }
    }

    private func cancel() {
        requestToken = UUID()
        guard requestID != PHInvalidImageRequestID else { return }
        PHImageManager.default().cancelImageRequest(requestID)
        requestID = PHInvalidImageRequestID
    }
}

private struct LivePhotoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    @Binding var isPressing: Bool
    let onLoaded: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoaded: onLoaded, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        context.coordinator.requestLivePhoto(for: asset, in: view)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        context.coordinator.onLoaded = onLoaded
        context.coordinator.onFailure = onFailure
        context.coordinator.updatePlayback(isPressing: isPressing, in: uiView)
    }

    static func dismantleUIView(_ uiView: PHLivePhotoView, coordinator: Coordinator) {
        coordinator.stopPlayback(in: uiView)
        if coordinator.requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(coordinator.requestID)
            coordinator.requestID = PHInvalidImageRequestID
        }
        uiView.livePhoto = nil
    }

    final class Coordinator {
        var requestID: PHImageRequestID = PHInvalidImageRequestID
        var onLoaded: () -> Void
        var onFailure: () -> Void
        private var isPlaying = false
        private var hasLoaded = false

        init(onLoaded: @escaping () -> Void, onFailure: @escaping () -> Void) {
            self.onLoaded = onLoaded
            self.onFailure = onFailure
        }

        func requestLivePhoto(for asset: PHAsset, in view: PHLivePhotoView) {
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            let screenTarget = CGSize(width: 2048, height: 2048)
            requestID = PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: screenTarget,
                contentMode: .aspectFit,
                options: options
            ) { [weak view, weak self] livePhoto, info in
                DispatchQueue.main.async {
                    guard let self, let view else { return }
                    if (info?[PHImageCancelledKey] as? Bool) == true { return }
                    if let livePhoto {
                        view.livePhoto = livePhoto
                        if !self.hasLoaded {
                            self.hasLoaded = true
                            self.onLoaded()
                        }
                        if self.requestID != PHInvalidImageRequestID {
                            self.requestID = PHInvalidImageRequestID
                        }
                    } else if let error = info?[PHImageErrorKey] as? Error {
                        _ = error
                        self.onFailure()
                    } else if (info?[PHImageResultIsInCloudKey] as? Bool) != true {
                        self.onFailure()
                    }
                }
            }
        }

        func updatePlayback(isPressing: Bool, in view: PHLivePhotoView) {
            guard hasLoaded, view.livePhoto != nil else { return }
            if isPressing && !isPlaying {
                isPlaying = true
                view.startPlayback(with: .full)
            } else if !isPressing && isPlaying {
                stopPlayback(in: view)
            }
        }

        func stopPlayback(in view: PHLivePhotoView) {
            guard isPlaying else { return }
            isPlaying = false
            view.stopPlayback()
        }
    }
}
