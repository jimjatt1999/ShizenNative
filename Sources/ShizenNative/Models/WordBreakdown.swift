import Foundation

struct WordBreakdown: Codable, Identifiable {
    let word: String
    let reading: String
    let meaning: String
    let partOfSpeech: String
    
    var id: String { word }
}
