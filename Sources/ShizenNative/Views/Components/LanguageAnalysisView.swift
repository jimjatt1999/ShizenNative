import SwiftUI
import NaturalLanguage

struct LanguageAnalysisView: View {
    let text: String
    @StateObject private var analyzer = LanguageAnalyzer.shared
    @State private var words: [WordAnalysis] = []
    @State private var isLoading = false
    @State private var selectedWord: WordAnalysis?
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing text...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
            } else if !words.isEmpty {
                ScrollView {
                    WordBreakdownListView(words: words) { word in
                        analyzer.openInDictionary(word.word)
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)
            } else {
                Button(action: analyze) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.circle")
                        Text("Analyze Text")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .id(text)
    }
    
    private func analyze() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            let results = await Task.detached {
                return LanguageAnalyzer.shared.analyze(text)
            }.value
            
            await MainActor.run {
                withAnimation {
                    self.words = results
                    self.isLoading = false
                }
            }
        }
    }
}

struct WordBreakdownListView: View {
    let words: [WordAnalysis]
    let onWordTap: (WordAnalysis) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(words) { word in
                WordBreakdownRow(word: word, onTap: onWordTap)
            }
        }
    }
}

struct WordBreakdownRow: View {
    let word: WordAnalysis
    let onTap: (WordAnalysis) -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onTap(word) }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 15, weight: .medium))
                    
                    if word.reading != word.word {
                        Text(word.reading)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(word.partOfSpeech)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                        .opacity(isHovered ? 1 : 0)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
