import SwiftUI
import Photos
import AVKit

struct PhotoDetailView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset
    @State private var feedbackMessage: String?
    @State private var player: AVPlayer?
    @State private var videoLoadingFailed = false

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
                            if asset.mediaSubtypes.contains(.photoLive) {
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
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
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
