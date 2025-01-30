import SwiftUI

struct UploadView: View {
   @Binding var showingFilePicker: Bool
   @Binding var isTranscribing: Bool
   @Binding var transcriptionProgress: String
   var onFileSelected: (URL, Double, String) -> Void
   
   @State private var selectedSource: AudioSourceType = .fileUpload
   @State private var isDragging = false
   @State private var showingAudioEditor = false
   @State private var audioToEdit: URL?
   @State private var showError = false
   @State private var errorMessage = ""
   
   private var sourceSelector: some View {
       Picker("Source", selection: $selectedSource) {
           ForEach(AudioSourceType.allCases, id: \.self) { source in
               Label(source.rawValue, systemImage: source.icon)
                   .tag(source)
           }
       }
       .pickerStyle(.segmented)
       .padding()
   }
   
   private var contentView: some View {
       Group {
           if isTranscribing {
               TranscribingView(progress: transcriptionProgress)
                   .frame(maxWidth: .infinity, maxHeight: .infinity)
           } else {
               GeometryReader { geometry in
                   ScrollView {
                       VStack(spacing: 0) {
                           ZStack {
                               Color(.windowBackgroundColor)
                                   .frame(height: geometry.size.height)
                               
                               sourceContent
                           }
                       }
                       .frame(minHeight: geometry.size.height)
                   }
               }
           }
       }
   }
   
   private var sourceContent: some View {
       Group {
           switch selectedSource {
           case .fileUpload:
               VStack(spacing: 20) {
                   Image(systemName: "doc.badge.plus")
                       .resizable()
                       .scaledToFit()
                       .frame(width: 60)
                       .foregroundColor(.blue)
                   
                   Text("Drag and drop audio files here")
                       .font(.headline)
                       .foregroundColor(.secondary)
                   
                   Text("or")
                       .font(.subheadline)
                       .foregroundColor(.secondary)
                   
                   Button(action: {
                       showingFilePicker = true
                   }) {
                       Text("Choose File")
                           .font(.headline)
                           .padding(.horizontal, 20)
                           .padding(.vertical, 10)
                           .background(Color.blue)
                           .foregroundColor(.white)
                           .cornerRadius(8)
                   }
                   .buttonStyle(PlainButtonStyle())
                   
                   Text("Supported: MP3, WAV, M4A")
                       .font(.caption)
                       .foregroundColor(.secondary)
               }
               .padding(40)
               .background(
                   RoundedRectangle(cornerRadius: 12)
                       .stroke(
                           isDragging ? Color.blue : Color.gray.opacity(0.3),
                           style: StrokeStyle(lineWidth: 2, dash: [6])
                       )
               )
               .padding(.horizontal, 40)
               .onDrop(
                   of: [.audio],
                   delegate: AudioDropDelegate(isDragging: $isDragging, showingFilePicker: $showingFilePicker)
               )
           case .recording:
               RecordingView { url in
                   print("Recording completed: \(url)")
                   audioToEdit = url
                   showingAudioEditor = true
               }
           case .podcast:
               PodcastView { url in
                   print("Podcast downloaded: \(url)")
                   audioToEdit = url
                   showingAudioEditor = true
               }
           case .youtube:
               YouTubeView { url in
                   print("YouTube audio downloaded: \(url)")
                   audioToEdit = url
                   showingAudioEditor = true
               }
           }
       }
       .frame(maxWidth: .infinity, maxHeight: .infinity)
   }
   
   private var audioEditor: some View {
       Group {
           if let audioURL = audioToEdit {
               AudioEditorView(
                   audioURL: audioURL,
                   initialSegmentDuration: 20.0,
                   onSave: { editedURL, segmentDuration, sourceName in
                       print("Audio edited and saved: \(editedURL)")
                       showingAudioEditor = false
                       onFileSelected(editedURL, segmentDuration, sourceName)
                   },
                   onCancel: {
                       print("Audio editing cancelled")
                       showingAudioEditor = false
                       audioToEdit = nil
                   }
               )
               .onAppear {
                   print("Showing audio editor for: \(audioURL)")
               }
           } else {
               Text("No audio file selected")
                   .foregroundColor(.red)
                   .onAppear {
                       print("audioToEdit is nil")
                   }
           }
       }
   }
   
   var body: some View {
       VStack(spacing: 0) {
           sourceSelector
           contentView
       }
       .frame(maxWidth: .infinity, maxHeight: .infinity)
       .sheet(isPresented: $showingAudioEditor) {
           audioEditor
       }
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
       .onChange(of: showingAudioEditor) { isShowing in
           if !isShowing {
               audioToEdit = nil
           }
       }
   }
   
   private func handleFileImport(_ result: Result<[URL], Error>) {
       do {
           let files = try result.get()
           guard let url = files.first else { return }
           print("File selected: \(url)")
           audioToEdit = url
           showingAudioEditor = true
       } catch {
           print("Error importing file: \(error)")
           errorMessage = error.localizedDescription
           showError = true
       }
   }
}

struct AudioDropDelegate: DropDelegate {
    @Binding var isDragging: Bool
    @Binding var showingFilePicker: Bool
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.audio])
    }
    
    func dropEntered(info: DropInfo) {
        isDragging = true
    }
    
    func dropExited(info: DropInfo) {
        isDragging = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isDragging = false
        showingFilePicker = true
        return true
    }
}

#Preview {
   UploadView(
       showingFilePicker: .constant(false),
       isTranscribing: .constant(false),
       transcriptionProgress: .constant(""),
       onFileSelected: { _, _, _ in }
   )
}
