import SwiftUI
import AVFoundation

struct ManageView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var segments: [Segment]
    @Binding var audioFiles: [String: URL]
    @StateObject var reviewState: ReviewState
    @State private var selectedSource: String?
    @State private var searchText = ""
    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var newSourceName = ""
    @State private var filterStatus: ReviewStatus? = nil
    @State private var isContinuousPlayback = false
    @State private var currentPlayingIndex = 0
    @State private var playbackSpeed: Float = 1.0
    
    var filteredSources: [String] {
        let sources = Array(Set(segments.map { $0.sourceId })).sorted()
        if searchText.isEmpty { return sources }
        return sources.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredSegments: [Segment] {
        var filtered = segments
        
        // Apply text search
        if !searchText.isEmpty {
            filtered = filtered.filter { segment in
                segment.text.localizedCaseInsensitiveContains(searchText) ||
                segment.sourceId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply source filter
        if let source = selectedSource {
            filtered = filtered.filter { $0.sourceId == source }
        }
        
        // Apply status filter
        if let status = filterStatus {
            filtered = filtered.filter { segment in
                let segmentStatus = getReviewStatus(for: segment)
                return segmentStatus == status
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            // Sidebar with sources
            List(selection: $selectedSource) {
                ForEach(filteredSources, id: \.self) { source in
                    NavigationLink(
                        destination: sourceContentView(for: source)
                    ) {
                        SourceRow(source: source, segments: segments)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            .searchable(text: $searchText, prompt: "Search sources and segments")
            
            // Main content area
            VStack {
                // Filter toolbar
                HStack {
                    Menu {
                        Button("All Cards", action: { filterStatus = nil })
                        Button("New Cards", action: { filterStatus = .new })
                        Button("Due Today", action: { filterStatus = .due })
                        Divider()
                        Button("Next Review Date", action: { 
                            filterStatus = .scheduled(date: Date())
                        })
                    } label: {
                        Label(filterStatus?.text ?? "All Cards", 
                              systemImage: "calendar")
                    }
                    
                    Spacer()
                    
                    // Playback speed control (only visible during continuous playback)
                    if isContinuousPlayback {
                        Menu {
                            ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                                Button(action: {
                                    playbackSpeed = Float(speed)
                                    audioPlayer.setPlaybackRate(Float(speed))
                                }) {
                                    HStack {
                                        Text("\(String(format: "%.2fx", speed))")
                                        if playbackSpeed == Float(speed) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text("\(String(format: "%.2fx", playbackSpeed))")
                        }
                    }
                    
                    // Continuous playback toggle
                    Button(action: {
                        toggleContinuousPlayback()
                    }) {
                        Image(systemName: isContinuousPlayback ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundColor(isContinuousPlayback ? .blue : .primary)
                    }
                    .help(isContinuousPlayback ? "Stop Continuous Playback" : "Start Continuous Playback")
                }
                .padding()
                
                if filteredSegments.isEmpty {
                    Text("No segments match your search")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredSegments) { segment in
                            SegmentRow(
                                segment: segment,
                                audioPlayer: audioPlayer,
                                reviewState: reviewState,
                                isPlaying: audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString,
                                isCurrentSegment: isContinuousPlayback && filteredSegments[currentPlayingIndex].id == segment.id,
                                isSelected: false
                            )
                        }
                    }
                }
            }
        }
        .alert("Rename Source", isPresented: $showingRenameAlert) {
            TextField("New name", text: $newSourceName)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if let oldName = selectedSource {
                    renameSource(from: oldName, to: newSourceName)
                }
            }
        }
        .alert("Delete Source", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let sourceId = selectedSource {
                    deleteSource(sourceId)
                }
            }
        } message: {
            Text("Are you sure you want to delete this source? This action cannot be undone.")
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func toggleContinuousPlayback() {
        if isContinuousPlayback {
            stopPlayback()
        } else {
            startContinuousPlayback()
        }
    }
    
    private func startContinuousPlayback() {
        guard !filteredSegments.isEmpty else { return }
        currentPlayingIndex = 0
        isContinuousPlayback = true
        playCurrentSegment()
    }
    
    private func stopPlayback() {
        isContinuousPlayback = false
        audioPlayer.stop()
    }
    
    private func playCurrentSegment() {
        guard currentPlayingIndex < filteredSegments.count else {
            stopPlayback()
            return
        }
        
        let segment = filteredSegments[currentPlayingIndex]
        if let audioURL = audioFiles[segment.sourceId] {
            audioPlayer.load(url: audioURL)
            audioPlayer.setPlaybackRate(playbackSpeed)
            audioPlayer.playSegment(segment: segment) {
                // When segment finishes, play next
                if isContinuousPlayback {
                    currentPlayingIndex += 1
                    if currentPlayingIndex < filteredSegments.count {
                        playCurrentSegment()
                    } else {
                        stopPlayback()
                    }
                }
            }
        }
    }
    
    private func sourceContentView(for source: String) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(segments.filter { $0.sourceId == source }) { segment in
                    SegmentRow(
                        segment: segment,
                        audioPlayer: audioPlayer,
                        reviewState: reviewState,
                        isPlaying: audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString,
                        isCurrentSegment: isContinuousPlayback && filteredSegments[currentPlayingIndex].id == segment.id,
                        isSelected: false
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(source)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Rename") {
                        newSourceName = source
                        showingRenameAlert = true
                    }
                    
                    Menu("Manage SRS") {
                        Button("Hide All from SRS") {
                            hideFromSRS(sourceId: source, hide: true)
                        }
                        Button("Show All in SRS") {
                            hideFromSRS(sourceId: source, hide: false)
                        }
                    }
                    
                    Button("Delete", role: .destructive) {
                        selectedSource = source
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func getReviewStatus(for segment: Segment) -> ReviewStatus {
        let segmentId = segment.id.uuidString
        if let card = reviewState.reviewCards[segmentId] {
            if card.dueDate <= Date() {
                return .due
            } else {
                return .scheduled(date: card.dueDate)
            }
        }
        return .new
    }
    
    private func hideFromSRS(sourceId: String, hide: Bool) {
        segments = segments.map { segment in
            var segment = segment
            if segment.sourceId == sourceId {
                segment.isHiddenFromSRS = hide
            }
            return segment
        }
        saveState()
    }
    
    private func renameSource(from oldName: String, to newName: String) {
        segments = segments.map { segment in
            var segment = segment
            if segment.sourceId == oldName {
                segment.sourceId = newName
            }
            return segment
        }
        
        if let audioURL = audioFiles[oldName] {
            audioFiles[newName] = audioURL
            audioFiles.removeValue(forKey: oldName)
        }
        
        saveState()
    }
    
    private func deleteSource(_ sourceId: String) {
        segments.removeAll { $0.sourceId == sourceId }
        audioFiles.removeValue(forKey: sourceId)
        selectedSource = nil
        saveState()
    }
    
    private func saveState() {
        if let segmentsData = try? JSONEncoder().encode(segments) {
            UserDefaults.standard.set(segmentsData, forKey: "segments")
            let audioFilePaths = audioFiles.mapValues { $0.path }
            UserDefaults.standard.set(audioFilePaths, forKey: "audioFiles")
            UserDefaults.standard.synchronize()
        }
        NotificationCenter.default.post(name: .segmentsUpdated, object: nil)
    }
}

struct SourceRow: View {
    let source: String
    let segments: [Segment]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source)
            
            HStack(spacing: 8) {
                Text("\(segments.filter { $0.sourceId == source }.count) segments")
                    .foregroundColor(.secondary)
                
                let hiddenCount = segments.filter { $0.sourceId == source && $0.isHiddenFromSRS }.count
                if hiddenCount > 0 {
                    Text("(\(hiddenCount) hidden)")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
        }
    }
}
