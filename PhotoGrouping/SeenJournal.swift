import Foundation

final class SeenJournal {
    static let shared = SeenJournal()

    private let q = DispatchQueue(label: "seen.journal.io", qos: .utility)
    private var pending: [String] = []
    private var lastFlush = Date(timeIntervalSince1970: 0)

    private var url: URL {
        let dir = try! FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask, appropriateFor: nil, create: true)
        let appDir = dir.appendingPathComponent("PhotoGrouping", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("seen.journal")
    }

    /// Append IDs to in-memory buffer, throttled flush to disk (append-only).
    func append(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        q.async {
            self.pending.append(contentsOf: ids)
            self.flushIfNeeded()
        }
    }

    /// Force flush any pending IDs synchronously.
    func flushSync() {
        q.sync { self.flush(force: true) }
    }

    /// Read all IDs from journal (disk + current buffer).
    func loadAll() -> Set<String> {
        var ids: [String] = []
        q.sync {
            if let data = try? Data(contentsOf: self.url),
               let text = String(data: data, encoding: .utf8) {
                // newline-separated IDs
                ids = text.split(whereSeparator: \.isNewline).map { String($0) }
            }
            ids.append(contentsOf: self.pending)
        }
        return Set(ids)
    }

    /// Clear journal file and memory.
    func clear() {
        q.sync {
            self.pending.removeAll()
            try? FileManager.default.removeItem(at: self.url)
        }
    }

    // MARK: - Private

    private func flushIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(self.lastFlush) >= 0.25 || pending.count >= 100 {
            flush(force: false)
            lastFlush = now
        }
    }

    private func flush(force: Bool) {
        guard force || !pending.isEmpty else { return }
        let toWrite = pending
        pending.removeAll()

        // Append as newline-delimited to avoid JSON overhead
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = (toWrite.joined(separator: "\n") + "\n").data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
            try? handle.close()
        } else {
            // Create file
            let text = toWrite.joined(separator: "\n") + "\n"
            try? text.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
}
