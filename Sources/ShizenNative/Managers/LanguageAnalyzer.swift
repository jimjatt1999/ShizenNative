import Foundation
import NaturalLanguage
import AppKit

struct WordAnalysis: Identifiable {
    let id = UUID()
    let word: String
    let reading: String
    let partOfSpeech: String
    let lookupURL: URL?
    
    var dictionaryString: String {
        // Create dictionary lookup string
        return "dictionary://\(word)"
    }
}

class LanguageAnalyzer: ObservableObject {
    static let shared = LanguageAnalyzer()
    private let tagger: NLTagger
    @Published var isProcessing = false
    
    init() {
        tagger = NLTagger(tagSchemes: [.tokenType, .language, .lexicalClass])
    }
    
    func analyze(_ text: String) -> [WordAnalysis] {
        tagger.string = text
        var results: [WordAnalysis] = []
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, 
                            unit: .word,
                            scheme: .lexicalClass,
                            options: options) { tag, range in
            let word = String(text[range])
            let reading = getReading(for: word)
            let pos = tag?.rawValue ?? "unknown"
            
            // Create dictionary lookup URL
            let lookupURL = URL(string: "dict://\(word)")
            
            results.append(WordAnalysis(
                word: word,
                reading: reading,
                partOfSpeech: translatePartOfSpeech(pos),
                lookupURL: lookupURL
            ))
            
            return true
        }
        
        return results
    }
    
    func openInDictionary(_ word: String) {
        if let url = URL(string: "dict://\(word)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func getReading(for text: String) -> String {
        return text.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text
    }
    
    private func translatePartOfSpeech(_ tag: String) -> String {
        switch tag {
        case "Noun": return "名詞 (Noun)"
        case "Verb": return "動詞 (Verb)"
        case "Adjective": return "形容詞 (Adjective)"
        case "Adverb": return "副詞 (Adverb)"
        case "Particle": return "助詞 (Particle)"
        default: return tag
        }
    }
}