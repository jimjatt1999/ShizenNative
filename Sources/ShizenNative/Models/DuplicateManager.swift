import Foundation
import CryptoKit

struct DuplicateManager {
    static func hash(for text: String) -> String {
        let inputData = Data(text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func isDuplicate(_ segment: Segment, in segments: [Segment]) -> Bool {
        let newHash = segment.hash
        return segments.contains { existingSegment in
            existingSegment.hash == newHash
        }
    }
}
