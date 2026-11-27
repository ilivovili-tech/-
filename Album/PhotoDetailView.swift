import SwiftUI
import Photos

struct PhotoDetailView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 18) {
                    AssetThumbnail(asset: asset, contentMode: .fit)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }
}
