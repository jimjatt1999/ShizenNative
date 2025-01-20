import SwiftUI

struct ReviewCard: View {
    let segment: Segment
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var settings: AppSettings
    @ObservedObject var reviewState: ReviewState
    let audioURL: URL
    let onResponse: (String) -> Void
    
    @State private var showTranscript: Bool
    @State private var showAIAnalysis = false
    
    init(segment: Segment, audioPlayer: AudioPlayer, settings: AppSettings, reviewState: ReviewState, audioURL: URL, onResponse: @escaping (String) -> Void) {
        self.segment = segment
        self.audioPlayer = audioPlayer
        self.settings = settings
        self.reviewState = reviewState
        self.audioURL = audioURL
        self.onResponse = onResponse
        _showTranscript = State(initialValue: settings.settings.showTranscriptsByDefault)
    }
    
    var isPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString
    }
    
    private func handleResponse(_ response: String) {
        print("[Review] Handling response: \(response)")
        
        // Stop any playing audio
        audioPlayer.stop()
        
        // Get the current card state
        let segmentId = segment.id.uuidString
        let isNewCard = reviewState.reviewCards[segmentId] == nil
        
        print("[Review] Sending notification - Response: \(response), New Card: \(isNewCard)")
        
        // Post notification for statistics
        NotificationCenter.default.post(
            name: .reviewCompleted,
            object: nil,
            userInfo: [
                "response": response,
                "isNewCard": isNewCard
            ]
        )
        
        // Call the response handler
        onResponse(response)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Text content with reveal and AI buttons
            HStack {
                if showTranscript {
                    Text(segment.text)
                        .font(.system(size: 18))
                        .transition(.opacity)
                } else {
                    Text("Tap to reveal transcript")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation {
                            showAIAnalysis.toggle()
                        }
                    }) {
                        Image(systemName: showAIAnalysis ? "brain.fill" : "brain")
                            .foregroundColor(.purple)
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
            
            // AI Analysis section (if enabled)
            if showAIAnalysis {
                Divider()
                AIAnalysisView(text: segment.text)
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
                
                // Review buttons
                HStack(spacing: 15) {
                    ReviewButton(title: "Again", color: .red) {
                        handleResponse("again")
                    }
                    ReviewButton(title: "Hard", color: .orange) {
                        handleResponse("hard")
                    }
                    ReviewButton(title: "Good", color: .green) {
                        handleResponse("good")
                    }
                    ReviewButton(title: "Easy", color: .blue) {
                        handleResponse("easy")
                    }
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
        .animation(.spring(), value: showAIAnalysis)
        .onDisappear {
            if isPlaying {
                audioPlayer.stop()
            }
        }
    }
}

struct ReviewButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(isHovered ? 0.9 : 1.0))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
