import SwiftUI

struct UploadView: View {
    @Binding var showingFilePicker: Bool
    @Binding var isTranscribing: Bool
    @Binding var transcriptionProgress: String
    @State private var selectedSource: AudioSourceType = .fileUpload
    @State private var isDragging = false
    
    var onFileSelected: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Source selector
            Picker("Source", selection: $selectedSource) {
                Label("File", systemImage: "doc").tag(AudioSourceType.fileUpload)
                Label("Record", systemImage: "mic").tag(AudioSourceType.recording)
                Label("Podcast", systemImage: "radio").tag(AudioSourceType.podcast)
                Label("YouTube", systemImage: "play.tv").tag(AudioSourceType.youtube)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content view
            if isTranscribing {
                TranscribingView(progress: transcriptionProgress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Content container with fixed height
                            ZStack {
                                // Background
                                Color(.windowBackgroundColor)
                                    .frame(height: geometry.size.height)
                                
                                // Source-specific content
                                Group {
                                    switch selectedSource {
                                    case .fileUpload:
                                        UploadPromptView(
                                            showingFilePicker: $showingFilePicker,
                                            isDragging: $isDragging
                                        )
                                    case .recording:
                                        RecordingView { url in
                                            onFileSelected(url)
                                        }
                                    case .podcast:
                                        PodcastView { url in
                                            onFileSelected(url)
                                        }
                                    case .youtube:
                                        YoutubeView { url in
                                            onFileSelected(url)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper Views
struct SourceButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContentContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
