import CryptoKit
import Photos
import UIKit

extension PHAsset {
    // Thread.sleep is added to simulate variability in hash calculation time
    func reliableHash() -> Double {
        Thread.sleep(forTimeInterval: Double.random(in: 0.01 ... 0.02))
        let data = Data(localIdentifier.utf8)
        let digest = SHA256.hash(data: data)
        let prefix = digest.prefix(8)
        let value = prefix.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        return Double(value) / Double(UInt64.max)
    }
}

enum PhotoGroup: String, CaseIterable, Codable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t

    var range: ClosedRange<Double> {
        switch self {
        case .a: return 0.00 ... 0.01
        case .b: return 0.02 ... 0.04
        case .c: return 0.05 ... 0.06
        case .d: return 0.08 ... 0.09
        case .e: return 0.11 ... 0.14
        case .f: return 0.15 ... 0.159
        case .g: return 0.17 ... 0.19
        case .h: return 0.20 ... 0.22
        case .i: return 0.25 ... 0.29
        case .j: return 0.30 ... 0.35
        case .k: return 0.36 ... 0.38
        case .l: return 0.42 ... 0.45
        case .m: return 0.47 ... 0.50
        case .n: return 0.52 ... 0.55
        case .o: return 0.57 ... 0.60
        case .p: return 0.62 ... 0.70
        case .q: return 0.72 ... 0.80
        case .r: return 0.82 ... 0.88
        case .s: return 0.89 ... 0.94
        case .t: return 0.96 ... 1.00
        }
    }

    static func group(for hash: Double) -> PhotoGroup? {
        return allCases.first { $0.range.contains(hash) }
    }
}
