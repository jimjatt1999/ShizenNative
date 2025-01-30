import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var settings = AppSettings()
    @StateObject private var reviewState: ReviewState
    @State private var showingFilePicker = false
    @State private var segments: [Segment] = []
    @State private var selectedView: String? = nil
    @State private var isTranscribing = false
    @State private var transcriptionProgress = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingFocusModeSelection = false
    @State private var showingAudioEditor = false
    @State private var audioToEdit: URL?
    @State private var audioFiles: [String: URL] = [:]
    @State private var selectedSourceForFocusMode: String?
    
    init() {
        let appSettings = AppSettings()
        _settings = StateObject(wrappedValue: appSettings)
        _reviewState = StateObject(wrappedValue: ReviewState(settings: appSettings))
    }
    
    var sidebarContent: some View {
        List(selection: $selectedView) {
            NavigationLink(
                destination: WelcomeView(
                    segments: segments,
                    reviewState: reviewState,
                    selectedView: $selectedView
                ),
                tag: "Home",
                selection: $selectedView
            ) {
                Label("Home", systemImage: "house")
                    .foregroundColor(.white)
            }
            
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
                    onFileSelected: handleFileSelected
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
            if let selectedView = selectedView {
                switch selectedView {
                case "Home":
                    WelcomeView(
                        segments: segments,
                        reviewState: reviewState,
                        selectedView: $selectedView
                    )
                case "Review":
                    ReviewView(
                        segments: segments,
                        audioPlayer: audioPlayer,
                        settings: settings,
                        audioFiles: audioFiles,
                        reviewState: reviewState
                    )
                case "Upload":
                    UploadView(
                        showingFilePicker: $showingFilePicker,
                        isTranscribing: $isTranscribing,
                        transcriptionProgress: $transcriptionProgress,
                        onFileSelected: handleFileSelected
                    )
                case "Manage":
                    ManageView(
                        audioPlayer: audioPlayer,
                        segments: $segments,
                        audioFiles: $audioFiles,
                        reviewState: reviewState
                    )
                case "Stats":
                    StatsView(reviewState: reviewState)
                case "Settings":
                    SettingsView()
                default:
                    WelcomeView(
                        segments: segments,
                        reviewState: reviewState,
                        selectedView: $selectedView
                    )
                }
            } else {
                WelcomeView(
                    segments: segments,
                    reviewState: reviewState,
                    selectedView: $selectedView
                )
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
            ToolbarItemGroup(placement: .navigation) {
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
            if let url = audioToEdit {
                AudioEditorView(
                    audioURL: url,
                    initialSegmentDuration: 20.0,
                    onSave: handleFileSelected,
                    onCancel: {
                        showingAudioEditor = false
                        audioToEdit = nil
                        isTranscribing = false
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
    
    private func handleFileSelected(_ url: URL, segmentDuration: TimeInterval, sourceName: String) {
        Task {
            do {
                let sourceId = sourceName
                audioFiles[sourceId] = url
                isTranscribing = true
                
                let funnyMessages = [
                    "Transcribing... hope you brought snacks!",
                    "Converting speech to text... in Japanese time",
                    "Working harder than a karaoke machine...",
                    "Channeling my inner Japanese master...",
                    "Taking a quick matcha break...",
                    "Consulting the ancient scrolls of audio...",
                    "Doing my best Japanese robot impression..."
                ]
                
                // Start showing progress messages
                for message in funnyMessages {
                    if !isTranscribing { break }
                    transcriptionProgress = message
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
                // Actual transcription
                let newSegments = try await transcriptionManager.transcribe(
                    audioPath: url.path,
                    segmentDuration: segmentDuration
                )
                
                // Process segments
                let processedSegments = newSegments.map { segment in
                    var segment = segment
                    segment.sourceId = sourceId
                    return segment
                }
                
                DispatchQueue.main.async {
                    segments.append(contentsOf: processedSegments)
                    saveState(segments: segments, audioFiles: audioFiles)
                    showingAudioEditor = false
                    showingFilePicker = false
                    isTranscribing = false
                    audioToEdit = nil
                    selectedView = "Review" // Automatically switch to Review view
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                    showingAudioEditor = false
                    showingFilePicker = false
                    isTranscribing = false
                    audioToEdit = nil
                }
            }
        }
    }
    
    private func showFocusMode(for sourceId: String) {
        selectedSourceForFocusMode = sourceId
        showingFocusModeSelection = true
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
