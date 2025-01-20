import SwiftUI
import AVFoundation

struct ManageView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var segments: [Segment]
    @Binding var audioFiles: [String: URL]
    @State private var selectedSource: String?
    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var newSourceName = ""
    
    var groupedSegments: [String: [Segment]] {
        Dictionary(grouping: segments) { $0.sourceId }
    }
    
    var body: some View {
        NavigationView {
            // Source list
            List(selection: $selectedSource) {
                ForEach(Array(groupedSegments.keys.sorted()), id: \.self) { sourceId in
                    NavigationLink(
                        destination: SourceContentView(
                            sourceId: sourceId,
                            segments: groupedSegments[sourceId] ?? [],
                            audioPlayer: audioPlayer,
                            audioFiles: audioFiles,
                            onUpdateSegments: { updatedSegments in
                                updateSegments(sourceId: sourceId, newSegments: updatedSegments)
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sourceId)
                            
                            HStack(spacing: 8) {
                                let sourceSegments = groupedSegments[sourceId] ?? []
                                let hiddenCount = sourceSegments.filter(\.isHiddenFromSRS).count
                                
                                Text("\(sourceSegments.count) segments")
                                    .foregroundColor(.secondary)
                                
                                if hiddenCount > 0 {
                                    Text("(\(hiddenCount) hidden)")
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.caption)
                        }
                        .contextMenu {
                            Button("Rename") {
                                newSourceName = sourceId
                                showingRenameAlert = true
                            }
                            
                            Menu("Manage SRS") {
                                Button("Hide All from SRS") {
                                    hideFromSRS(sourceId: sourceId, hide: true)
                                }
                                Button("Show All in SRS") {
                                    hideFromSRS(sourceId: sourceId, hide: false)
                                }
                            }
                            
                            Button("Delete", role: .destructive) {
                                selectedSource = sourceId
                                showingDeleteAlert = true
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if let sourceId = selectedSource {
                        Menu {
                            Button("Rename") {
                                newSourceName = sourceId
                                showingRenameAlert = true
                            }
                            
                            Menu("Manage SRS") {
                                Button("Hide All from SRS") {
                                    hideFromSRS(sourceId: sourceId, hide: true)
                                }
                                Button("Show All in SRS") {
                                    hideFromSRS(sourceId: sourceId, hide: false)
                                }
                            }
                            
                            Button("Delete", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            
            Text("Select a source")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
    
    private func updateSegments(sourceId: String, newSegments: [Segment]) {
        segments.removeAll { $0.sourceId == sourceId }
        segments.append(contentsOf: newSegments)
        saveSegments()
        NotificationCenter.default.post(name: .segmentsUpdated, object: nil)
    }
    
    private func hideFromSRS(sourceId: String, hide: Bool) {
        segments = segments.map { segment in
            var segment = segment
            if segment.sourceId == sourceId {
                segment.isHiddenFromSRS = hide
            }
            return segment
        }
        saveSegments()
        NotificationCenter.default.post(name: .segmentsUpdated, object: nil)
    }
    
    private func renameSource(from oldName: String, to newName: String) {
        // Update segments
        segments = segments.map { segment in
            var segment = segment
            if segment.sourceId == oldName {
                segment.sourceId = newName
            }
            return segment
        }
        
        // Update audioFiles dictionary
        if let audioURL = audioFiles[oldName] {
            audioFiles[newName] = audioURL
            audioFiles.removeValue(forKey: oldName)
        }
        
        saveSegments()
        saveAudioFiles()
        NotificationCenter.default.post(name: .segmentsUpdated, object: nil)
    }
    
    private func deleteSource(_ sourceId: String) {
        segments.removeAll { $0.sourceId == sourceId }
        audioFiles.removeValue(forKey: sourceId)
        selectedSource = nil
        saveSegments()
        saveAudioFiles()
        NotificationCenter.default.post(name: .segmentsUpdated, object: nil)
    }
    
    private func saveSegments() {
        if let data = try? JSONEncoder().encode(segments) {
            UserDefaults.standard.set(data, forKey: "segments")
            UserDefaults.standard.synchronize()
        }
    }
    
    private func saveAudioFiles() {
        let audioFilePaths = audioFiles.mapValues { $0.path }
        UserDefaults.standard.set(audioFilePaths, forKey: "audioFiles")
        UserDefaults.standard.synchronize()
    }
}

struct SourceContentView: View {
    let sourceId: String
    let segments: [Segment]
    let audioPlayer: AudioPlayer
    let audioFiles: [String: URL]
    let onUpdateSegments: ([Segment]) -> Void
    
    @State private var isSelectionMode = false
    @State private var selectedSegments = Set<UUID>()
    @State private var currentPlayingIndex = 0
    @State private var isPlaying = false
    @State private var isContinuousPlayback = false
    @State private var playbackSpeed: Float = 1.0
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack {
            List {
                ForEach(segments) { segment in
                    SegmentRow(
                        segment: segment,
                        audioPlayer: audioPlayer,
                        isPlaying: Binding(
                            get: { audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString },
                            set: { _ in }
                        ),
                        isCurrentSegment: segments[currentPlayingIndex].id == segment.id && isContinuousPlayback,
                        isSelected: selectedSegments.contains(segment.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelectionMode {
                            if selectedSegments.contains(segment.id) {
                                selectedSegments.remove(segment.id)
                            } else {
                                selectedSegments.insert(segment.id)
                            }
                        }
                    }
                }
            }
            
            if isContinuousPlayback {
                PlaybackControlsView(
                    audioPlayer: audioPlayer,
                    segments: segments,
                    currentIndex: $currentPlayingIndex,
                    isPlaying: $isPlaying,
                    playbackSpeed: $playbackSpeed
                )
            }
            
            HStack {
                Button(action: {
                    isContinuousPlayback.toggle()
                    if isContinuousPlayback {
                        currentPlayingIndex = 0
                        if let audioURL = audioFiles[sourceId] {
                            audioPlayer.load(url: audioURL)
                            audioPlayer.setPlaybackRate(playbackSpeed)
                            playCurrentSegment()
                        }
                    } else {
                        stopPlayback()
                    }
                }) {
                    HStack {
                        Image(systemName: isContinuousPlayback ? "pause.circle.fill" : "play.circle.fill")
                        Text("Continuous Playback")
                    }
                    .foregroundColor(isContinuousPlayback ? .blue : .primary)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if !isSelectionMode {
                    Button("Select") {
                        isSelectionMode = true
                    }
                } else {
                    HStack {
                        if !selectedSegments.isEmpty {
                            Menu {
                                Button("Hide from SRS") {
                                    updateSelectedSegments(hideFromSRS: true)
                                }
                                Button("Show in SRS") {
                                    updateSelectedSegments(hideFromSRS: false)
                                }
                                Button("Delete", role: .destructive) {
                                    showingActionSheet = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        
                        Button("Done") {
                            isSelectionMode = false
                            selectedSegments.removeAll()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(sourceId)
        .alert("Delete Segments", isPresented: $showingActionSheet) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedSegments()
            }
        } message: {
            Text("Are you sure you want to delete the selected segments? This action cannot be undone.")
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func playCurrentSegment() {
        guard currentPlayingIndex < segments.count else {
            stopPlayback()
            return
        }
        
        let segment = segments[currentPlayingIndex]
        audioPlayer.playSegment(segment: segment) {
            if isContinuousPlayback && currentPlayingIndex < segments.count - 1 {
                DispatchQueue.main.async {
                    currentPlayingIndex += 1
                    playCurrentSegment()
                }
            } else {
                isPlaying = false
                isContinuousPlayback = false
            }
        }
        isPlaying = true
    }
    
    private func stopPlayback() {
        audioPlayer.stop()
        isPlaying = false
        isContinuousPlayback = false
    }
    
    private func updateSelectedSegments(hideFromSRS: Bool) {
        var updatedSegments = segments
        for id in selectedSegments {
            if let index = updatedSegments.firstIndex(where: { $0.id == id }) {
                updatedSegments[index].isHiddenFromSRS = hideFromSRS
            }
        }
        onUpdateSegments(updatedSegments)
        selectedSegments.removeAll()
        isSelectionMode = false
    }
    
    private func deleteSelectedSegments() {
        var updatedSegments = segments
        updatedSegments.removeAll { selectedSegments.contains($0.id) }
        onUpdateSegments(updatedSegments)
        selectedSegments.removeAll()
        isSelectionMode = false
    }
}
