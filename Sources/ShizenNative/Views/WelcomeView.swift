import SwiftUI
import AppKit

struct WelcomeView: View {
    let segments: [Segment]
    @ObservedObject var reviewState: ReviewState
    @Binding var selectedView: String?
    @State private var isWaving = false
    @State private var cardOffset: CGFloat = 400
    @State private var currentCardIndex = 0
    @State private var isFlipping = false
    @State private var navigateToReview = false
    @State private var showingFilePicker = false
    @State private var isTranscribing = false
    @State private var transcriptionProgress = ""
    
    var dueCards: [(id: String, card: ReviewScheduler.Card, segment: Segment)] {
        reviewState.reviewCards.filter { 
            $0.value.dueDate <= Date() 
        }.compactMap { id, card in
            if let segmentId = UUID(uuidString: id),
               let segment = segments.first(where: { $0.id == segmentId }) {
                return (id: id, card: card, segment: segment)
            }
            return nil
        }
    }
    
    private var cardsPreview: some View {
        Group {
            if !dueCards.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        ForEach(Array(dueCards.enumerated()), id: \.element.id) { index, pair in
                            ReviewCardView(
                                segment: pair.segment,
                                audioPlayer: AudioPlayer(),
                                settings: AppSettings(),
                                audioURL: URL(fileURLWithPath: ""),
                                onResponse: nil,
                                isCompact: true,
                                showControls: false,
                                isSelected: false,
                                onSelect: nil,
                                onTranscriptEdit: nil,
                                reviewState: reviewState
                            )
                            .frame(width: 400, height: 150)
                            .offset(x: CGFloat(index - currentCardIndex) * 10.0,
                                    y: CGFloat(index - currentCardIndex) * 10.0)
                            .opacity(index == currentCardIndex ? 1.0 : 1.0)
                            .scaleEffect(index == currentCardIndex ? 1.0 : 0.9)
                            .rotation3DEffect(
                                .degrees(isFlipping && index == currentCardIndex ? 180 : 0),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .zIndex(Double(dueCards.count - index))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    if index == currentCardIndex {
                                        isFlipping.toggle()
                                    } else {
                                        currentCardIndex = index
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, -100)
                    
                    Spacer()
                        .frame(height: 50)
                    
                    Text("\(dueCards.count) cards due for review")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<dueCards.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentCardIndex ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.bottom, -30)
            }
        }
    }
    
    var newToday: Int {
        reviewState.reviewCards.filter {
            Calendar.current.isDateInToday($0.value.dueDate)
        }.count
    }
    
    private var headerView: some View {
        VStack(spacing: 40) {
            Text("Welcome to Shizen")
                .font(.system(size: 48, weight: .bold))
            
            HStack(spacing: 4) {
                ForEach(0..<10) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .frame(width: 3, height: 20)
                        .foregroundColor(.blue.opacity(1.0))
                        .scaleEffect(y: isWaving ? 1.0 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.1),
                            value: isWaving
                        )
                }
            }
            .onAppear { isWaving = true }
            
            Text("Your personal Japanese immersion companion")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
    private var statsView: some View {
        HStack(spacing: 60) {
            VStack {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.blue)
                    Text("\(newToday)/20")
                        .font(.title2)
                }
                Text("New Today")
                    .foregroundColor(.secondary)
            }
            
            VStack {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text("\(dueCards.count)")
                        .font(.title2)
                }
                Text("Due Now")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var quickActionsView: some View {
        VStack(spacing: 20) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 30) {
                Button(action: {
                    selectedView = "Review"
                }) {
                    Label("Start Review", systemImage: "play.fill")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    selectedView = "Upload"
                }) {
                    Label("Upload Content", systemImage: "arrow.up.circle")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
    
    var body: some View {
        VStack(spacing: 40) {
            headerView
            Spacer()
            cardsPreview
            statsView
                .padding(.top, 40)
            quickActionsView
                .padding(.top, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper Components
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(width: 120, height: 100)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
}

struct DueCardPreview: View {
    let segment: Segment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(segment.text)
                .font(.system(size: 16))
                .lineLimit(3)
                .padding(.bottom, 8)
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Due now")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 14))
            }
            .foregroundColor(color)
            .frame(width: 120, height: 80)
            .background(Color(.windowBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 