import SwiftUI

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
        .animation(.spring(), value: showAIAnalysis)
        .onDisappear {
            if isPlaying {
                audioPlayer.stop()
            }
        }
    }
}