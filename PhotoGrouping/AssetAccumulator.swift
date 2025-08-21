import Foundation

actor AssetAccumulator {
    private var groups: [PhotoGroup: Set<String>] = [:]
    private var others: Set<String> = []
    private(set) var processed: Int = 0
    private(set) var total: Int = 0

    func setTotal(_ n: Int) { total = n }

    func insert(_ assetID: String, into group: PhotoGroup?) -> Bool {
        processed &+= 1
        if let g = group {
            if groups[g] == nil { groups[g] = [] }
            let inserted = groups[g]!.insert(assetID).inserted
            return inserted
        } else {
            let inserted = others.insert(assetID).inserted
            return inserted
        }
    }

    func snapshotCounts() -> (counts: [PhotoGroup: Int], others: Int, processed: Int, total: Int) {
        let counts = groups.mapValues { $0.count }
        let result = (counts, others.count, processed, total)
        return result
    }

    func materialize() -> (groups: [PhotoGroup: [String]], others: [String]) {
        let groupsArray = groups.mapValues { Array($0) }
        let result = (groups: groupsArray, others: Array(others))
        return result
    }
}
