import SwiftUI
import Photos

private enum OrganizerFilter: String, CaseIterable {
    case nearby = "时间相近"
    case videos = "视频"
    case bursts = "连拍"
}

private enum OrganizerSort: String, CaseIterable {
    case newest = "最新拍摄"
    case oldest = "最早拍摄"
}

struct OrganizerView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var filter: OrganizerFilter = .nearby
    @State private var sort: OrganizerSort = .newest
    @State private var selectedIDs: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var activeAsset: PHAsset?
    @State private var showDetail = false
    @State private var errorMessage: String?

    private var visibleAssets: [PHAsset] {
        switch filter {
        case .videos:
            return library.assets.filter { $0.mediaType == .video }
        case .bursts:
            return library.assets.filter { $0.burstIdentifier != nil }
        case .nearby:
            let dated = library.assets.enumerated().compactMap { index, asset -> PHAsset? in
                guard let date = asset.creationDate else { return nil }
                let before = index > 0 ? library.assets[index - 1].creationDate : nil
                let after = index + 1 < library.assets.count ? library.assets[index + 1].creationDate : nil
                let closeBefore = before.map { abs(date.timeIntervalSince($0)) <= 120 } ?? false
                let closeAfter = after.map { abs(date.timeIntervalSince($0)) <= 120 } ?? false
                return closeBefore || closeAfter ? asset : nil
            }
            return dated
        }
    }

    private var sortedAssets: [PHAsset] {
        visibleAssets.sorted { lhs, rhs in
            let leftDate = lhs.creationDate ?? .distantPast
            let rightDate = rhs.creationDate ?? .distantPast
            switch sort {
            case .newest:
                return leftDate == rightDate
                    ? lhs.localIdentifier < rhs.localIdentifier
                    : leftDate > rightDate
            case .oldest:
                return leftDate == rightDate
                    ? lhs.localIdentifier < rhs.localIdentifier
                    : leftDate < rightDate
            }
        }
    }

    private var selectedAssets: [PHAsset] {
        sortedAssets.filter { selectedIDs.contains($0.localIdentifier) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("整理你的图库").font(.system(size: 23, weight: .bold, design: .serif))
                Text("右滑或长按照片加入待删除列表；确认前不会删除任何内容。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Picker("分类", selection: $filter) {
                    ForEach(OrganizerFilter.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: filter) { _, _ in selectedIDs.removeAll() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(visibleAssets.count) 个项目")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    if !selectedIDs.isEmpty {
                        Text("已暂存 \(selectedIDs.count) 个待删除项目")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                Menu {
                    Picker("排序方式", selection: $sort) {
                        ForEach(OrganizerSort.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                } label: {
                    Label("排序", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                }
                if !selectedIDs.isEmpty {
                    Button("取消选择") { selectedIDs.removeAll() }
                        .font(.system(size: 12))
                }
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label("删除所选（\(selectedIDs.count)）", systemImage: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selectedIDs.isEmpty ? Color.gray.opacity(0.35) : Color.red, in: Capsule())
                }
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            if visibleAssets.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySymbol,
                    description: Text(emptyDescription)
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(sortedAssets, id: \.localIdentifier) { asset in
                            Button {
                                if selectedIDs.isEmpty {
                                    activeAsset = asset
                                    showDetail = true
                                } else {
                                    toggle(asset)
                                }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    AssetThumbnail(asset: asset, contentMode: .fill)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                    if asset.mediaType == .video {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(7)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                    }
                                    Image(systemName: selectedIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 21, weight: .medium))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, selectedIDs.contains(asset.localIdentifier) ? .green : .black.opacity(0.3))
                                        .padding(6)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedIDs.contains(asset.localIdentifier) ? Color.green : .clear, lineWidth: 3)
                                }
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 28)
                                    .onEnded { value in
                                        let horizontal = value.translation.width
                                        let vertical = value.translation.height
                                        guard horizontal > 55, abs(horizontal) > abs(vertical) else { return }
                                        if !selectedIDs.contains(asset.localIdentifier) {
                                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                                toggle(asset)
                                            }
                                        }
                                    }
                            )
                            .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in toggle(asset) })
                            .accessibilityLabel(selectedIDs.contains(asset.localIdentifier) ? "已加入待删除列表" : "照片，右滑或长按可加入待删除列表")
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 20)
                }
            }
        }
        .onChange(of: library.assets.map(\.localIdentifier)) { _, identifiers in
            selectedIDs.formIntersection(Set(identifiers))
        }
        .sheet(isPresented: $showDetail) {
            if let activeAsset {
                PhotoDetailView(asset: activeAsset).environmentObject(library)
            }
        }
        .confirmationDialog("删除选中的 \(selectedIDs.count) 个项目？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("移至最近删除", role: .destructive) {
                let assets = selectedAssets
                Task {
                    do {
                        try await library.delete(assets)
                        selectedIDs.removeAll()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("项目将交由 iOS 照片图库管理，可在系统“最近删除”中恢复。")
        }
        .alert("删除失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .nearby: return "没有发现时间相近的照片"
        case .videos: return "还没有视频"
        case .bursts: return "没有连拍照片"
        }
    }

    private var emptySymbol: String {
        switch filter {
        case .nearby: return "clock"
        case .videos: return "video"
        case .bursts: return "square.stack.3d.up"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .nearby: return "拍摄时间相近的照片会出现在这里，方便你一起检查。"
        case .videos: return "图库中的视频会集中显示在这里。"
        case .bursts: return "系统识别到的连拍照片会显示在这里。"
        }
    }

    private func toggle(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }
}
