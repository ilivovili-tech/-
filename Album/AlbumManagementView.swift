import SwiftUI
import Photos

struct AlbumDetailView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    let album: PHAssetCollection
    @State private var selectedAsset: PHAsset?
    @State private var showPhoto = false
    @State private var errorMessage: String?

    private var items: [PHAsset] { library.assets(in: album) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.localizedTitle ?? "相簿")
                                .font(.system(size: 27, weight: .bold, design: .serif))
                            Text("\(items.count) 张照片与视频")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 24)).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(items, id: \.localIdentifier) { asset in
                            Button {
                                selectedAsset = asset
                                showPhoto = true
                            } label: {
                                AssetThumbnail(asset: asset, contentMode: .fill)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.96, green: 0.95, blue: 0.91))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            // AlbumDetailView is itself presented as a sheet from ContentView.
            // Present the photo viewer full-screen to avoid a nested sheet,
            // which can produce a blank presentation on iOS.
            .fullScreenCover(isPresented: $showPhoto) {
                if let selectedAsset {
                    PhotoDetailView(asset: selectedAsset)
                        .environmentObject(library)
                }
            }
            .alert("无法打开相簿", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

struct CreateAlbumView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("相簿名称") {
                    TextField("例如：旅行、家人、日常", text: $title)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("新相簿会创建在 iPhone 系统照片图库中，可在系统照片 App 中同步查看。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建相簿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "创建中…" : "创建") {
                        isSaving = true
                        Task {
                            do {
                                try await library.createAlbum(named: title)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isSaving = false
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .alert("创建失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
