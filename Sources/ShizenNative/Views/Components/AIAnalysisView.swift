import SwiftUI

struct AIAnalysisView: View {
    let text: String
    @StateObject private var ollamaManager = OllamaManager()
    @State private var analysis: JapaneseAnalysis?
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let tabs = ["Translation", "Words", "Grammar", "Context"]
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing with AI...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
            } else if let analysis = analysis {
                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Button(action: {
                            withAnimation {
                                selectedTab = index
                            }
                        }) {
                            Text(tabs[index])
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedTab == index ? Color.blue.opacity(0.1) : Color.clear)
                                .foregroundColor(selectedTab == index ? .blue : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if index < tabs.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(.windowBackgroundColor))
                .cornerRadius(8)
                
                Divider()
                
                // Content
                ScrollView {
                    switch selectedTab {
                    case 0:
                        TranslationView(translation: analysis.translation)
                    case 1:
                        WordBreakdownListView(words: analysis.wordBreakdown)
                    case 2:
                        GrammarPointsView(points: analysis.grammarPoints)
                    case 3:
                        CulturalNotesView(notes: analysis.culturalNotes)
                    default:
                        EmptyView()
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)
            } else {
                Button(action: analyze) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Analyze with AI")
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
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .id(text)
    }
    
    private func analyze() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let newAnalysis = try await ollamaManager.analyzeJapanese(text: text)
                await MainActor.run {
                    withAnimation {
                        self.analysis = newAnalysis
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Analysis failed: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
}

struct TranslationView: View {
    let translation: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(translation)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(translation, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct WordBreakdownListView: View {
    let words: [WordBreakdown]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if words.isEmpty {
                Text("No word breakdown available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(words, id: \.word) { word in
                    WordBreakdownView(word: word)
                }
            }
        }
    }
}

struct GrammarPointsView: View {
    let points: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if points.isEmpty {
                Text("No grammar points available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                        Text(point)
                    }
                }
            }
        }
    }
}

struct CulturalNotesView: View {
    let notes: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notes = notes {
                Text(notes)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No cultural notes available")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WordBreakdownView: View {
    let word: WordBreakdown
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(word.word)
                .font(.system(size: 15, weight: .medium))
            Text(word.reading)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("•")
                .foregroundColor(.secondary)
            Text(word.meaning)
                .font(.system(size: 13))
            Spacer()
            Text(word.partOfSpeech)
                .font(.system(size: 11))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}
