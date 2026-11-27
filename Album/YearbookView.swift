import SwiftUI
import Photos

struct YearbookView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    let year: Int
    @State private var selectedAsset: PHAsset?
    @State private var showPhotoDetail = false

    private var yearAssets: [PHAsset] { library.assets(in: year) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.95, blue: 0.91).ignoresSafeArea()
                if yearAssets.isEmpty {
                    ContentUnavailableView("这一年还没有照片", systemImage: "book.closed", description: Text("选择其他年份，继续浏览你的时光。"))
                } else {
                    TabView {
                        ForEach(1...12, id: \.self) { month in
                            monthPage(month)
                                .padding(.horizontal, 18)
                                .padding(.top, 12)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .navigationTitle("\(year) 年 · 照片书")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPhotoDetail) {
                if let selectedAsset {
                    PhotoDetailView(asset: selectedAsset).environmentObject(library)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func monthPage(_ month: Int) -> some View {
        let items = yearAssets.filter {
            guard let date = $0.creationDate else { return false }
            return Calendar.current.component(.month, from: date) == month
        }
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline) {
                    Text(String(format: "%02d", month))
                        .font(.system(size: 54, weight: .light, design: .serif))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(month) 月").font(.system(size: 18, weight: .semibold, design: .serif))
                        Text("\(items.count) 个瞬间").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("MEMORIES").font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                }
                Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 1)
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "wind").font(.system(size: 30, weight: .ultraLight))
                        Text("这个月暂时没有照片").font(.system(size: 14, weight: .medium, design: .serif))
                    }
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(items, id: \.localIdentifier) { asset in
                            Button {
                                selectedAsset = asset
                                showPhotoDetail = true
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    AssetThumbnail(asset: asset, contentMode: .fill)
                                        .frame(height: 158).clipShape(RoundedRectangle(cornerRadius: 9))
                                    Text(asset.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "日期未知")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 34)
        }
    }
}
