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

    private var seen = Set<String>() // global seen set to guard against duplicates

    func apply(snapshot: Snapshot) {
        processed = snapshot.processed
        total = snapshot.total

        // Append real IDs by group
        for (g, ids) in snapshot.addedByGroup {
            var bucket = groups[g, default: []]
            for id in ids where !seen.contains(id) {
                seen.insert(id)
                bucket.append(id)
            }
            groups[g] = bucket
        }

        // Append Others
        if !snapshot.addedOthers.isEmpty {
            for id in snapshot.addedOthers where !seen.contains(id) {
                seen.insert(id)
                others.append(id)
            }
        }
    }

    func finalize(groups: [PhotoGroup: [String]], others: [String]) {
        self.groups = groups
        self.others = others
        self.seen = Set(groups.values.flatMap { $0 } + others)
    }

    var nonEmptyGroups: [(PhotoGroup, Int)] {
        let result = groups.compactMap { ($0.key, $0.value.count) }.filter { $0.1 > 0 }.sorted { $0.0.rawValue < $1.0.rawValue }
        return result
    }
}
