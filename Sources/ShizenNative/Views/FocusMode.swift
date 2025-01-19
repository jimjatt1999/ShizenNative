import SwiftUI

struct FocusModeSourceSelection: View {
    let segments: [Segment]
    let audioPlayer: AudioPlayer
    let settings: AppSettings
    let audioFiles: [String: URL]  // Add this
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSource: String?
    
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
                    audioFiles: audioFiles  // Pass audioFiles
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
                    dismiss()
                }
            }
        }
    }
}

struct FocusMode: View {
    let audioPlayer: AudioPlayer
    let settings: AppSettings
    let segments: [Segment]
    let sourceId: String
    let audioFiles: [String: URL]  // Add this
    
    @State private var currentIndex = 0
    @State private var showingExitAlert = false
    
    var body: some View {
        VStack {
            // Progress
            HStack {
                Text("\(currentIndex + 1) of \(segments.count)")
                    .font(.headline)
                Spacer()
                Button("Exit") {
                    showingExitAlert = true
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
        .alert("Exit Focus Mode", isPresented: $showingExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                NotificationCenter.default.post(
                    name: .exitFocusMode,
                    object: nil
                )
            }
        } message: {
            Text("Are you sure you want to exit focus mode?")
        }
    }
    
    private func handleResponse(_ response: String) {
        if settings.settings.countFocusModeInSRS {
            // Process SRS as normal
            let segmentId = segments[currentIndex].id.uuidString
            var card = ReviewScheduler.Card()
            _ = ReviewScheduler.processReview(card: &card, response: response)
            
            // Save the card state
            if let existingData = UserDefaults.standard.data(forKey: "reviewCards"),
               var reviewCards = try? JSONDecoder().decode([String: ReviewScheduler.Card].self, from: existingData) {
                reviewCards[segmentId] = card
                if let encoded = try? JSONEncoder().encode(reviewCards) {
                    UserDefaults.standard.set(encoded, forKey: "reviewCards")
                    UserDefaults.standard.synchronize()
                }
            }
        }
        
        // Move to next card
        withAnimation {
            currentIndex += 1
        }
    }
}
