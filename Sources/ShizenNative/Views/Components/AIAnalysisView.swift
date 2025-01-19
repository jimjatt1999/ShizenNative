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
        VStack(spacing: 15) {
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing with AI...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else if let analysis = analysis {
                VStack(spacing: 0) {
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
                        .padding(.vertical, 8)
                    
                    // Content
                    ScrollView {
                        switch selectedTab {
                        case 0:
                            // Translation
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Translation", systemImage: "character.book.closed")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(analysis.translation, forType: .string)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                Text(analysis.translation)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.windowBackgroundColor))
                                    .cornerRadius(8)
                            }
                            
                        case 1:
                            // Word Breakdown
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Vocabulary", systemImage: "textformat")
                                    .font(.headline)
                                
                                if analysis.wordBreakdown.isEmpty {
                                    Text("No word breakdown available")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    ForEach(analysis.wordBreakdown, id: \.word) { word in
                                        WordBreakdownView(word: word)
                                    }
                                }
                            }
                            
                        case 2:
                            // Grammar Points
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Grammar Points", systemImage: "list.bullet.indent")
                                    .font(.headline)
                                
                                if analysis.grammarPoints.isEmpty {
                                    Text("No grammar points available")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    ForEach(analysis.grammarPoints, id: \.self) { point in
                                        HStack(alignment: .top) {
                                            Image(systemName: "arrow.right.circle")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                            Text(point)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            
                        case 3:
                            // Cultural Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Cultural Context", systemImage: "text.book.closed")
                                    .font(.headline)
                                
                                if let culturalNotes = analysis.culturalNotes {
                                    Text(culturalNotes)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.windowBackgroundColor))
                                        .cornerRadius(8)
                                } else {
                                    Text("No cultural notes available")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                }
                            }
                            
                        default:
                            EmptyView()
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 15) {
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
                    
                    Text("Using local LLM for analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }
        }
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func analyze() {
        isLoading = true
        Task {
            do {
                analysis = try await ollamaManager.analyzeJapanese(text: text)
            } catch {
                print("Analysis error: \(error)")
                errorMessage = "Failed to analyze text: \(error.localizedDescription)"
                showError = true
                // Provide a fallback analysis
                analysis = JapaneseAnalysis(
                    translation: "Could not analyze text. Please try again.",
                    wordBreakdown: [],
                    grammarPoints: ["Analysis unavailable"],
                    culturalNotes: nil  // Now this is valid since it's optional
                )
            }
            isLoading = false
        }
    }
}

struct WordBreakdownView: View {
    let word: WordBreakdown
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(word.word)
                    .font(.headline)
                Text("「\(word.reading)」")
                    .foregroundColor(.secondary)
                Spacer()
                Text(word.partOfSpeech)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            Text(word.meaning)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.windowBackgroundColor).opacity(isHovered ? 0.8 : 1.0))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
