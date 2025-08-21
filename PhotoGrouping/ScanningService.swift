//
//  ScanningService.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import Foundation
import Photos

struct Snapshot {
    let counts: [PhotoGroup: Int]
    let othersCount: Int
    let processed: Int
    let total: Int
}

protocol ScanningServiceDelegate: AnyObject {
    func scanningService(_ service: ScanningService, didUpdate snapshot: Snapshot)
    func scanningServiceDidComplete(_ service: ScanningService,
                                    groups: [PhotoGroup: [String]],
                                    others: [String])
    func scanningService(_ service: ScanningService, didFailWithError error: Error)
}

final class ScanningService {
    weak var delegate: ScanningServiceDelegate?

    private let workQueue = DispatchQueue(label: "scan.queue", qos: .userInitiated, attributes: .concurrent)
    private let throttleQueue = DispatchQueue(label: "scan.throttle") // serial for emit gating
    private let gate = DispatchSemaphore(value: 4) // bounded concurrency
    private let accumulator = AssetAccumulator()

    private var isCancelled = false
    private var lastEmit = Date(timeIntervalSince1970: 0)
    private let emitInterval: TimeInterval = 0.1
    private let emitBatch = 20

    func startScan() {
        isCancelled = false

        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.delegate?.scanningService(self, didFailWithError:
                        NSError(domain: "PhotoGrouping", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                }
                return
            }
            self.scanAssets()
        }
    }

    func stopScan() { isCancelled = true }

    private func scanAssets() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetch = PHAsset.fetchAssets(with: options)
        Task { await accumulator.setTotal(fetch.count) }

        // Process all assets with bounded concurrency
        let group = DispatchGroup()
        var processedAtLastEmit = 0

        for i in 0..<fetch.count {
            if isCancelled { break }
            let asset = fetch.object(at: i)
            gate.wait()
            group.enter()
            workQueue.async { [weak self] in
                defer { self?.gate.signal(); group.leave() }
                guard let self = self else { return }

                autoreleasepool {
                    let value = asset.reliableHash()
                    let g = PhotoGroup.group(for: value)
                    let id = asset.localIdentifier
                    
                    // Update accumulator
                    Task {
                        _ = await self.accumulator.insert(id, into: g)
                    }

                    // Throttle UI snapshot
                    self.throttleQueue.sync {
                        Task {
                            let snap = await self.accumulator.snapshotCounts()
                            // Only emit if enough items processed or time window passed
                            if (snap.processed - processedAtLastEmit) >= self.emitBatch
                                || Date().timeIntervalSince(self.lastEmit) >= self.emitInterval {
                                processedAtLastEmit = snap.processed
                                self.lastEmit = Date()
                                
                                // Use async to prevent blocking
                                DispatchQueue.main.async {
                                    self.delegate?.scanningService(self,
                                        didUpdate: Snapshot(counts: snap.counts,
                                                          othersCount: snap.others,
                                                          processed: snap.processed,
                                                          total: snap.total))
                                }
                            }
                        }
                    }
                }
            }
        }

        group.notify(queue: workQueue) { [weak self] in
            guard let self = self else { return }
            Task {
                let snap = await self.accumulator.snapshotCounts()
                // Final emit
                DispatchQueue.main.async {
                    self.delegate?.scanningService(self,
                        didUpdate: Snapshot(counts: snap.counts,
                                         othersCount: snap.others,
                                         processed: snap.processed,
                                         total: snap.total))
                }
                let materialized = await self.accumulator.materialize()
                DispatchQueue.main.async {
                    self.delegate?.scanningServiceDidComplete(self,
                        groups: materialized.groups,
                        others: materialized.others)
                }
            }
        }
    }
}
