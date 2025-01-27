import Foundation

struct Segment: Identifiable, Codable {
    let id: UUID
    var text: String
    let start: Double
    let end: Double
    var sourceId: String
    var isHiddenFromSRS: Bool
    var hash: String {
        return "\(text)-\(start)-\(end)"
    }
    
    init(id: UUID = UUID(), text: String, start: TimeInterval, end: TimeInterval, sourceId: String = "") {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.sourceId = sourceId
        self.isHiddenFromSRS = false
    }
    
    mutating func updateTranscript(_ newText: String) {
        text = newText
    }
}
