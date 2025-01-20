import SwiftUI

struct ReviewView: View {
    let segments: [Segment]
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var settings: AppSettings
    let audioFiles: [String: URL]
    @ObservedObject var reviewState: ReviewState
    @State private var refreshID = UUID()
    @State private var forceReload = false
    @State private var sessionStartTime: Date?
    
    var visibleSegments: [Segment] {
        // Filter out hidden segments first
        let availableSegments = segments.filter { !$0.isHiddenFromSRS }
        
        // Always show the user-specified number of cards
        let startIndex = reviewState.currentIndex
        let maxCards = settings.settings.cardsPerFeed
        let endIndex = min(startIndex + maxCards, availableSegments.count)
        
        guard startIndex < availableSegments.count else { return [] }
        
        // Get the slice of segments
        var segmentSlice = Array(availableSegments[startIndex..<endIndex])
        
        // Filter for due cards and new cards
        segmentSlice = segmentSlice.filter { segment in
            let segmentId = segment.id.uuidString
            if let card = reviewState.reviewCards[segmentId] {
                return card.dueDate <= Date()
            }
            return reviewState.todayNewCards < settings.settings.newCardsPerDay
        }
        
        // If we have fewer cards than requested after filtering, try to get more
        if segmentSlice.count < maxCards {
            var additionalStartIndex = endIndex
            while segmentSlice.count < maxCards && additionalStartIndex < availableSegments.count {
                let segment = availableSegments[additionalStartIndex]
                let segmentId = segment.id.uuidString
                
                if let card = reviewState.reviewCards[segmentId] {
                    if card.dueDate <= Date() {
                        segmentSlice.append(segment)
                    }
                } else if reviewState.todayNewCards < settings.settings.newCardsPerDay {
                    segmentSlice.append(segment)
                }
                
                additionalStartIndex += 1
            }
        }
        
        return segmentSlice
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress header
            HStack {
                let totalVisible = segments.filter { !$0.isHiddenFromSRS }.count
                Text("\(reviewState.currentIndex + 1) of \(totalVisible)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 15) {
                    Label("\(reviewState.todayNewCards)/\(settings.settings.newCardsPerDay) New", 
                          systemImage: "star.fill")
                        .foregroundColor(.blue)
                    
                    Label("\(totalVisible - reviewState.currentIndex) Left", 
                          systemImage: "clock.fill")
                        .foregroundColor(.orange)
                }
                .font(.caption)
            }
            .padding()
            
            if visibleSegments.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(visibleSegments) { segment in
                            if let audioURL = audioFiles[segment.sourceId] {
                                ReviewCard(
                                    segment: segment,
                                    audioPlayer: audioPlayer,
                                    settings: settings,
                                    audioURL: audioURL
                                ) { response in
                                    handleResponse(for: segment, response: response)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .id(refreshID)
        .onChange(of: settings.settings.cardsPerFeed) { _ in
            refreshView()
        }
        .onChange(of: settings.settings.newCardsPerDay) { _ in
            refreshView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
            refreshView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .segmentsUpdated)) { _ in
            refreshView()
        }
        .onChange(of: forceReload) { _ in
            refreshID = UUID()
        }
    }
    
    private func refreshView() {
        audioPlayer.stop()
        withAnimation {
            forceReload.toggle()
            refreshID = UUID()
        }
    }
    
    private func handleResponse(for segment: Segment, response: String) {
        let segmentId = segment.id.uuidString
        var card = reviewState.reviewCards[segmentId] ?? ReviewScheduler.Card()
        
        // Process the review
        let nextDue = ReviewScheduler.processReview(card: &card, response: response)
        
        // Update new cards count if this was a new card
        if card.reviews == 0 && response != "again" {
            reviewState.todayNewCards += 1
        }
        
        // Update card
        card.reviews += 1
        card.dueDate = nextDue
        reviewState.reviewCards[segmentId] = card
        
        // Save state
        reviewState.save()
        
        // Move to next card
        reviewState.currentIndex += 1
        audioPlayer.stop()
        
        // Force refresh to update visible cards
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            refreshView()
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.green)
            
            Text("No cards to review!")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
