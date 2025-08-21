//
//  PhotoThumbnailCache.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 22.08.2025.
//

import UIKit
import Photos

final class PhotoThumbCache {
    static let shared = PhotoThumbCache()

    let manager = PHCachingImageManager()
    private let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 5000
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for id: String,
               targetSize: CGSize,
               mode: PHImageContentMode = .aspectFill,
               completion: @escaping (UIImage?) -> Void) -> PHImageRequestID? {

        if let hit = cache.object(forKey: id as NSString) {
            completion(hit)
            return nil
        }

        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            completion(nil); return nil
        }

        let opt = PHImageRequestOptions()
        opt.deliveryMode = .highQualityFormat
        opt.resizeMode = .fast
        opt.isSynchronous = false
        opt.isNetworkAccessAllowed = true

        let rid = manager.requestImage(for: asset,
                                       targetSize: targetSize,
                                       contentMode: mode,
                                       options: opt) { [weak self] img, info in
            // düşük kalite/degraded gönderimleri tamamen yok say
            if let d = info?[PHImageResultIsDegradedKey] as? Bool, d { return }
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled { return }
            if let img = img {
                self?.cache.setObject(img, forKey: id as NSString, cost: img.pngData()?.count ?? 0)
            }
            completion(img)
        }
        return rid
    }

    func cancel(_ id: PHImageRequestID?) {
        guard let id else { return }
        manager.cancelImageRequest(id)
    }

    func preheat(ids: [String], size: CGSize, mode: PHImageContentMode = .aspectFill) {
        guard !ids.isEmpty else { return }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in assets.append(a) }
        let opt = PHImageRequestOptions()
        opt.deliveryMode = .highQualityFormat
        opt.resizeMode = .fast
        opt.isNetworkAccessAllowed = true
        manager.startCachingImages(for: assets, targetSize: size, contentMode: mode, options: opt)
    }
}

