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
    
    var reviewStats: (newCards: Int, dueReviews: Int) {
        var newCount = 0
        var dueCount = 0
        
        for segment in segments where !segment.isHiddenFromSRS {
            let segmentId = segment.id.uuidString
            if let card = reviewState.reviewCards[segmentId] {
                if card.dueDate <= Date() {
                    dueCount += 1
                }
            } else {
                // Count as potential new card
                newCount += 1
            }
        }
        
        // Limit new cards by daily limit
        newCount = min(newCount, settings.settings.newCardsPerDay - reviewState.todayNewCards)
        return (newCount, dueCount)
    }
    
    var reviewableSegments: [Segment] {
        segments.filter { segment in
            if segment.isHiddenFromSRS { return false }
            
            let segmentId = segment.id.uuidString
            if let card = reviewState.reviewCards[segmentId] {
                return card.dueDate <= Date()
            }
            // Only include new cards if we haven't reached today's limit
            return reviewState.todayNewCards < settings.settings.newCardsPerDay
        }
    }
    
    var visibleSegments: [Segment] {
        let startIndex = reviewState.currentIndex
        let maxCards = settings.settings.cardsPerFeed
        let endIndex = min(startIndex + maxCards, reviewableSegments.count)
        
        guard startIndex < reviewableSegments.count else { return [] }
        return Array(reviewableSegments[startIndex..<endIndex])
    }
    
    var progressText: String {
        let stats = reviewStats
        let totalToReview = stats.newCards + stats.dueReviews
        let current = min(reviewState.currentIndex + 1, totalToReview)
        return "\(current) of \(totalToReview)"
    }
    
    var remainingCount: Int {
        let stats = reviewStats
        return max(0, stats.newCards + stats.dueReviews - reviewState.currentIndex)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Progress")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Cards Today")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Label("\(reviewState.todayNewCards)/\(settings.settings.newCardsPerDay)", 
                              systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cards Remaining")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Label("\(reviewStats.dueReviews)", systemImage: "clock.fill")
                                .foregroundColor(.orange)
                            Text("+")
                            Label("\(reviewStats.newCards)", systemImage: "star.fill")
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                    }
                }
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
                                    reviewState: reviewState,  // Add this line
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
        .onAppear {
            // Update current index if it's beyond available cards
            if reviewState.currentIndex >= reviewableSegments.count {
                reviewState.currentIndex = 0
            }
        }
    }
    
    private func refreshView() {
        audioPlayer.stop()
        withAnimation {
            // Ensure current index is valid
            if reviewState.currentIndex >= reviewableSegments.count {
                reviewState.currentIndex = 0
            }
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
        
        // Reset index if we've reached the end
        if reviewState.currentIndex >= reviewableSegments.count {
            reviewState.currentIndex = 0
        }
        
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
