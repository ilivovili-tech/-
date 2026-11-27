import SwiftUI
import Photos
import UIKit

@MainActor
final class PhotoLibraryStore: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var albums: [PHAssetCollection] = []
    @Published private(set) var photoCount = 0
    @Published private(set) var videoCount = 0
    private var assetsByYear: [Int: [PHAsset]] = [:]
    private var assetsByYearAndMonth: [Int: [Int: [PHAsset]]] = [:]
    private var albumFetchResults: [String: PHFetchResult<PHAsset>] = [:]
    @Published var selectedAsset: PHAsset?
    private let manager = PHCachingImageManager()

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorization = status
        if status == .authorized || status == .limited {
            loadLibrary()
        } else {
            clearLibrary()
        }
    }

    func refresh() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorization == .authorized || authorization == .limited {
            loadLibrary()
        } else {
            clearLibrary()
        }
    }

    private func clearLibrary() {
        assets = []
        albums = []
        photoCount = 0
        videoCount = 0
        assetsByYear = [:]
        assetsByYearAndMonth = [:]
        albumFetchResults = [:]
    }

    private func loadLibrary() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var items: [PHAsset] = []
        var photos = 0
        var videos = 0
        var byYear: [Int: [PHAsset]] = [:]
        var byYearMonth: [Int: [Int: [PHAsset]]] = [:]
        let calendar = Calendar.current
        result.enumerateObjects { asset, _, _ in
            items.append(asset)
            if asset.mediaType == .image { photos += 1 }
            else if asset.mediaType == .video { videos += 1 }
            if let date = asset.creationDate {
                let components = calendar.dateComponents([.year, .month], from: date)
                if let year = components.year {
                    byYear[year, default: []].append(asset)
                    if let month = components.month {
                        byYearMonth[year, default: [:]][month, default: []].append(asset)
                    }
                }
            }
        }
        assets = items
        photoCount = photos
        videoCount = videos
        assetsByYear = byYear
        assetsByYearAndMonth = byYearMonth

        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: [PHAssetCollection] = []
        var fetchResults: [String: PHFetchResult<PHAsset>] = [:]
        collections.enumerateObjects { collection, _, _ in
            found.append(collection)
            let albumOptions = PHFetchOptions()
            albumOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResults[collection.localIdentifier] = PHAsset.fetchAssets(in: collection, options: albumOptions)
        }
        albums = found
        albumFetchResults = fetchResults
    }

    func image(for asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
    }

    func assets(in year: Int) -> [PHAsset] {
        assetsByYear[year] ?? []
    }

    func assets(in year: Int, month: Int) -> [PHAsset] {
        assetsByYearAndMonth[year]?[month] ?? []
    }

    func assets(in album: PHAssetCollection) -> [PHAsset] {
        guard let result = albumFetchResults[album.localIdentifier] else { return [] }
        var items: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in items.append(asset) }
        return items
    }

    func assetCount(in album: PHAssetCollection) -> Int {
        albumFetchResults[album.localIdentifier]?.count ?? 0
    }

    func coverAsset(in album: PHAssetCollection) -> PHAsset? {
        albumFetchResults[album.localIdentifier]?.firstObject
    }

    func createAlbum(named title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: trimmed)
        }
        refresh()
    }

    func add(_ asset: PHAsset, to album: PHAssetCollection) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            guard let request = PHAssetCollectionChangeRequest(for: album) else { return }
            request.addAssets([asset] as NSArray)
        }
        refresh()
    }

    func delete(_ asset: PHAsset) async throws {
        try await delete([asset])
    }

    func delete(_ selectedAssets: [PHAsset]) async throws {
        guard !selectedAssets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(selectedAssets as NSArray)
        }
        refresh()
    }
}
