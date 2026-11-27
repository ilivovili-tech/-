import SwiftUI
import Photos

private enum AlbumTab: String, CaseIterable {
    case years = "时光"
    case albums = "相册"
    case memories = "回忆"
    case organize = "整理"

    var symbol: String {
        switch self {
        case .years: return "book.closed.fill"
        case .albums: return "square.stack.fill"
        case .memories: return "sparkles"
        case .organize: return "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var tab: AlbumTab = .years
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showDeleteConfirmation = false
    @State private var pendingDelete: PHAsset?
    @State private var errorMessage: String?
    @State private var showYearbook = false
    @State private var showPhotoDetail = false
    @State private var activePhoto: PHAsset?
    @State private var pendingAlbumPhoto: PHAsset?
    @State private var showCreateAlbum = false
    @State private var showAlbumDetail = false
    @State private var selectedAlbum: PHAssetCollection?

    private let ink = Color(red: 0.16, green: 0.19, blue: 0.17)
    private let paper = Color(red: 0.96, green: 0.95, blue: 0.91)

    private var availableYears: [Int] {
        let years = library.assets.compactMap { asset -> Int? in
            guard let date = asset.creationDate else { return nil }
            return Calendar.current.component(.year, from: date)
        }
        return Array(Set(years)).sorted(by: >)
    }

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch tab {
                    case .years: yearsPage
                    case .albums: albumsPage
                    case .memories: memoriesPage
                    case .organize: organizePage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if tab != .years { tabBar }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ink)
        .task { library.refresh() }
        .fullScreenCover(isPresented: $showYearbook) {
            YearbookView(year: selectedYear)
                .environmentObject(library)
        }
        .fullScreenCover(isPresented: $showPhotoDetail) {
            if let activePhoto {
                PhotoDetailView(asset: activePhoto)
                    .environmentObject(library)
            }
        }
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView().environmentObject(library)
        }
        .sheet(isPresented: $showAlbumDetail, onDismiss: {
            // Wait until the album sheet has fully dismissed before presenting
            // the photo viewer from the root view. This avoids nested modal
            // presentations, which caused the blank photo screen on device.
            if let photo = pendingAlbumPhoto {
                pendingAlbumPhoto = nil
                activePhoto = photo
                DispatchQueue.main.async {
                    showPhotoDetail = true
                }
            }
        }) {
            if let selectedAlbum {
                AlbumDetailView(album: selectedAlbum) { asset in
                    pendingAlbumPhoto = asset
                    showAlbumDetail = false
                }
                .environmentObject(library)
            }
        }
        .alert("删除这张照片？", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("移至最近删除", role: .destructive) {
                guard let asset = pendingDelete else { return }
                Task {
                    do { try await library.delete(asset) }
                    catch { errorMessage = error.localizedDescription }
                    pendingDelete = nil
                }
            }
        } message: {
            Text("照片将交由系统照片图库管理，你可以在系统“最近删除”中恢复。")
        }
        .alert("操作未完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var header: some View {
        HStack {
            if tab != .years {
                VStack(alignment: .leading, spacing: 3) {
                    Text("私藏时光")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text(tab.rawValue)
                        .font(.system(size: 25, weight: .bold, design: .serif))
                }
            }
            Spacer()
            Menu {
                Button { tab = .albums } label: { Label("相册", systemImage: "square.stack") }
                Button { tab = .memories } label: { Label("回忆", systemImage: "sparkles") }
                Button { tab = .organize } label: { Label("整理照片", systemImage: "slider.horizontal.3") }
            } label: {
                Image(systemName: "person")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ink)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.76), in: Circle())
                    .overlay(Circle().stroke(ink.opacity(0.12), lineWidth: 0.8))
            }
            .accessibilityLabel("个人与功能菜单")
        }
        .padding(.horizontal, 22)
        .padding(.top, tab == .years ? 10 : 14)
        .padding(.bottom, tab == .years ? 2 : 12)
    }

    private var yearsPage: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Color.white.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.96, blue: 0.94),
                        .white,
                        Color(red: 0.99, green: 0.96, blue: 0.97),
                        .white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if library.authorization == .authorized || library.authorization == .limited {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if availableYears.isEmpty {
                                emptyState("还没有照片", subtitle: "允许访问照片图库后，你的年度照片书会出现在这里。", icon: "photo.on.rectangle")
                                    .padding(.top, 80)
                            } else {
                                ForEach(availableYears, id: \.self) { year in
                                    yearShelfRow(year: year, width: proxy.size.width)
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 110)
                    }
                    .modifier(AlbumScrollEdgeEffect())
                } else {
                    permissionCard.padding(.horizontal, 20).padding(.top, 50)
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        tab = .organize
                    }
                } label: {
                    Label("清理", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1))
                        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 22)
                .accessibilityLabel("打开照片清理")
            }
        }
    }

    private func yearShelfRow(year: Int, width: CGFloat) -> some View {
        let assets = library.assets(in: year)
        let isCurrent = year == selectedYear
        let palette: [Color] = [
            Color(red: 0.96, green: 0.75, blue: 0.12),
            Color(red: 0.91, green: 0.22, blue: 0.20),
            Color(red: 0.20, green: 0.68, blue: 0.40),
            Color(red: 0.37, green: 0.54, blue: 0.83),
            Color(red: 0.65, green: 0.48, blue: 0.72)
        ]
        let accent = palette[abs(year) % palette.count]

        return HStack(spacing: 9) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    selectedYear = year
                }
                showYearbook = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    if isCurrent {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.bottom, 4)
                    }
                    Text(String(year))
                        .font(.system(size: isCurrent ? 27 : 22, weight: .bold, design: .serif))
                        .monospacedDigit()
                    if isCurrent {
                        Text("打开照片书")
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(ink.opacity(isCurrent ? 1 : 0.36))
                .frame(width: 88, alignment: .leading)
                .blur(radius: isCurrent ? 0 : 0.45)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                selectedYear = year
                showYearbook = true
            } label: {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(.white)
                        .frame(width: min(width * 0.62, 245), height: 270)
                        .offset(x: 17, y: 8)
                        .shadow(color: .black.opacity(0.12), radius: 15, x: 5, y: 8)
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(accent)
                        .frame(width: min(width * 0.60, 237), height: 266)
                        .offset(x: 8, y: 4)
                    ZStack(alignment: .topLeading) {
                        if let cover = assets.first {
                            AssetThumbnail(asset: cover, contentMode: .fill)
                                .frame(width: min(width * 0.58, 229), height: 262)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(red: 0.91, green: 0.91, blue: 0.89))
                                .frame(width: min(width * 0.58, 229), height: 262)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 42, weight: .ultraLight))
                                        .foregroundStyle(.white)
                                }
                        }
                        LinearGradient(
                            colors: [.black.opacity(0.35), .clear, .black.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: min(width * 0.58, 229), height: 262)
                        Text(String(year))
                            .font(.system(size: 43, weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .padding(17)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.55), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.16), radius: 17, x: 0, y: 11)
                }
                .frame(width: min(width * 0.66, 260), height: 286)
                .rotation3DEffect(.degrees(-7), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.7)
                .rotationEffect(.degrees(-3))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottomLeading) {
                Text("\(assets.count) 张照片")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .offset(x: 5, y: 14)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 318)
        .padding(.leading, 2)
    }

    private var permissionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 42, weight: .light))
                .foregroundStyle(Color(red: 0.36, green: 0.48, blue: 0.39))
            Text("让回忆住进照片书").font(.system(size: 22, weight: .bold, design: .serif))
            Text("允许访问照片图库后，即可按年份浏览照片、制作年度封面并整理相册。照片只在你的设备上读取。")
                .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { Task { await library.requestAccess() } } label: {
                Text("开启照片访问").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(ink, in: Capsule())
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .padding(.top, 28)
    }

    private var albumsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("我的收藏").font(.system(size: 22, weight: .bold, design: .serif))
                        Text("创建属于自己的主题相簿").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showCreateAlbum = true } label: {
                        Label("新建", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 13).padding(.vertical, 9)
                            .background(ink, in: Capsule()).foregroundStyle(.white)
                    }
                }
                if library.authorization == .authorized || library.authorization == .limited {
                    if library.albums.isEmpty {
                        emptyState("还没有自定义相簿", subtitle: "点击右上角“新建”，创建你的第一个主题相簿。", icon: "square.stack")
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(library.albums, id: \.localIdentifier) { album in
                                Button {
                                    selectedAlbum = album
                                    showAlbumDetail = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16).fill(.white)
                                            if let asset = library.coverAsset(in: album) {
                                                AssetThumbnail(asset: asset, contentMode: .fill)
                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                            } else {
                                                Image(systemName: "photo.stack").font(.largeTitle).foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(height: 140)
                                        .overlay(alignment: .bottomTrailing) {
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(8)
                                                .background(.black.opacity(0.35), in: Circle())
                                                .padding(8)
                                        }
                                        Text(album.localizedTitle ?? "未命名相簿")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(ink)
                                        Text("\(library.assetCount(in: album)) 张照片")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else { permissionCard }
            }.padding(20)
        }
        .modifier(AlbumScrollEdgeEffect())
    }

    private var memoriesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("把今天，交给回忆").font(.system(size: 23, weight: .bold, design: .serif))
                Text("ON THIS DAY").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                let matches = library.assets.filter {
                    guard let date = $0.creationDate else { return false }
                    return Calendar.current.component(.month, from: date) == Calendar.current.component(.month, from: Date())
                        && Calendar.current.component(.day, from: date) == Calendar.current.component(.day, from: Date())
                        && Calendar.current.component(.year, from: date) != Calendar.current.component(.year, from: Date())
                }
                if matches.isEmpty {
                    emptyState("今天还没有往年记忆", subtitle: "当你积累更多照片，这里会出现同一天的珍贵瞬间。", icon: "sparkles")
                } else {
                    let memoriesByYear = Dictionary(grouping: matches) { asset in
                        Calendar.current.component(.year, from: asset.creationDate ?? Date.distantPast)
                    }
                    ForEach(memoriesByYear.keys.sorted(by: >), id: \.self) { year in
                        let yearAssets = memoriesByYear[year] ?? []
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(year) 年的今天")
                                    .font(.system(size: 17, weight: .semibold, design: .serif))
                                Spacer()
                                Text("\(yearAssets.count) 张回忆")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            photoGrid(yearAssets)
                        }
                        .padding(14)
                        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                Text("每一张照片，都是时间寄来的明信片。")
                    .font(.system(size: 15, weight: .medium, design: .serif)).foregroundStyle(.secondary)
                    .padding(.vertical, 22)
            }.padding(20)
        }
        .modifier(AlbumScrollEdgeEffect())
    }

    private var organizePage: some View {
        OrganizerView().environmentObject(library)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AlbumTab.allCases, id: \.self) { item in
                tabButton(item)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            if #available(iOS 26.0, *) {
                Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.24), lineWidth: 0.7)
        }
        .padding(.horizontal, 20)
        .padding(.top, 5)
        .padding(.bottom, 4)
    }

    private func tabButton(_ item: AlbumTab) -> some View {
        let isSelected = tab == item
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                tab = item
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.symbol)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: isSelected)
                Text(item.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? ink : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 9)
            .padding(.bottom, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(paper)
                        .padding(.horizontal, 5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold, design: .serif))
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(15).frame(maxWidth: .infinity).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
    }

    private func photoGrid(_ assets: [PHAsset]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
            ForEach(assets, id: \.localIdentifier) { asset in
                ZStack(alignment: .topTrailing) {
                    Button {
                        activePhoto = asset
                        showPhotoDetail = true
                    } label: {
                        AssetThumbnail(asset: asset, contentMode: .fill)
                            .aspectRatio(1, contentMode: .fill).clipped()
                    }
                    .buttonStyle(.plain)
                    if asset.mediaType == .video {
                        Image(systemName: "play.fill").font(.system(size: 10)).foregroundStyle(.white).padding(7)
                    }
                    Button {
                        pendingDelete = asset
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white).padding(8).background(.black.opacity(0.35), in: Circle())
                    }.padding(5)
                }.clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private func emptyState(_ title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 35, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 17, weight: .semibold, design: .serif))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(32).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct AlbumScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        } else {
            content
        }
    }
}
