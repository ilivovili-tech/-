import SwiftUI
import Photos
import UIKit

@MainActor
final class PhotoLibraryStore: ObservableObject {
    @Published private(set) var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var albums: [PHAssetCollection] = []
    @Published var selectedAsset: PHAsset?
    private let manager = PHCachingImageManager()

    var photoCount: Int { assets.filter { $0.mediaType == .image }.count }
    var videoCount: Int { assets.filter { $0.mediaType == .video }.count }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorization = status
        if status == .authorized || status == .limited { loadLibrary() }
    }

    func refresh() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorization == .authorized || authorization == .limited { loadLibrary() }
    }

    private func loadLibrary() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var items: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in items.append(asset) }
        assets = items

        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: [PHAssetCollection] = []
        collections.enumerateObjects { collection, _, _ in found.append(collection) }
        albums = found
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
        assets.filter {
            guard let date = $0.creationDate else { return false }
            return Calendar.current.component(.year, from: date) == year
        }
    }

    func assets(in album: PHAssetCollection) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(in: album, options: options)
        var items: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in items.append(asset) }
        return items
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
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }
        refresh()
    }
}
