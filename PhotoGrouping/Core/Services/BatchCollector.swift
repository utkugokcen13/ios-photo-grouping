//
//  BatchCollector.swift
//  PhotoGrouping
//
//  Created by Utku Gökçen on 21.08.2025.
//

import Foundation

actor BatchCollector {
    private var addedByGroup: [PhotoGroup: [String]] = [:]
    private var addedOthers: [String] = []

    func add(id: String, to group: PhotoGroup?) {
        if let g = group {
            addedByGroup[g, default: []].append(id)
        } else {
            addedOthers.append(id)
        }
    }

    func drain() -> (byGroup: [PhotoGroup: [String]], others: [String]) {
        let byGroup = addedByGroup
        let others = addedOthers
        addedByGroup = [:]
        addedOthers = []
        return (byGroup, others)
    }

    var isEmpty: Bool { addedByGroup.isEmpty && addedOthers.isEmpty }

    func reset() {
        addedByGroup = [:]
        addedOthers = []
    }
}
