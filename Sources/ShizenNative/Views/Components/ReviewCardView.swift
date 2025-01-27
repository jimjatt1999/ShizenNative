import SwiftUI

struct ReviewCardView: View {
    let segment: Segment
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var settings: AppSettings
    @ObservedObject var reviewState: ReviewState
    let audioURL: URL
    let onResponse: ((String) -> Void)?
    let isCompact: Bool
    let showControls: Bool
    let isSelected: Bool
    let onSelect: (() -> Void)?
    var onTranscriptEdit: ((String) -> Void)?
    
    @State private var showTranscript: Bool
    @State private var showLanguageAnalysis = false
    @State private var isEditing = false
    @State private var editedText: String = ""
    
    var isPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString
    }
    
    init(segment: Segment, 
         audioPlayer: AudioPlayer, 
         settings: AppSettings, 
         reviewState: ReviewState,
         audioURL: URL,
         onResponse: ((String) -> Void)? = nil, 
         isCompact: Bool = false, 
         showControls: Bool = true,
         isSelected: Bool = false,
         onSelect: (() -> Void)? = nil,
         onTranscriptEdit: ((String) -> Void)? = nil) {
        self.segment = segment
        self.audioPlayer = audioPlayer
        self.settings = settings
        self.reviewState = reviewState
        self.audioURL = audioURL
        self.onResponse = onResponse
        self.isCompact = isCompact
        self.showControls = showControls
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onTranscriptEdit = onTranscriptEdit
        _showTranscript = State(initialValue: settings.settings.showTranscriptsByDefault)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: isCompact ? 4 : 8) {
                // Header with selection and duration
                HStack {
                    if let onSelect = onSelect {
                        Button(action: onSelect) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add status text
                    let segmentId = segment.id.uuidString
                    let status: ReviewStatus = {
                        if let card = reviewState.reviewCards[segmentId] {
                            if card.dueDate <= Date() {
                                return .due
                            } else {
                                return .scheduled(date: card.dueDate)
                            }
                        }
                        return .new
                    }()
                    
                    Text(status.text)
                        .font(.caption)
                        .foregroundColor(status.color)
                    
                    Spacer()
                    
                    Text(timeString(start: segment.start, end: segment.end))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, isCompact ? 12 : 16)
                .padding(.top, isCompact ? 8 : 12)
                
                // Text content with editing
                HStack {
                    if isEditing {
                        TextEditor(text: $editedText)
                            .font(.system(size: isCompact ? 14 : 16))
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                    } else if showTranscript {
                        Text(segment.text)
                            .font(.system(size: isCompact ? 14 : 16))
                            .transition(.opacity)
                    } else {
                        Text("Tap to reveal transcript")
                            .font(.system(size: isCompact ? 14 : 16))
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
                                showTranscript.toggle()
                            }
                        }) {
                            Image(systemName: showTranscript ? "eye.slash" : "eye")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, isCompact ? 12 : 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        showTranscript.toggle()
                    }
                }
                
                if showLanguageAnalysis {
                    Divider()
                    LanguageAnalysisView(text: segment.text)
                        .frame(height: isCompact ? 120 : 180)
                }
                
                Divider()
                
                // Audio waveform
                HStack(spacing: isCompact ? 10 : 15) {
                    Button(action: handlePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: isCompact ? 24 : 30, height: isCompact ? 24 : 30)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    WaveformView(audioPlayer: audioPlayer, segment: segment)
                        .frame(height: isCompact ? 32 : 40)
                }
                .padding(.horizontal, isCompact ? 12 : 16)
                .padding(.vertical, isCompact ? 8 : 10)
                
                if showControls {
                    Divider()
                    
                    // Review buttons
                    HStack(spacing: isCompact ? 8 : 15) {
                        ForEach(["Again", "Hard", "Good", "Easy"], id: \.self) { response in
                            Button(action: { onResponse?(response.lowercased()) }) {
                                Text(response)
                                    .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                    .padding(.horizontal, isCompact ? 12 : 16)
                                    .padding(.vertical, isCompact ? 6 : 8)
                                    .background(buttonColor(for: response))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(isCompact ? 8 : 15)
                }
            }
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func handlePlayback() {
        if isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                audioPlayer.load(url: audioURL)
                audioPlayer.playSegment(segment: segment)
            }
        }
    }
    
    private func buttonColor(for response: String) -> Color {
        switch response.lowercased() {
        case "again": return .red
        case "hard": return .orange
        case "good": return .green
        case "easy": return .blue
        default: return .gray
        }
    }
    
    private func timeString(start: Double, end: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return "\(formatter.string(from: start) ?? "0:00") - \(formatter.string(from: end) ?? "0:00")"
    }
}
