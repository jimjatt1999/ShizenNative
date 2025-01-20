import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var transcriptionManager = TranscriptionManager()
    @StateObject private var settings = AppSettings()
    @State private var showingFilePicker = false
    @State private var segments: [Segment] = []
    @State private var selectedView: String? = "Review"
    @State private var isTranscribing = false
    @State private var transcriptionProgress = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingFocusModeSelection = false
    @State private var audioFiles: [String: URL] = [:]
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(selection: $selectedView) {
                NavigationLink(
                    destination: ReviewView(
                        segments: segments,
                        audioPlayer: audioPlayer,
                        settings: settings,
                        audioFiles: audioFiles
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
                        onFileSelected: handleFileUpload
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
                        audioFiles: $audioFiles
                    ),
                    tag: "Manage",
                    selection: $selectedView
                ) {
                    Label("Manage", systemImage: "folder")
                        .foregroundColor(.white)
                }
                
                NavigationLink(
                    destination: StatsView(),
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
            
            // Main content
            Group {
                if selectedView == "Upload" {
                    UploadView(
                        showingFilePicker: $showingFilePicker,
                        isTranscribing: $isTranscribing,
                        transcriptionProgress: $transcriptionProgress,
                        onFileSelected: handleFileUpload
                    )
                } else if selectedView == "Review" {
                    ReviewView(
                        segments: segments,
                        audioPlayer: audioPlayer,
                        settings: settings,
                        audioFiles: audioFiles
                    )
                } else if selectedView == "Manage" {
                    ManageView(
                        audioPlayer: audioPlayer,
                        segments: $segments,
                        audioFiles: $audioFiles
                    )
                } else if selectedView == "Stats" {
                    StatsView()
                } else if selectedView == "Settings" {
                    SettingsView()
                }
            }
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
        .sheet(isPresented: $showingFocusModeSelection) {
            FocusModeSourceSelection(
                segments: segments,
                audioPlayer: audioPlayer,
                settings: settings,
                audioFiles: audioFiles
            )
        }
        .preferredColorScheme(settings.settings.appearanceMode == .system ? nil :
                                (settings.settings.appearanceMode == .dark ? .dark : .light))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
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
        Task {
            do {
                isTranscribing = true
                transcriptionProgress = "Processing audio..."
                
                // Store the audio file URL
                let sourceId = url.lastPathComponent
                audioFiles[sourceId] = url
                
                // Load audio
                audioPlayer.load(url: url)
                
                // Then transcribe
                transcriptionProgress = "Transcribing..."
                let newSegments = try await transcriptionManager.transcribe(audioPath: url.path)
                
                await MainActor.run {
                    print("Received \(newSegments.count) segments")
                    
                    // Process for duplicates
                    let processedSegments = newSegments.map { segment in
                        var segment = segment
                        segment.sourceId = sourceId
                        segment.isDuplicate = DuplicateManager.isDuplicate(segment, in: segments)
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
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        Task {
            do {
                let files = try result.get()
                guard let url = files.first else { return }
                handleFileUpload(url)
            } catch {
                print("Error during file import: \(error)")
                errorMessage = error.localizedDescription
                showError = true
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
}
