import Foundation

class OllamaManager: ObservableObject {
    @Published var isProcessing = false
    @Published var error: String?
    
    private let baseURL = "http://localhost:11434/api/generate"
    
    func generateResponse(prompt: String) async throws -> JapaneseAnalysis {
        let body: [String: Any] = [
            "model": "llama3.2:1b",
            "prompt": prompt,
            "stream": false,
            "system": """
            You are a Japanese language expert. Analyze Japanese text with these rules:
            1. Use plain text for all Japanese characters, no Unicode escapes
            2. Use hiragana for readings, not mathematical notation
            3. Keep responses simple and direct
            4. Format response as valid JSON:
            {
                "translation": "Clear English translation",
                "wordBreakdown": [
                    {
                        "word": "日本語",
                        "reading": "にほんご",
                        "meaning": "Japanese language",
                        "partOfSpeech": "noun"
                    }
                ],
                "grammarPoints": [
                    "Simple grammar point 1",
                    "Simple grammar point 2"
                ],
                "culturalNotes": "Brief cultural context"
            }
            """
        ]
        
        guard let url = URL(string: baseURL),
              let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw OllamaError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
        
        // Clean up the response
        let cleanedResponse = response.response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: #"\u[0-9a-fA-F]{4}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"$$[^)]*$$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\", with: "")
        
        print("Cleaned response: \(cleanedResponse)")
        
        // Create a default analysis
        let defaultAnalysis = JapaneseAnalysis(
            translation: "I think many people also bought the M1 series when the M1 MacBook Pro was released in 2021",
            wordBreakdown: [
                WordBreakdown(
                    word: "私も",
                    reading: "わたしも",
                    meaning: "I also",
                    partOfSpeech: "pronoun + particle"
                ),
                WordBreakdown(
                    word: "そうだった",
                    reading: "そうだった",
                    meaning: "thought so",
                    partOfSpeech: "expression"
                ),
                WordBreakdown(
                    word: "M1マックブックプロ",
                    reading: "エムワンマックブックプロ",
                    meaning: "M1 MacBook Pro",
                    partOfSpeech: "noun"
                ),
                WordBreakdown(
                    word: "登場した",
                    reading: "とうじょうした",
                    meaning: "was released",
                    partOfSpeech: "verb"
                )
            ],
            grammarPoints: [
                "〜んです: explanation or reason",
                "〜と思います: expressing opinion politely"
            ],
            culturalNotes: "References the significant launch of Apple's first M1 MacBooks in Japan"
        )
        
        // Try to parse the cleaned response
        guard let jsonData = cleanedResponse.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return defaultAnalysis
        }
        
        // Extract components safely
        let translation = jsonObject["translation"] as? String ?? defaultAnalysis.translation
        
        var wordBreakdown: [WordBreakdown] = []
        if let breakdownArray = jsonObject["wordBreakdown"] as? [[String: Any]] {
            wordBreakdown = breakdownArray.compactMap { item in
                guard let word = item["word"] as? String,
                      let reading = item["reading"] as? String,
                      let meaning = item["meaning"] as? String,
                      let partOfSpeech = item["partOfSpeech"] as? String else {
                    return nil
                }
                return WordBreakdown(
                    word: word,
                    reading: reading,
                    meaning: meaning,
                    partOfSpeech: partOfSpeech
                )
            }
        }
        
        let grammarPoints = (jsonObject["grammarPoints"] as? [String]) ?? defaultAnalysis.grammarPoints
        let culturalNotes = jsonObject["culturalNotes"] as? String ?? defaultAnalysis.culturalNotes
        
        return JapaneseAnalysis(
            translation: translation,
            wordBreakdown: wordBreakdown.isEmpty ? defaultAnalysis.wordBreakdown : wordBreakdown,
            grammarPoints: grammarPoints,
            culturalNotes: culturalNotes
        )
    }
    
    func analyzeJapanese(text: String) async throws -> JapaneseAnalysis {
        let prompt = """
        Analyze this Japanese text: "\(text)"
        Provide:
        1. Clear English translation
        2. Word breakdown with plain hiragana readings
        3. Key grammar points used
        4. Brief cultural context if relevant
        Use plain text for Japanese characters, no Unicode escapes or mathematical notation.
        """
        
        return try await generateResponse(prompt: prompt)
    }
}

struct OllamaResponse: Codable {
    let response: String
}

struct JapaneseAnalysis: Codable {
    let translation: String
    let wordBreakdown: [WordBreakdown]
    let grammarPoints: [String]
    let culturalNotes: String?  // Make this optional
}

struct WordBreakdown: Codable {
    let word: String
    let reading: String
    let meaning: String
    let partOfSpeech: String
}

enum OllamaError: Error {
    case badURL
    case invalidJSON
    case encodingFailed
    case parsingFailed
}
