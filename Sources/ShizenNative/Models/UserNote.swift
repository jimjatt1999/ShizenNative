import Foundation

struct UserNote: Codable, Identifiable {
    let id: UUID
    let segmentId: String
    var text: String
    var createdAt: Date
    var updatedAt: Date
    
    init(segmentId: String, text: String) {
        self.id = UUID()
        self.segmentId = segmentId
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Add Codable conformance for Date and UUID
    enum CodingKeys: String, CodingKey {
        case id, segmentId, text, createdAt, updatedAt
    }
} 