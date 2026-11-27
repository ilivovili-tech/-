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
                        monthNavigation
                        monthPage(displayedMonth)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            ForEach(1...12, id: \.self) { month in
                                Capsule()
                                    .fill(month == displayedMonth ? Color.primary : Color.primary.opacity(0.15))
                                    .frame(height: 3)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("\(year) 年 · 照片书")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let latestMonth = (1...12).reversed().first(where: { !library.assets(in: year, month: $0).isEmpty }) {
                    displayedMonth = latestMonth
                }
            }
            .fullScreenCover(isPresented: $showPhotoDetail) {
                if let selectedAsset {
                    PhotoDetailView(asset: selectedAsset)
                        .environmentObject(library)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var monthNavigation: some View {
        HStack {
            Button { turnPage(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.8), in: Circle())
            }
            .disabled(displayedMonth == 1 || isTurningPage)

            Spacer()
            Menu {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = month
                        }
                    } label: {
                        let count = library.assets(in: year, month: month).count
                        if month == displayedMonth {
                            Label("\(month) 月 · \(count) 张", systemImage: "checkmark")
                        } else {
                            Text("\(month) 月 · \(count) 张")
                        }
                    }
                }
            } label: {
                VStack(spacing: 3) {
                    HStack(spacing: 5) {
                        Text(String(format: "%02d / 12", displayedMonth))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    Text("选择月份 · 左右滑动翻页")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
    }

    private func monthPage(_ month: Int) -> some View {
        let items = library.assets(in: year, month: month)
        let calendar = Calendar.current
        let firstDate = calendar.date(from: DateComponents(year: year, month: month, day: 1))
        let dayCount = firstDate.flatMap { calendar.range(of: .day, in: .month, for: $0)?.count } ?? 0
        let leadingDays = firstDate.map {
            (calendar.component(.weekday, from: $0) - calendar.firstWeekday + 7) % 7
        } ?? 0
        let grouped = Dictionary(grouping: items.filter { $0.creationDate != nil }) {
            calendar.component(.day, from: $0.creationDate!)
        }
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = max(0, min(calendar.firstWeekday - 1, symbols.count - 1))
        let weekdays = Array(symbols[firstIndex..<symbols.count]) + Array(symbols[0..<firstIndex])

        return HStack(spacing: 0) {
            // Left leaf: monthly calendar and date index.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    Text(String(format: "%02d", month))
                        .font(.system(size: 43, weight: .light, design: .serif))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("\(month) 月 · \(items.count) 个瞬间")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundStyle(.secondary)
                    Rectangle().fill(Color.primary.opacity(0.14)).frame(height: 1)
                    Text("月历")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 5) {
                        ForEach(Array(weekdays.enumerated()), id: \.offset) { entry in
                            Text(entry.element)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        ForEach(0..<leadingDays, id: \.self) { _ in
                            Color.clear.frame(height: 38)
                        }
                        if dayCount > 0 {
                            ForEach(1...dayCount, id: \.self) { day in
                                calendarDay(day, assets: grouped[day] ?? [])
                            }
                        }
                    }
                    Text("\(year) · \(String(format: "%02d", month))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.90))

            // Book gutter: a subtle recessed spine and paper edge.
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.18), Color.black.opacity(0.035), Color.white.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 8)

            // Right leaf: photographic page.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("瞬间")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                        Spacer(minLength: 0)
                        Text("\(items.count)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Rectangle().fill(Color.primary.opacity(0.14)).frame(height: 1)
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "wind")
                                .font(.system(size: 25, weight: .ultraLight))
                            Text("这个月还没有照片")
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 35)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                            ForEach(items, id: \.localIdentifier) { asset in
                                Button {
                                    selectedAsset = asset
                                    showPhotoDetail = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        AssetThumbnail(asset: asset, contentMode: .fill)
                                            .frame(height: 112)
                                            .frame(maxWidth: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        Text(asset.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "日期未知")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.97))
            .rotation3DEffect(
                .degrees(pageRotation),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.38
            )
            .overlay(alignment: pageRotation < 0 ? .leading : .trailing) {
                LinearGradient(
                    colors: [.black.opacity(abs(pageRotation) / 700), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 24)
                .allowsHitTesting(false)
            }
        }
        .background(Color(red: 0.91, green: 0.88, blue: 0.81))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.55, green: 0.49, blue: 0.37).opacity(0.2), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.13), radius: 18, x: 0, y: 9)
        .accessibilityElement(children: .contain)
    }

    private func calendarDay(_ day: Int, assets: [PHAsset]) -> some View {
        Button {
            guard let asset = assets.first else { return }
            selectedAsset = asset
            showPhotoDetail = true
        } label: {
            VStack(spacing: 3) {
                if let cover = assets.first {
                    AssetThumbnail(asset: cover, contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                } else {
                    Text("\(day)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }

                Text("\(day)")
                    .font(.system(size: 9, weight: assets.isEmpty ? .regular : .semibold, design: .rounded))
                    .foregroundStyle(assets.isEmpty ? Color.secondary : Color.primary)

                if assets.count > 1 {
                    Text("+\(assets.count - 1)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear.frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(assets.isEmpty)
        .accessibilityLabel(assets.isEmpty ? "\(day) 日，无照片" : "\(day) 日，\(assets.count) 张照片")
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
