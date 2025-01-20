import SwiftUI

struct FocusModeSourceSelection: View {
    let segments: [Segment]
    let audioPlayer: AudioPlayer
    let settings: AppSettings
    let audioFiles: [String: URL]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSource: String?
    @State private var showingConfirmation = false
    @State private var hasChanges = false
    @ObservedObject var reviewState: ReviewState
    
    var sources: [String] {
        Array(Set(segments.map { $0.sourceId })).sorted()
    }
    
    var body: some View {
        NavigationView {
            List(sources, id: \.self, selection: $selectedSource) { source in
                HStack {
                    Text(source)
                    Spacer()
                    Text("\(segments.filter { $0.sourceId == source }.count) segments")
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            
            if let source = selectedSource {
                FocusMode(
                    audioPlayer: audioPlayer,
                    settings: settings,
                    segments: segments.filter { $0.sourceId == source },
                    sourceId: source,
                    audioFiles: audioFiles,
                    reviewState: reviewState,
                    onProgressChange: { hasChanges = true }
                )
            } else {
                Text("Select a source to study")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("Focus Mode")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    if settings.settings.countFocusModeInSRS && hasChanges {
                        showingConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .alert("Save Progress?", isPresented: $showingConfirmation) {
            Button("Save and Exit", role: .destructive) {
                if settings.settings.countFocusModeInSRS {
                    // Save the current state
                    reviewState.save()
                    
                    // Update last review date
                    UserDefaults.standard.set(Date(), forKey: "lastReviewDate")
                    UserDefaults.standard.synchronize()
                    
                    // Post notifications to force refresh
                    NotificationCenter.default.post(
                        name: .reviewProgressReset,
                        object: nil
                    )
                }
                
                dismiss()
            }
            Button("Exit Without Saving", role: .destructive) {
                if settings.settings.countFocusModeInSRS {
                    // Restore the backup state
                    reviewState.restoreFromBackup()
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to save your progress? This will update your review progress.")
        }
        .onAppear {
            if settings.settings.countFocusModeInSRS {
                // Create backup of current state
                reviewState.createBackup()
            }
        }
    }
}

struct FocusMode: View {
    let audioPlayer: AudioPlayer
    let settings: AppSettings
    let segments: [Segment]
    let sourceId: String
    let audioFiles: [String: URL]
    @ObservedObject var reviewState: ReviewState
    let onProgressChange: () -> Void
    
    @State private var currentIndex = 0
    
    var body: some View {
        VStack {
            // Progress and limits
            HStack {
                Text("\(currentIndex + 1) of \(segments.count)")
                    .font(.headline)
                Spacer()
                if settings.settings.countFocusModeInSRS {
                    Text("\(reviewState.todayNewCards)/\(settings.settings.newCardsPerDay) new cards today")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            if currentIndex < segments.count {
                // Current card
                if let audioURL = audioFiles[segments[currentIndex].sourceId] {
                    ReviewCard(
                        segment: segments[currentIndex],
                        audioPlayer: audioPlayer,
                        settings: settings,
                        reviewState: reviewState,
                        audioURL: audioURL,
                        onResponse: { response in
                            handleResponse(response)
                        }
                    )
                    .padding()
                }
            } else {
                // Completion view
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    
                    Text("Session Complete!")
                        .font(.title)
                    
                    Button("Start Over") {
                        currentIndex = 0
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func handleResponse(_ response: String) {
        if settings.settings.countFocusModeInSRS {
            let segment = segments[currentIndex]
            let segmentId = segment.id.uuidString
            
            // Check if this would be a new card
            let isNewCard = reviewState.reviewCards[segmentId] == nil
            
            // Create or update card
            var card = reviewState.reviewCards[segmentId] ?? ReviewScheduler.Card()
            let nextDue = ReviewScheduler.processReview(card: &card, response: response)
            
            // Update new cards count if this was a new card
            if isNewCard && response != "again" && reviewState.todayNewCards < settings.settings.newCardsPerDay {
                reviewState.todayNewCards += 1
            }
            
            // Update card
            card.dueDate = nextDue
            reviewState.reviewCards[segmentId] = card
            
            onProgressChange()
        }
        
        // Move to next card
        withAnimation {
            currentIndex += 1
        }
    }
}
