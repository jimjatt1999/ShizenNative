import SwiftUI

struct UploadView: View {
    @Binding var showingFilePicker: Bool
    @Binding var isTranscribing: Bool
    @Binding var transcriptionProgress: String
    @State private var selectedSource: AudioSourceType = .fileUpload
    @State private var isDragging = false
    
    var onFileSelected: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            if isTranscribing {
                TranscribingView(progress: transcriptionProgress)
            } else {
                // Source selector
                Picker("Source", selection: $selectedSource) {
                    Image(systemName: "doc").tag(AudioSourceType.fileUpload)
                    Image(systemName: "mic").tag(AudioSourceType.recording)
                    Image(systemName: "radio").tag(AudioSourceType.podcast)
                    Image(systemName: "play.tv").tag(AudioSourceType.youtube)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content view based on selected source
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
