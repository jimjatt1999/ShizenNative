import SwiftUI

struct ReviewCard: View {
    let segment: Segment
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var settings: AppSettings
    let audioURL: URL
    let onResponse: (String) -> Void
    
    @State private var showTranscript: Bool
    @State private var playbackSpeed: Float = 1.0
    @State private var showAIAnalysis = false
    
    private let availableSpeeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    
    init(segment: Segment, audioPlayer: AudioPlayer, settings: AppSettings, audioURL: URL, onResponse: @escaping (String) -> Void) {
        self.segment = segment
        self.audioPlayer = audioPlayer
        self.settings = settings
        self.audioURL = audioURL
        self.onResponse = onResponse
        _showTranscript = State(initialValue: settings.settings.showTranscriptsByDefault)
        
        // Debug print to verify segment data
        print("Initializing ReviewCard for segment:")
        print("ID: \(segment.id)")
        print("Text: \(segment.text)")
        print("Start: \(segment.start)")
        print("End: \(segment.end)")
        print("Source: \(segment.sourceId)")
        print("Audio URL: \(audioURL.path)")
    }
    
    private var isThisCardPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString
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
                        if isThisCardPlaying {
                            audioPlayer.pause()
                        } else {
                            // Stop any other playing audio first
                            audioPlayer.stop()
                            // Load the correct audio file
                            audioPlayer.load(url: audioURL)
                            // Then play this segment
                            audioPlayer.playSegment(segment: segment)
                        }
                    }) {
                        Image(systemName: isThisCardPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    // Waveform with integrated speed control
                    HStack(spacing: 0) {
                        WaveformView(audioPlayer: audioPlayer, segment: segment)
                            .frame(height: 40)
                        
                        // Speed control
                        Menu {
                            ForEach(availableSpeeds, id: \.self) { speed in
                                Button(action: {
                                    playbackSpeed = speed
                                    audioPlayer.setPlaybackRate(speed)
                                }) {
                                    HStack {
                                        Text("\(String(format: "%.2fx", speed))")
                                        if speed == playbackSpeed {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: playbackSpeed > 1.0 ? "forward.circle.fill" : "forward.circle")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                Divider()
                
                // Review buttons
                HStack(spacing: 15) {
                    ReviewButton(title: "Again", color: .red) {
                        audioPlayer.stop()
                        onResponse("again")
                    }
                    ReviewButton(title: "Hard", color: .orange) {
                        audioPlayer.stop()
                        onResponse("hard")
                    }
                    ReviewButton(title: "Good", color: .green) {
                        audioPlayer.stop()
                        onResponse("good")
                    }
                    ReviewButton(title: "Easy", color: .blue) {
                        audioPlayer.stop()
                        onResponse("easy")
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
            // Stop playback if this card's audio is playing when the card disappears
            if isThisCardPlaying {
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
