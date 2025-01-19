import SwiftUI

struct PodcastView: View {
    @StateObject private var podcastManager = PodcastManager()
    @State private var searchText = ""
    @State private var selectedEpisode: PodcastEpisode?
    @State private var isDownloading = false
    var onEpisodeDownloaded: (URL) -> Void
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search Japanese podcasts...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                    Task {
                        await podcastManager.searchPodcasts(searchText)
                    }
                }
            }
            .padding()
            
            // Results list
            List(podcastManager.searchResults) { episode in
                PodcastEpisodeRow(episode: episode) {
                    selectedEpisode = episode
                    downloadEpisode(episode)
                }
            }
            
            if isDownloading {
                ProgressView()
                    .padding()
            }
        }
        .alert("Download Error", isPresented: .constant(podcastManager.error != nil)) {
            Button("OK", role: .cancel) {
                podcastManager.error = nil
            }
        } message: {
            Text(podcastManager.error ?? "")
        }
    }
    
    private func downloadEpisode(_ episode: PodcastEpisode) {
        isDownloading = true
        Task {
            do {
                let url = try await podcastManager.downloadEpisode(episode)
                await MainActor.run {
                    isDownloading = false
                    onEpisodeDownloaded(url)
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    podcastManager.error = error.localizedDescription
                }
            }
        }
    }
}

struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    let onDownload: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(episode.title)
                .font(.headline)
            
            Text(episode.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(formatDuration(episode.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}
