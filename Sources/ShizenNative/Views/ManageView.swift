import SwiftUI
import AVFoundation

struct ManageView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var segments: [Segment]
    @Binding var audioFiles: [String: URL]
    @StateObject var reviewState: ReviewState
    @StateObject private var settings = AppSettings()  // Add this line
    @State private var selectedSource: String?
    @State private var searchText = ""
    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var newSourceName = ""
    @State private var filterStatus: ReviewStatus? = nil
    @State private var isContinuousPlayback = false
    @State private var currentPlayingIndex = 0
    @State private var playbackSpeed: Float = 1.0
    @State private var selectedSegments: Set<UUID> = []
    @State private var currentSourceId: String?
    
    var filteredSources: [String] {
        let sources = Array(Set(segments.map { $0.sourceId })).sorted()
        if searchText.isEmpty { return sources }
        return sources.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var currentSegments: [Segment] {
        var filtered = segments
        
        if !searchText.isEmpty {
            filtered = filtered.filter { segment in
                segment.text.localizedCaseInsensitiveContains(searchText) ||
                segment.sourceId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let source = selectedSource {
            filtered = filtered.filter { $0.sourceId == source }
        }
        
        if let status = filterStatus {
            filtered = filtered.filter { segment in
                let segmentStatus = getReviewStatus(for: segment)
                return segmentStatus == status
            }
        }
        
        return filtered.sorted { s1, s2 in
            if s1.sourceId == s2.sourceId {
                return s1.start < s2.start
            }
            return s1.sourceId < s2.sourceId
        }
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack {
                List(selection: $selectedSource) {
                    Text("All Sources")
                        .tag(nil as String?)
                    
                    Section("Sources") {
                        ForEach(filteredSources, id: \.self) { source in
                            SourceRow(source: source, segments: segments)
                                .tag(source as String?)
                        }
                    }
                }
                .listStyle(SidebarListStyle())
            }
            .frame(minWidth: 200, maxWidth: 300)
            .searchable(text: $searchText, prompt: "Search sources and segments")
            
            // Main content
            VStack(spacing: 0) {
                // Unified toolbar
                toolbar
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Content
                if currentSegments.isEmpty {
                    emptyStateView
                } else {
                    segmentsGrid
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
                if let source = selectedSource {
                    deleteSource(source)
                }
            }
        } message: {
            Text("Are you sure you want to delete this source? This action cannot be undone.")
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    private var toolbar: some View {
        HStack {
            // Filter menu
            Menu {
                Button("All Cards", action: { filterStatus = nil })
                Button("New Cards", action: { filterStatus = .new })
                Button("Due Today", action: { filterStatus = .due })
                Divider()
                Button("Next Review Date", action: { 
                    filterStatus = .scheduled(date: Date())
                })
            } label: {
                Label(filterStatus?.text ?? "All Cards", systemImage: "calendar")
            }
            
            Spacer()
            
            // Source actions (if source selected)
            if let source = selectedSource {
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
                        showingDeleteAlert = true
                    }
                } label: {
                    Label("Source Actions", systemImage: "ellipsis.circle")
                }
            }
            
            // Bulk actions (if segments selected)
            if !selectedSegments.isEmpty {
                Menu {
                    Button("Hide from SRS") {
                        hideSelectedFromSRS(hide: true)
                    }
                    Button("Show in SRS") {
                        hideSelectedFromSRS(hide: false)
                    }
                    Button("Delete Selected", role: .destructive) {
                        deleteSelectedSegments()
                    }
                } label: {
                    Label("Bulk Actions", systemImage: "ellipsis.circle")
                }
            }
            
            // Playback controls
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
            
            Button(action: {
                toggleContinuousPlayback()
            }) {
                Image(systemName: isContinuousPlayback ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(isContinuousPlayback ? .blue : .primary)
            }
            .help(isContinuousPlayback ? "Stop Continuous Playback" : "Start Continuous Playback")
        }
    }
    
    private var emptyStateView: some View {
        Text("No segments match your search")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var segmentsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 300, maximum: .infinity))],
                spacing: 16
            ) {
                ForEach(currentSegments) { segment in
                    if let audioURL = audioFiles[segment.sourceId] {
                        ReviewCardView(
                            segment: segment,
                            audioPlayer: audioPlayer,
                            settings: settings,
                            audioURL: audioURL,
                            onResponse: { response in
                                handleResponse(for: segment, response: response)
                            },
                            isCompact: true,
                            showControls: true,
                            isSelected: selectedSegments.contains(segment.id),
                            onSelect: {
                                toggleSelection(for: segment)
                            }
                        )
                        .contextMenu {
                            Button(action: {
                                var updatedSegment = segment
                                updatedSegment.isHiddenFromSRS.toggle()
                                updateSegment(updatedSegment)
                            }) {
                                Label(    
                                    segment.isHiddenFromSRS ? "Show in SRS" : "Hide from SRS",
                                    systemImage: segment.isHiddenFromSRS ? "eye" : "eye.slash"
                                )
                            }
                            
                            Button(role: .destructive, action: {
                                deleteSegments([segment])
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func toggleSelection(for segment: Segment) {
        if selectedSegments.contains(segment.id) {
            selectedSegments.remove(segment.id)
        } else {
            selectedSegments.insert(segment.id)
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
        guard !currentSegments.isEmpty else { return }
        currentPlayingIndex = 0
        isContinuousPlayback = true
        
        let firstSegment = currentSegments[currentPlayingIndex]
        prepareAudioForSegment(firstSegment)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            playCurrentSegment()
        }
    }
    
    private func prepareAudioForSegment(_ segment: Segment) {
        if currentSourceId != segment.sourceId {
            if let audioURL = audioFiles[segment.sourceId] {
                audioPlayer.stop()
                DispatchQueue.main.async {
                    audioPlayer.load(url: audioURL)
                    currentSourceId = segment.sourceId
                }
            }
        }
    }
    
    private func playCurrentSegment() {
        guard currentPlayingIndex < currentSegments.count else {
            stopPlayback()
            return
        }
        
        let segment = currentSegments[currentPlayingIndex]
        prepareAudioForSegment(segment)
        
        audioPlayer.setPlaybackRate(playbackSpeed)
        audioPlayer.playSegment(segment: segment) {
            if isContinuousPlayback {
                currentPlayingIndex += 1
                if currentPlayingIndex < currentSegments.count {
                    playCurrentSegment()
                } else {
                    stopPlayback()
                }
            }
        }
    }
    
    private func handleResponse(for segment: Segment, response: String) {
        let segmentId = segment.id.uuidString
        var card = reviewState.reviewCards[segmentId] ?? ReviewScheduler.Card()
        
        let nextDue = ReviewScheduler.processReview(card: &card, response: response)
        
        if card.reviews == 0 && response != "again" {
            reviewState.todayNewCards += 1
        }
        
        card.reviews += 1
        card.dueDate = nextDue
        reviewState.reviewCards[segmentId] = card
        
        reviewState.save()
    }
    
    private func stopPlayback() {
        isContinuousPlayback = false
        audioPlayer.stop()
        currentSourceId = nil
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
    
    private func hideSelectedFromSRS(hide: Bool) {
        segments = segments.map { segment in
            var segment = segment
            if selectedSegments.contains(segment.id) {
                segment.isHiddenFromSRS = hide
            }
            return segment
        }
        saveState()
        selectedSegments.removeAll()
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
    
    private func updateSegment(_ updatedSegment: Segment) {
        if let index = segments.firstIndex(where: { $0.id == updatedSegment.id }) {
            segments[index] = updatedSegment
            saveState()
        }
    }
    
    private func deleteSelectedSegments() {
        deleteSegments(segments.filter { selectedSegments.contains($0.id) })
        selectedSegments.removeAll()
    }
    
    private func deleteSegments(_ segmentsToDelete: [Segment]) {
        segments.removeAll { segment in
            segmentsToDelete.contains { $0.id == segment.id }
        }
        saveState()
    }
    
    private func renameSource(from oldName: String, to newName: String) {
        guard !newName.isEmpty && oldName != newName else { return }
        
        // Update segments
        segments = segments.map { segment in
            var segment = segment
            if segment.sourceId == oldName {
                segment.sourceId = newName
            }
            return segment
        }
        
        // Update audio files
        if let audioURL = audioFiles[oldName] {
            audioFiles[newName] = audioURL
            audioFiles.removeValue(forKey: oldName)
        }
        
        // Update selected source
        selectedSource = newName
        
        // Update current source ID if it matches the old name
        if currentSourceId == oldName {
            currentSourceId = newName
        }
        
        // Stop playback to prevent any audio issues
        if isContinuousPlayback && currentSourceId == oldName {
            stopPlayback()
        }
        
        // Save state immediately
        saveState()
        
        // Force a UI refresh by triggering state changes
        DispatchQueue.main.async {
            let tempSelection = selectedSource
            selectedSource = nil
            selectedSource = tempSelection
        }
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
                        
                                    
                                    
