import Foundation

@MainActor
class OllamaManager: ObservableObject {
    @Published var isProcessing = false
    @Published var error: String?
    
    private let baseURL = "http://localhost:11434/api/generate"
    
    func analyzeJapanese(text: String) async throws -> JapaneseAnalysis {
        let body: [String: Any] = [
            "model": "llama3.2:1b",
            "prompt": """
            Analyze this Japanese text (provide response in JSON only):
            "\(text)"
            
            Required JSON format:
            {
                "translation": "English translation",
                "wordBreakdown": [
                    {
                        "word": "word in Japanese",
                        "reading": "reading in hiragana",
                        "meaning": "meaning in English",
                        "partOfSpeech": "part of speech"
                    }
                ],
                "grammarPoints": [
                    "grammar point explanation"
                ],
                "culturalNotes": "cultural context if relevant"
            }
            """,
            "stream": false,
            "temperature": 0.1,
            "system": """
            You are a Japanese language expert. 
            - Respond with ONLY valid JSON
            - No markdown, no comments
            - Ensure all Japanese text is properly encoded
            - Keep responses focused and concise
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
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
            
            // Extract and clean JSON
            let cleanedResponse = extractJSON(from: response.response)
            
            guard let jsonData = cleanedResponse.data(using: .utf8) else {
                print("Failed to encode cleaned response to data")
                throw OllamaError.encodingFailed
            }
            
            do {
                return try JSONDecoder().decode(JapaneseAnalysis.self, from: jsonData)
            } catch {
                print("JSON parsing error: \(error)")
                print("Cleaned response: \(cleanedResponse)")
                
                // Return fallback analysis
                return JapaneseAnalysis(
                    translation: text,  // Use original text as fallback
                    wordBreakdown: [
                        WordBreakdown(
                            word: text,
                            reading: "",
                            meaning: "Analysis unavailable",
                            partOfSpeech: ""
                        )
                    ],
                    grammarPoints: [],
                    culturalNotes: nil
                )
            }
        } catch {
            print("Network or processing error: \(error)")
            throw OllamaError.serverError(error.localizedDescription)
        }
    }
    
    private func extractJSON(from response: String) -> String {
        // First, try to find JSON between curly braces
        if let start = response.firstIndex(of: "{"),
           let end = response.lastIndex(of: "}") {
            let jsonSubstring = response[start...end]
            return String(jsonSubstring)
        }
        
        // If no JSON found, clean the response and try to make it valid JSON
        var cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure the response starts with { and ends with }
        if !cleaned.hasPrefix("{") {
            cleaned = "{\n" + cleaned
        }
        if !cleaned.hasSuffix("}") {
            cleaned = cleaned + "\n}"
        }
        
        // Remove any comments
        cleaned = cleaned.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        
        return cleaned
    }
}

struct OllamaResponse: Codable {
    let response: String
}

struct JapaneseAnalysis: Codable {
    let translation: String
    let wordBreakdown: [WordBreakdown]
    let grammarPoints: [String]
    let culturalNotes: String?
    
    init(translation: String, wordBreakdown: [WordBreakdown], grammarPoints: [String], culturalNotes: String?) {
        self.translation = translation
        self.wordBreakdown = wordBreakdown
        self.grammarPoints = grammarPoints
        self.culturalNotes = culturalNotes
    }
}

struct WordBreakdown: Codable, Identifiable {
    let word: String
    let reading: String
    let meaning: String
    let partOfSpeech: String
    
    var id: String { word }  // Add Identifiable conformance
}

enum OllamaError: Error, LocalizedError {
    case badURL
    case invalidJSON
    case encodingFailed
    case parsingFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid URL or request configuration"
        case .invalidJSON:
            return "Invalid JSON response from server"
        case .encodingFailed:
            return "Failed to encode response data"
        case .parsingFailed:
            return "Failed to parse server response"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
