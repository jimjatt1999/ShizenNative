import Foundation

struct JapaneseAnalysis: Codable {
    let translation: String
    let wordBreakdown: [WordBreakdown]
    let grammarPoints: [String]
    let culturalNotes: String?
}
