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
                tabBar
            }
        }
        .foregroundStyle(ink)
        .task { library.refresh() }
        .sheet(isPresented: $showYearbook) {
            YearbookView(year: selectedYear).environmentObject(library)
        }
        .sheet(isPresented: $showPhotoDetail) {
            if let activePhoto {
                PhotoDetailView(asset: activePhoto).environmentObject(library)
            }
        }
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView().environmentObject(library)
        }
        .sheet(isPresented: $showAlbumDetail) {
            if let selectedAlbum {
                AlbumDetailView(album: selectedAlbum).environmentObject(library)
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 10, weight: .semibold))
                    Text("私藏时光")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2)
                }
                .foregroundStyle(.secondary)
                Text(tab == .years ? "我的照片书" : tab.rawValue)
                    .font(.system(size: 29, weight: .bold, design: .serif))
                    .contentTransition(.opacity)
            }
            Spacer()
            if library.authorization == .authorized || library.authorization == .limited {
                HStack(spacing: 7) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 13, weight: .medium))
                    Text(library.photoCount.formatted())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(.white.opacity(0.78), in: Capsule())
                .overlay(Capsule().stroke(ink.opacity(0.06), lineWidth: 1))
                .accessibilityLabel("照片数量：\\(library.photoCount)")
            } else {
                Image(systemName: "photo.stack")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.7), in: Circle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var yearsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if library.authorization == .authorized || library.authorization == .limited {
                    yearBook
                    HStack(spacing: 10) {
                        statCard(title: "照片", value: "\(library.photoCount)", icon: "photo")
                        statCard(title: "视频", value: "\(library.videoCount)", icon: "video")
                    }
                    Text("最近的时光").font(.system(size: 21, weight: .bold, design: .serif))
                    photoGrid(Array(library.assets.prefix(18)))
                } else {
                    permissionCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var yearBook: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { selectedYear = max(1900, selectedYear - 1) }
                } label: { Image(systemName: "chevron.left") }
                .disabled(selectedYear <= 1900)
                Spacer()
                Menu {
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selectedYear = year
                            }
                        } label: {
                            if year == selectedYear {
                                Label("\(year) 年", systemImage: "checkmark")
                            } else {
                                Text("\(year) 年")
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 5) {
                            Text("\(selectedYear)")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text("YEARBOOK · 年度记忆")
                            .font(.system(size: 9, weight: .semibold)).tracking(2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(availableYears.isEmpty)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { selectedYear = min(Calendar.current.component(.year, from: Date()), selectedYear + 1) }
                } label: { Image(systemName: "chevron.right") }
                .disabled(selectedYear >= Calendar.current.component(.year, from: Date()))
            }
            .buttonStyle(.plain)
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.29, green: 0.37, blue: 0.31))
                    .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 9)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MY YEAR").font(.system(size: 10, weight: .bold)).tracking(3).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text("\(selectedYear)").font(.system(size: 43, weight: .regular, design: .serif)).foregroundStyle(.white)
                        Text("\(library.assets(in: selectedYear).count) 个珍贵瞬间")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                        Spacer()
                        Text("PHOTO COLLECTION  /  NO. 01").font(.system(size: 7, weight: .medium)).tracking(1.4).foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(20)
                    Spacer(minLength: 0)
                    ZStack {
                        if let cover = library.assets(in: selectedYear).first {
                            AssetThumbnail(asset: cover, contentMode: .fill)
                                .frame(width: 118, height: 190).clipped()
                                .rotation3DEffect(.degrees(-5), axis: (x: 0, y: 1, z: 0))
                        } else {
                            Image(systemName: "sun.max").font(.system(size: 52, weight: .ultraLight)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(9)
                }
            }
            .frame(height: 208)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .rotation3DEffect(.degrees(-2), axis: (x: 0, y: 1, z: 0))
            Button { showYearbook = true } label: {
                HStack(spacing: 8) {
                    Text("翻开 \(selectedYear) 年照片书")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 17).padding(.vertical, 11)
                .background(ink, in: Capsule())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
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
                                            if let asset = PHAsset.fetchAssets(in: album, options: nil).firstObject {
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
                                        Text("\(PHAsset.fetchAssets(in: album, options: nil).count) 张照片")
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
                    photoGrid(matches)
                }
                Text("每一张照片，都是时间寄来的明信片。")
                    .font(.system(size: 15, weight: .medium, design: .serif)).foregroundStyle(.secondary)
                    .padding(.vertical, 22)
            }.padding(20)
        }
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
        .padding(.top, 7)
        .background(.white.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle().fill(ink.opacity(0.07)).frame(height: 1)
        }
        .background { Color.white.opacity(0.94).ignoresSafeArea(edges: .bottom) }
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
