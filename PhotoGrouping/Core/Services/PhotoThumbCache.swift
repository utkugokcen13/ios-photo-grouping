//
//  PhotoThumbCache.swift
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
    private var activeRequests = Set<PHImageRequestID>()
    private var isSuspended = false
    private let lock = NSLock()

    private init() {
        cache.countLimit = 5000
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func suspend() {
        lock.lock()
        isSuspended = true
        let ids = activeRequests
        activeRequests.removeAll()
        lock.unlock()
        ids.forEach { manager.cancelImageRequest($0) }
        stopAllPreheating()
    }

    func resume() {
        lock.lock()
        isSuspended = false
        lock.unlock()
    }

    func image(for id: String,
               targetSize: CGSize,
               mode: PHImageContentMode = .aspectFill,
               completion: @escaping (UIImage?) -> Void) -> PHImageRequestID? {

        if let hit = cache.object(forKey: id as NSString) {
            completion(hit)
            return nil
        }

        lock.lock()
        let suspended = isSuspended
        lock.unlock()
        if suspended {
            completion(nil)
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
            guard let self else { return }
            if let d = info?[PHImageResultIsDegradedKey] as? Bool, d { return }
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled { return }

            if let img = img {
                self.cache.setObject(img, forKey: id as NSString, cost: img.pngData()?.count ?? 0)
            }

            if let req = info?[PHImageResultRequestIDKey] as? PHImageRequestID {
                self.lock.lock()
                self.activeRequests.remove(req)
                self.lock.unlock()
            }

            completion(img)
        }

        lock.lock()
        activeRequests.insert(rid)
        lock.unlock()
        return rid
    }

    func cancel(_ id: PHImageRequestID?) {
        guard let id else { return }
        manager.cancelImageRequest(id)
        lock.lock()
        activeRequests.remove(id)
        lock.unlock()
    }

    // PREHEAT
    func preheat(ids: [String], size: CGSize, mode: PHImageContentMode = .aspectFill) {
        guard !ids.isEmpty else { return }

        lock.lock()
        let suspended = isSuspended
        lock.unlock()
        if suspended { return }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in assets.append(a) }
        let opt = PHImageRequestOptions()
        opt.deliveryMode = .highQualityFormat
        opt.resizeMode = .fast
        opt.isNetworkAccessAllowed = true
        manager.startCachingImages(for: assets, targetSize: size, contentMode: mode, options: opt)
    }

    func stopAllPreheating() {
        manager.stopCachingImagesForAllAssets()
    }
}

