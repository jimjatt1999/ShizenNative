import SwiftUI

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var settings = AppSettings()
    @StateObject private var reviewState: ReviewState
    @State private var showingFilePicker = false
    @State private var segments: [Segment] = []
    @State private var selectedView: String? = "Review"
    @State private var isTranscribing = false
    @State private var transcriptionProgress = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingFocusModeSelection = false
    @State private var audioFiles: [String: URL] = [:]
    @State private var showingAudioEditor = false
    @State private var audioToEdit: URL?
    
    init() {
        let appSettings = AppSettings()
        _settings = StateObject(wrappedValue: appSettings)
        _reviewState = StateObject(wrappedValue: ReviewState(settings: appSettings))
    }
    
    var sidebarContent: some View {
        List(selection: $selectedView) {
            NavigationLink(
                destination: ReviewView(
                    segments: segments,
                    audioPlayer: audioPlayer,
                    settings: settings,
                    audioFiles: audioFiles,
                    reviewState: reviewState
                ),
                tag: "Review",
                selection: $selectedView
            ) {
                Label("Review", systemImage: "clock")
                    .foregroundColor(.white)
            }
            
            NavigationLink(
                destination: UploadView(
                    showingFilePicker: $showingFilePicker,
                    isTranscribing: $isTranscribing,
                    transcriptionProgress: $transcriptionProgress,
                    onFileSelected: { url, segmentDuration in
                        handleEditedAudio(url, segmentDuration: segmentDuration)
                    }
                ),
                tag: "Upload",
                selection: $selectedView
            ) {
                Label("Upload", systemImage: "arrow.up.circle")
                    .foregroundColor(.white)
            }
            
            NavigationLink(
                destination: ManageView(
                    audioPlayer: audioPlayer,
                    segments: $segments,
                    audioFiles: $audioFiles,
                    reviewState: reviewState
                ),
                tag: "Manage",
                selection: $selectedView
            ) {
                Label("Manage", systemImage: "folder")
                    .foregroundColor(.white)
            }
            
            NavigationLink(
                destination: StatsView(reviewState: reviewState),
                tag: "Stats",
                selection: $selectedView
            ) {
                Label("Stats", systemImage: "chart.bar")
                    .foregroundColor(.white)
            }
            
            NavigationLink(
                destination: SettingsView(),
                tag: "Settings",
                selection: $selectedView
            ) {
                Label("Settings", systemImage: "gear")
                    .foregroundColor(.white)
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200, maxWidth: 300)
        .background(Color(NSColor.darkGray))
    }
    
    var mainContent: some View {
        Group {
            if selectedView == "Upload" {
                UploadView(
                    showingFilePicker: $showingFilePicker,
                    isTranscribing: $isTranscribing,
                    transcriptionProgress: $transcriptionProgress,
                    onFileSelected: { url, segmentDuration in
                        handleEditedAudio(url, segmentDuration: segmentDuration)
                    }
                )
            } else if selectedView == "Review" {
                ReviewView(
                    segments: segments,
                    audioPlayer: audioPlayer,
                    settings: settings,
                    audioFiles: audioFiles,
                    reviewState: reviewState
                )
            } else if selectedView == "Manage" {
                ManageView(
                    audioPlayer: audioPlayer,
                    segments: $segments,
                    audioFiles: $audioFiles,
                    reviewState: reviewState
                )
            } else if selectedView == "Stats" {
                StatsView(reviewState: reviewState)
            } else if selectedView == "Settings" {
                SettingsView()
            }
        }
    }
    
    var body: some View {
        NavigationView {
            sidebarContent
            mainContent
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("Shizen")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showingFocusModeSelection = true
                }) {
                    HStack {
                        Image(systemName: "target")
                        Text("Focus Mode")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAudioEditor) {
            if let audioURL = audioToEdit {
                AudioEditorView(
                    audioURL: audioURL,
                    initialSegmentDuration: 20.0,
                    onSave: { url, segmentDuration in
                        showingAudioEditor = false
                        handleEditedAudio(url, segmentDuration: segmentDuration)
                    },
                    onCancel: {
                        showingAudioEditor = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingFocusModeSelection) {
            FocusModeSourceSelection(
                segments: segments,
                audioPlayer: audioPlayer,
                settings: settings,
                audioFiles: audioFiles,
                reviewState: reviewState
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadSavedState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exitFocusMode)) { _ in
            showingFocusModeSelection = false
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    private func handleFileUpload(_ url: URL) {
        audioToEdit = url
        showingAudioEditor = true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let files = try result.get()
            guard let url = files.first else { return }
            audioToEdit = url
            showingAudioEditor = true
        } catch {
            print("Error during file import: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleEditedAudio(_ url: URL, segmentDuration: Double) {
        Task {
            do {
                isTranscribing = true
                transcriptionProgress = "Processing audio..."
                
                let sourceId = url.lastPathComponent
                audioFiles[sourceId] = url
                
                audioPlayer.load(url: url)
                
                transcriptionProgress = "Transcribing..."
                let newSegments = try await transcriptionManager.transcribe(
                    audioPath: url.path,
                    segmentDuration: segmentDuration
                )
                
                await MainActor.run {
                    print("Received \(newSegments.count) segments")
                    
                    let processedSegments = newSegments.map { segment in
                        var segment = segment
                        segment.sourceId = sourceId
                        return segment
                    }
                    
                    segments.append(contentsOf: processedSegments)
                    saveState(segments: segments, audioFiles: audioFiles)
                    
                    isTranscribing = false
                    selectedView = "Review"
                }
            } catch {
                print("Error during transcription: \(error)")
                await MainActor.run {
                    isTranscribing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func loadSavedState() {
        if let segmentData = UserDefaults.standard.data(forKey: "segments"),
           let loadedSegments = try? JSONDecoder().decode([Segment].self, from: segmentData) {
            segments = loadedSegments
        }
        
        if let savedAudioPaths = UserDefaults.standard.dictionary(forKey: "audioFiles") as? [String: String] {
            audioFiles = savedAudioPaths.compactMapValues { URL(fileURLWithPath: $0) }
            if let firstAudioURL = audioFiles.values.first {
                audioPlayer.load(url: firstAudioURL)
            }
        }
    }
    
    private func saveState(segments: [Segment], audioFiles: [String: URL]) {
        if let segmentsData = try? JSONEncoder().encode(segments) {
            UserDefaults.standard.set(segmentsData, forKey: "segments")
            let audioFilePaths = audioFiles.mapValues { $0.path }
            UserDefaults.standard.set(audioFilePaths, forKey: "audioFiles")
            UserDefaults.standard.synchronize()
        }
    }
}
