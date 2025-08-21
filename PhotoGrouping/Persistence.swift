import Foundation

struct PersistedGroups: Codable {
    let version: Int
    let groups: [PhotoGroup: [String]]
    let others: [String]
    let totalCount: Int
    let processedCount: Int
    let lastSavedAt: Date
}

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let ioQueue = DispatchQueue(label: "persist.io.queue", qos: .utility)
    private var pendingWorkItem: DispatchWorkItem?

    private var groupsURL: URL {
        let dir = try! FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask, appropriateFor: nil, create: true)
        let appDir = dir.appendingPathComponent("PhotoGrouping", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("groupedIndex.json")
    }

    func save(groups: [PhotoGroup: [String]],
              others: [String],
              total: Int,
              processed: Int,
              throttle: TimeInterval = 1.0,
              force: Bool = false) {
        let payload = PersistedGroups(version: 1,
                                      groups: groups,
                                      others: others,
                                      totalCount: total,
                                      processedCount: processed,
                                      lastSavedAt: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(payload) else { 
            print("Failed to encode persistence data")
            return 
        }

        let writeBlock = { [url = self.groupsURL] in
            let tmp = url.appendingPathExtension("tmp")
            do {
                try data.write(to: tmp, options: .atomic)
                // Replace existing atomically
                _ = try? FileManager.default.removeItem(at: url)
                try FileManager.default.moveItem(at: tmp, to: url)
            } catch {
                print("Failed to write persistence data: \(error)")
            }
        }

        if force {
            print("Force saving persistence data: \(groups.count) groups, \(others.count) others")
            // Synchronous save for checkpoints to guarantee file is written before suspension
            ioQueue.sync { writeBlock() }
            return
        }
        
        ioQueue.async {
            self.pendingWorkItem?.cancel()
            let item = DispatchWorkItem(block: writeBlock)
            self.pendingWorkItem = item
            self.ioQueue.asyncAfter(deadline: .now() + throttle, execute: item)
        }
    }

    func load() -> PersistedGroups? {
        let url = groupsURL
        guard let data = try? Data(contentsOf: url) else { 
            print("No persisted data found at: \(url)")
            return nil 
        }
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(PersistedGroups.self, from: data)
            print("Loaded persisted data: \(result.groups.count) groups, \(result.others.count) others, \(result.processedCount)/\(result.totalCount) processed")
            return result
        } catch {
            print("Failed to decode persisted data: \(error)")
            return nil
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: groupsURL)
    }
}
