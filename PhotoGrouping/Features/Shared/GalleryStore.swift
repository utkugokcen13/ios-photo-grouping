//
//  GalleryStore.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import Foundation
import SwiftUI

final class GalleryStore: ObservableObject {
    @Published private(set) var groups: [PhotoGroup: [String]] = [:]
    @Published private(set) var others: [String] = []
    @Published private(set) var processed: Int = 0
    @Published private(set) var total: Int = 0

    private var seen = Set<String>()

    init() {
        if let persisted = PersistenceManager.shared.load() {
            self.groups = persisted.groups
            self.others = persisted.others
            self.total = persisted.totalCount
            self.processed = persisted.processedCount
            self.seen = Set(persisted.groups.values.flatMap { $0 } + persisted.others)
        } else {
            print("GalleryStore initialized with no persisted data")
        }
    }

    func knownIDs() -> Set<String> { seen } // for scanner resume

    func apply(snapshot: Snapshot, forceSave: Bool = false) {
        processed = snapshot.processed
        total = snapshot.total

        for (g, ids) in snapshot.addedByGroup {
            var bucket = groups[g, default: []]
            for id in ids where !seen.contains(id) {
                seen.insert(id)
                bucket.append(id)
            }
            groups[g] = bucket
        }
        for id in snapshot.addedOthers where !seen.contains(id) {
            seen.insert(id)
            others.append(id)
        }

        // Persist throttled in background
        PersistenceManager.shared.save(groups: groups,
                                       others: others,
                                       total: total,
                                       processed: processed,
                                       throttle: forceSave ? 0.0 : 1.0,
                                       force: forceSave)
    }

    func finalize(groups: [PhotoGroup: [String]], others: [String]) {
        self.groups = groups
        self.others = others
        self.seen = Set(groups.values.flatMap { $0 } + others)
        self.processed = groups.values.reduce(0, { $0 + $1.count }) + others.count
        self.total = self.processed

        PersistenceManager.shared.save(groups: self.groups,
                                       others: self.others,
                                       total: self.total,
                                       processed: self.processed,
                                       throttle: 0.0,
                                       force: true)
    }

    func resetAll() {
        groups = [:]
        others = []
        processed = 0
        total = 0
        seen = []
        PersistenceManager.shared.clear()
    }
    
    func updateProgress(processed: Int, total: Int) {
        self.processed = processed
        self.total = total
    }

    var nonEmptyGroups: [(PhotoGroup, Int)] {
        let result = groups.compactMap { ($0.key, $0.value.count) }.filter { $0.1 > 0 }.sorted { $0.0.rawValue < $1.0.rawValue }
        return result
    }
}
