import SwiftUI
import NaturalLanguage
import Translation  // Add this import

struct ReviewButtonWithTooltip: View {
    let title: String
    let color: Color
    let action: () -> Void
    let card: ReviewScheduler.Card
    
    @State private var isHovered = false
    @State private var showTooltip = false
    
    private var nextReviewDate: Date {
        var cardCopy = card
        return ReviewScheduler.processReview(card: &cardCopy, response: title.lowercased())
    }
    
    private var tooltipText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: nextReviewDate)
        
        let calendar = Calendar.current
        if calendar.isDateInToday(nextReviewDate) {
            return "Later today at \(dateStr.components(separatedBy: " at ").last ?? "")"
        } else if calendar.isDateInTomorrow(nextReviewDate) {
            return "Tomorrow at \(dateStr.components(separatedBy: " at ").last ?? "")"
        }
        return dateStr
    }
    
    private var tooltipOffset: CGFloat {
        showTooltip ? -40 : 0
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Tooltip
            if isHovered {
                Text(tooltipText)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.windowBackgroundColor))
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    )
                    .offset(y: tooltipOffset)
                    .opacity(showTooltip ? 1 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: tooltipOffset)
            }
            
            // Button
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(isHovered ? 0.9 : 1.0))
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTooltip = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.1)) {
                    showTooltip = false
                }
            }
        }
    }
}

struct ReviewCard: View {
    let segment: Segment
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var settings: AppSettings
    @ObservedObject var reviewState: ReviewState
    let audioURL: URL
    let onResponse: (String) -> Void
    let onTranscriptEdit: ((String) -> Void)?
    
    @State private var showTranscript: Bool
    @State private var showLanguageAnalysis = false
    @State private var showTranslation = false
    @State private var translatedText: String = ""
    @State private var isTranslating = false
    @State private var showingNoteEditor = false
    @State private var showingTranscriptEditor = false
    @State private var editingText: String = ""
    @State private var isEditing = false
    @State private var editedText: String = ""
    
    init(segment: Segment, audioPlayer: AudioPlayer, settings: AppSettings, reviewState: ReviewState, audioURL: URL, onResponse: @escaping (String) -> Void, onTranscriptEdit: ((String) -> Void)? = nil) {
        self.segment = segment
        self.audioPlayer = audioPlayer
        self.settings = settings
        self.reviewState = reviewState
        self.audioURL = audioURL
        self.onResponse = onResponse
        self.onTranscriptEdit = onTranscriptEdit
        _showTranscript = State(initialValue: settings.settings.showTranscriptsByDefault)
    }
    
    var isPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString
    }
    
    private var currentCard: ReviewScheduler.Card {
        reviewState.reviewCards[segment.id.uuidString] ?? ReviewScheduler.Card()
    }
    
    private func handleResponse(_ response: String) {
        print("[Review] Handling response: \(response)")
        audioPlayer.stop()
        
        let segmentId = segment.id.uuidString
        let isNewCard = reviewState.reviewCards[segmentId] == nil
        
        print("[Review] Sending notification - Response: \(response), New Card: \(isNewCard)")
        
        NotificationCenter.default.post(
            name: .reviewCompleted,
            object: nil,
            userInfo: [
                "response": response,
                "isNewCard": isNewCard
            ]
        )
        
        onResponse(response)
    }
    
    private func translateText() {
        guard !isTranslating else { return }
        isTranslating = true
        
        Task {
            do {
                let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
                tagger.string = segment.text
                
                // Use Apple's built-in translation service
                let request = NSURLRequest(url: URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=ja&tl=en&dt=t&q=\(segment.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!)
                
                let (data, response) = try await URLSession.shared.data(for: request as URLRequest)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                   let translations = json[0] as? [[Any]],
                   let translation = translations[0][0] as? String {
                    
                    await MainActor.run {
                        withAnimation {
                            self.translatedText = translation
                            self.isTranslating = false
                        }
                    }
                } else {
                    throw NSError(domain: "TranslationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse translation response"])
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.translatedText = "Translation failed: \(error.localizedDescription)"
                        self.isTranslating = false
                    }
                }
            }
        }
    }
    
    // Remove the simpleTranslate function as it's no longer needed
    
    private func simpleTranslate(_ text: String) -> String {
        // Basic Japanese-to-English dictionary
        let dictionary: [String: String] = [
            "コンビニエンスストア": "Convenience store",
            "鬼ギリ": "Onigiri",
            "穴上げ": "Price increase",
            "お米": "Rice",
            "行動": "Movement",
            "中": "While",
            "大事な": "Important",
            "どうやったら": "How to",
            "最大限": "To the fullest",
            "美味しく": "Deliciously",
            "食べられる": "Eat",
            "プロ": "Professional",
            "生きました": "Asked"
        ]
        
        // Split the text into words and translate using the dictionary
        let translatedText = text.components(separatedBy: " ").map { word in
            return dictionary[word] ?? word
        }.joined(separator: " ")
        
        return translatedText
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Text content with editing
            HStack {
                if isEditing {
                    TextEditor(text: $editedText)
                        .font(.system(size: 16))
                        .frame(height: 100)
                        .padding(4)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                } else if showTranscript {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(segment.text)
                            .font(.system(size: 18))
                        
                        if showTranslation {
                            Divider()
                            
                            if isTranslating {
                                ProgressView()
                                    .padding(.vertical, 8)
                            } else {
                                Text(translatedText)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .transition(.opacity)
                } else {
                    Text("Tap to reveal transcript")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if showTranscript {
                        Button(action: {
                            if isEditing {
                                onTranscriptEdit?(editedText)
                            }
                            withAnimation {
                                isEditing.toggle()
                                if isEditing {
                                    editedText = segment.text
                                }
                            }
                        }) {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Notes Button
                    Button(action: {
                        if let existingNote = reviewState.getNote(for: segment.id.uuidString) {
                            editingText = existingNote.text
                        } else {
                            editingText = ""
                        }
                        showingNoteEditor = true
                    }) {
                        if reviewState.getNote(for: segment.id.uuidString) != nil {
                            Image(systemName: "note.text.badge.plus")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "note.text")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            showLanguageAnalysis.toggle()
                        }
                    }) {
                        Image(systemName: showLanguageAnalysis ? "book.fill" : "book")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        withAnimation {
                            showTranslation.toggle()
                            if showTranslation {
                                translateText()
                            }
                        }
                    }) {
                        Image(systemName: showTranslation ? "character.book.closed.fill" : "character.book.closed")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        withAnimation {
                            showTranscript.toggle()
                        }
                    }) {
                        Image(systemName: showTranscript ? "eye.slash" : "eye")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(20)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    showTranscript.toggle()
                }
            }
            
            if showLanguageAnalysis {
                Divider()
                LanguageAnalysisView(text: segment.text)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider()
            
            // Audio controls
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    Button(action: {
                        if isPlaying {
                            audioPlayer.pause()
                        } else {
                            audioPlayer.stop()
                            audioPlayer.load(url: audioURL)
                            audioPlayer.playSegment(segment: segment)
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    WaveformView(audioPlayer: audioPlayer, segment: segment)
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                Divider()
                
                // Review buttons with tooltips
                HStack(spacing: 15) {
                    ReviewButtonWithTooltip(
                        title: "Again",
                        color: .red,
                        action: { handleResponse("again") },
                        card: currentCard
                    )
                    
                    ReviewButtonWithTooltip(
                        title: "Hard",
                        color: .orange,
                        action: { handleResponse("hard") },
                        card: currentCard
                    )
                    
                    ReviewButtonWithTooltip(
                        title: "Good",
                        color: .green,
                        action: { handleResponse("good") },
                        card: currentCard
                    )
                    
                    ReviewButtonWithTooltip(
                        title: "Easy",
                        color: .blue,
                        action: { handleResponse("easy") },
                        card: currentCard
                    )
                }
                .padding(15)
            }
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .animation(.spring(), value: showLanguageAnalysis)
        .onDisappear {
            if isPlaying {
                audioPlayer.stop()
            }
        }
        .sheet(isPresented: $showingNoteEditor) {
            NavigationView {
                VStack(spacing: 20) {
                    TextEditor(text: $editingText)
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            Group {
                                if editingText.isEmpty {
                                    Text("Add study notes, mnemonics, or context...")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 12)
                                        .padding(.top, 12)
                                }
                            }
                        )
                }
                .padding()
                .navigationTitle(reviewState.getNote(for: segment.id.uuidString) != nil ? "Edit Note" : "Add Note")
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Button("Cancel") {
                            showingNoteEditor = false
                        }
                        
                        Button(reviewState.getNote(for: segment.id.uuidString) != nil ? "Update" : "Save") {
                            if editingText.isEmpty {
                                reviewState.removeNote(for: segment.id.uuidString)
                            } else {
                                let note = UserNote(segmentId: segment.id.uuidString, text: editingText)
                                reviewState.saveNote(note, for: segment.id.uuidString)
                            }
                            showingNoteEditor = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTranscriptEditor) {
            NavigationView {
                VStack(spacing: 20) {
                    TextEditor(text: $editingText)
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)
                }
                .padding()
                .navigationTitle("Edit Transcript")
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Button("Cancel") {
                            showingTranscriptEditor = false
                        }
                        
                        Button("Save") {
                            // We need to handle transcript updates here
                            // This will require adding a callback property
                            showingTranscriptEditor = false
                        }
                    }
                }
            }
        }
    }
}