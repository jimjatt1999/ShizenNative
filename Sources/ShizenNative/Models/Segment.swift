import Foundation

struct Segment: Identifiable, Codable {
    let id: UUID
    let text: String
    let start: Double
    let end: Double
    var sourceId: String
    let hash: String
    var isDuplicate: Bool
    var isHiddenFromSRS: Bool
    
    init(id: UUID = UUID(), text: String, start: Double, end: Double, sourceId: String = "") {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.sourceId = sourceId
        self.hash = DuplicateManager.hash(for: text)
        self.isDuplicate = false
        self.isHiddenFromSRS = false
    }
}
