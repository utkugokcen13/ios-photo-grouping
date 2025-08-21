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

    func apply(snapshot: Snapshot) {

        // Update counts
        processed = snapshot.processed
        total = snapshot.total
        
        var newGroups: [PhotoGroup: [String]] = [:]
        for (group, count) in snapshot.counts {
            if count > 0 {
                newGroups[group] = Array(0..<count).map { "\(group.rawValue)_\($0)" }
            }
        }
        let newOthers = snapshot.othersCount > 0 ? Array(0..<snapshot.othersCount).map { "others_\($0)" } : []
        
        // Update the published properties
        groups = newGroups
        others = newOthers
    }

    func finalize(groups: [PhotoGroup: [String]], others: [String]) {
        let groupNames = Dictionary(uniqueKeysWithValues: groups.map { ($0.key.rawValue, $0.value) })
        
        self.groups = groups
        self.others = others
        
    }

    var nonEmptyGroups: [(PhotoGroup, Int)] {
        let result = groups.compactMap { ($0.key, $0.value.count) }.filter { $0.1 > 0 }.sorted { $0.0.rawValue < $1.0.rawValue }
        return result
    }
}
