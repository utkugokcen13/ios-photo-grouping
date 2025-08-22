//
//  ScanningService.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import Foundation
import Photos

struct Snapshot {
    let addedByGroup: [PhotoGroup: [String]]
    let addedOthers: [String]
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
    private var accumulator = AssetAccumulator()
    private var collector = BatchCollector()
    private let journal = SeenJournal.shared

    private var isCancelled = false
    private var lastEmit = Date(timeIntervalSince1970: 0)
    private let emitInterval: TimeInterval = 0.25
    private let emitBatch = 50
    private var initialSeen = Set<String>()
    private var bootstrapped = false

    // NEW: call this once with persisted store state
    func bootstrap(groups: [PhotoGroup: [String]],
                   others: [String],
                   total: Int,
                   processed: Int) {
        Task { await accumulator.bootstrap(groups: groups, others: others, processed: processed)
               await accumulator.setTotal(total)
        }
        bootstrapped = true
    }

    func startScan(initialSeen: Set<String> = []) {
        // Merge with journal
        let journalSeen = self.journal.loadAll()
        let merged = initialSeen.union(journalSeen)
        self.initialSeen = merged
        isCancelled = false

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
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

    // Cancel & reset state so a fresh scan can begin
    func cancelAndReset(completion: (() -> Void)? = nil) {
        isCancelled = true
        throttleQueue.sync {
            Task {
                await self.accumulator.reset()
                await self.collector.reset()
                self.lastEmit = Date(timeIntervalSince1970: 0)
                self.initialSeen = []
                self.journal.clear()
                DispatchQueue.main.async { completion?() }
            }
        }
    }

    // Flush pending batch to delegate so the store persists exact progress
    func requestCheckpoint(completion: @escaping (Snapshot?) -> Void) {
        throttleQueue.sync {
            Task {
                let counts = await self.accumulator.snapshotCounts()
                let deltas = await self.collector.drain()
                // Build a snapshot only if there is something new; still include counts for accuracy
                let snap = (deltas.byGroup.isEmpty && deltas.others.isEmpty)
                    ? nil
                    : Snapshot(addedByGroup: deltas.byGroup,
                               addedOthers: deltas.others,
                               processed: counts.processed,
                               total: counts.total)
                // Also still notify delegate if we built a snapshot (optional, UI can reflect last bits)
                if let snap = snap {
                    DispatchQueue.main.async {
                        self.delegate?.scanningService(self, didUpdate: snap)
                    }
                }
                DispatchQueue.main.async { completion(snap) }
            }
            // Flush journal on checkpoint
            self.journal.flushSync()
        }
    }

    private func scanAssets() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetch = PHAsset.fetchAssets(with: options)

        Task {
            await accumulator.setTotal(fetch.count)
            // If caller didn't bootstrap (older code path), at least seed counts
            if !bootstrapped {
                await accumulator.seedProcessed(initialSeen.count)
            }
        }

        // Process all assets with bounded concurrency
        let group = DispatchGroup()
        let initialProcessed = initialSeen.count
        var processedAtLastEmit = initialProcessed

        if !initialSeen.isEmpty {

            var alreadySeenAssets: [PHAsset] = []
            fetch.enumerateObjects { asset, index, stop in
                if self.initialSeen.contains(asset.localIdentifier) {
                    alreadySeenAssets.append(asset)
                }
            }

            let fastGroup = DispatchGroup()
            for asset in alreadySeenAssets {
                fastGroup.enter()
                workQueue.async { [weak self] in
                    defer { fastGroup.leave() }
                    guard let self = self, !self.isCancelled else { return }
                    autoreleasepool {
                        let value = asset.reliableHash()
                        let g = PhotoGroup.group(for: value)
                        Task {
                            await self.accumulator.insertExisting(asset.localIdentifier, into: g)
                            await self.collector.add(id: asset.localIdentifier, to: g)
                        }
                    }
                }
            }
            
            fastGroup.wait()
        }

        for i in 0..<fetch.count {
            if isCancelled { break }
            let asset = fetch.object(at: i)
            let id = asset.localIdentifier

            // Skip already processed IDs
            if initialSeen.contains(id) { continue }

            gate.wait()
            group.enter()
            workQueue.async { [weak self] in
                defer { self?.gate.signal(); group.leave() }
                guard let self = self, !self.isCancelled else { return }

                autoreleasepool {
                    let value = asset.reliableHash()
                    let g = PhotoGroup.group(for: value)

                    Task {
                        if await self.isCancelled { return }
                        let inserted = await self.accumulator.insert(id, into: g)
                        if inserted { 
                            await self.collector.add(id: id, to: g)
                            // also journal
                            self.journal.append([id])
                        }
                    }

                    // Throttle UI snapshot
                    self.throttleQueue.sync {
                        Task {
                            let snapCounts = await self.accumulator.snapshotCounts() // for processed/total only
                            // Only emit if enough items processed or time window passed
                            if (snapCounts.processed - processedAtLastEmit) >= self.emitBatch
                                || Date().timeIntervalSince(self.lastEmit) >= self.emitInterval {

                                processedAtLastEmit = snapCounts.processed
                                self.lastEmit = Date()

                                let deltas = await self.collector.drain()
                                guard !(deltas.byGroup.isEmpty && deltas.others.isEmpty) else { return }
                                if await self.isCancelled { return }

                                DispatchQueue.main.async {
                                    self.delegate?.scanningService(
                                        self,
                                        didUpdate: Snapshot(
                                            addedByGroup: deltas.byGroup,
                                            addedOthers: deltas.others,
                                            processed: snapCounts.processed,
                                            total: snapCounts.total
                                        )
                                    )
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
                let snapCounts = await self.accumulator.snapshotCounts()
                let deltas = await self.collector.drain()
                if !self.isCancelled, !(deltas.byGroup.isEmpty && deltas.others.isEmpty) {
                    DispatchQueue.main.async {
                        self.delegate?.scanningService(
                            self,
                            didUpdate: Snapshot(
                                addedByGroup: deltas.byGroup,
                                addedOthers: deltas.others,
                                processed: snapCounts.processed,
                                total: snapCounts.total
                            )
                        )
                    }
                }
                let materialized = await self.accumulator.materialize()
                if !self.isCancelled {
                    DispatchQueue.main.async {
                        self.delegate?.scanningServiceDidComplete(self,
                            groups: materialized.groups,
                            others: materialized.others)
                    }
                }
                self.journal.clear()
            }
        }
    }
}
