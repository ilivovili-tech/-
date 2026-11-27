import SwiftUI
import Photos

struct YearbookView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    let year: Int
    @State private var selectedAsset: PHAsset?
    @State private var showPhotoDetail = false
    @State private var displayedMonth = 1
    @State private var pageRotation = 0.0
    @State private var isTurningPage = false

    private var yearAssets: [PHAsset] { library.assets(in: year) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.95, blue: 0.91).ignoresSafeArea()
                if yearAssets.isEmpty {
                    ContentUnavailableView("这一年还没有照片", systemImage: "book.closed", description: Text("选择其他年份，继续浏览你的时光。"))
                } else {
                    VStack(spacing: 10) {
                        HStack {
                            Button { turnPage(-1) } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .background(.white.opacity(0.8), in: Circle())
                            }
                            .disabled(displayedMonth == 1 || isTurningPage)
                            Spacer()
                            VStack(spacing: 3) {
                                Text(String(format: "%02d / 12", displayedMonth))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .tracking(2)
                                Text("向左或向右滑动翻页")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { turnPage(1) } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .background(.white.opacity(0.8), in: Circle())
                            }
                            .disabled(displayedMonth == 12 || isTurningPage)
                        }
                        .buttonStyle(.plain)
                        monthPage(displayedMonth)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .rotation3DEffect(
                                .degrees(pageRotation),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: pageRotation < 0 ? .leading : .trailing,
                                perspective: 0.65
                            )
                            .shadow(color: .black.opacity(abs(pageRotation) / 700), radius: 12, x: 0, y: 5)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 25)
                                    .onEnded { value in
                                        let horizontal = abs(value.translation.width)
                                        let vertical = abs(value.translation.height)
                                        guard horizontal > vertical * 1.25 else { return }
                                        if value.translation.width < -45 { turnPage(1) }
                                        else if value.translation.width > 45 { turnPage(-1) }
                                    }
                            )
                        HStack(spacing: 5) {
                            ForEach(Array(1...12), id: \.self) { month in
                                Capsule()
                                    .fill(month == displayedMonth ? Color.primary : Color.primary.opacity(0.15))
                                    .frame(height: 3)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
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
        let items = library.assets(in: year, month: month)
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

    private func turnPage(_ direction: Int) {
        let nextMonth = displayedMonth + direction
        guard (1...12).contains(nextMonth), !isTurningPage else { return }
        isTurningPage = true
        withAnimation(.easeIn(duration: 0.16)) {
            pageRotation = direction > 0 ? -72 : 72
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            displayedMonth = nextMonth
            pageRotation = direction > 0 ? 72 : -72
            withAnimation(.easeOut(duration: 0.24)) {
                pageRotation = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isTurningPage = false
            }
        }
    }
}
