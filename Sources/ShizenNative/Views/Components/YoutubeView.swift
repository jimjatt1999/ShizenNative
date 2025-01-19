import SwiftUI

struct YoutubeView: View {
    @StateObject private var youtubeManager = YoutubeManager()
    @State private var urlString = ""
    @State private var isProcessing = false
    var onDownloadComplete: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("Paste YouTube URL", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            
            if youtubeManager.isDownloading {
                VStack(spacing: 10) {
                    ProgressView(value: youtubeManager.downloadProgress, total: 100)
                        .progressViewStyle(.linear)
                    Text("\(Int(youtubeManager.downloadProgress))%")
                        .font(.caption)
                }
                .padding()
            }
            
            Button(action: downloadVideo) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Download Audio")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(urlString.isEmpty || youtubeManager.isDownloading)
        }
        .alert("Download Error", isPresented: .constant(youtubeManager.error != nil)) {
            Button("OK", role: .cancel) {
                youtubeManager.error = nil
            }
        } message: {
            Text(youtubeManager.error ?? "")
        }
    }
    
    private func downloadVideo() {
        Task {
            do {
                let url = try await youtubeManager.downloadAudio(from: urlString)
                await MainActor.run {
                    onDownloadComplete(url)
                }
            } catch {
                print("Download error: \(error)")
            }
        }
    }
}
