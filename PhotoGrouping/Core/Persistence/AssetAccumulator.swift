//
//  AssetAccumulator.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import Foundation

actor AssetAccumulator {
    private var groups: [PhotoGroup: Set<String>] = [:]
    private var others: Set<String> = []
    private(set) var processed: Int = 0
    private(set) var total: Int = 0
    private var order: [String: Int] = [:]
    private var nextOrder: Int = 0

    func setTotal(_ n: Int) { total = n }

    // preload persisted groups/others exactly as saved
    func bootstrap(groups persisted: [PhotoGroup: [String]],
                   others persistedOthers: [String],
                   processed seenCount: Int) {
        groups = persisted.mapValues { Set($0) }
        others = Set(persistedOthers)
        processed = seenCount
        order.removeAll(keepingCapacity: true)
        nextOrder = 0
        // preserve persisted array order
        for (_, arr) in persisted {
            for id in arr { order[id] = nextOrder; nextOrder &+= 1 }
        }
        for id in persistedOthers {
            order[id] = nextOrder; nextOrder &+= 1
        }
    }

    // Keep old seedProcessed for callers that only know counts
    func seedProcessed(_ count: Int) {
        processed = count
        nextOrder = max(nextOrder, count)
    }

    // insert already-seen ID into its group WITHOUT incrementing processed
    func insertExisting(_ assetID: String, into group: PhotoGroup?) {
        if let g = group {
            if groups[g] == nil { groups[g] = [] }
            let inserted = groups[g]!.insert(assetID).inserted
            if inserted { order[assetID] = nextOrder; nextOrder &+= 1 }
        } else {
            let inserted = others.insert(assetID).inserted
            if inserted { order[assetID] = nextOrder; nextOrder &+= 1 }
        }
    }

    @discardableResult
    func insert(_ assetID: String, into group: PhotoGroup?) -> Bool {
        processed &+= 1
        var inserted = false
        if let g = group {
            if groups[g] == nil { groups[g] = [] }
            inserted = groups[g]!.insert(assetID).inserted
        } else {
            inserted = others.insert(assetID).inserted
        }
        if inserted {
            order[assetID] = nextOrder
            nextOrder &+= 1
        }
        return inserted
    }

    func snapshotCounts() -> (counts: [PhotoGroup: Int], others: Int, processed: Int, total: Int) {
        (groups.mapValues { $0.count }, others.count, processed, total)
    }

    func materialize() -> (groups: [PhotoGroup: [String]], others: [String]) {
        var out: [PhotoGroup: [String]] = [:]
        for (g, set) in groups {
            out[g] = set.sorted { (order[$0] ?? .max) < (order[$1] ?? .max) }
        }
        let outOthers = others.sorted { (order[$0] ?? .max) < (order[$1] ?? .max) }
        return (out, outOthers)
    }

    func reset() {
        groups = [:]; others = []; processed = 0; total = 0
        order = [:]; nextOrder = 0
    }
}
