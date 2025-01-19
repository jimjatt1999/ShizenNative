import Foundation

class PodcastManager: ObservableObject {
    @Published var searchResults: [PodcastEpisode] = []
    @Published var isSearching = false
    @Published var error: String?
    
    private let baseUrl = "https://itunes.apple.com/search"
    
    func searchPodcasts(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseUrl)?term=\(encodedQuery)&entity=podcast&language=ja") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let results = try JSONDecoder().decode(ItunesSearchResponse.self, from: data)
            await MainActor.run {
                self.searchResults = results.results.map { result in
                    PodcastEpisode(
                        id: result.trackId,
                        title: result.trackName,
                        description: result.description ?? "",
                        audioUrl: result.episodeUrl ?? "",
                        duration: TimeInterval(result.trackTimeMillis ?? 0) / 1000,
                        publishDate: ISO8601DateFormatter().date(from: result.releaseDate ?? "") ?? Date()
                    )
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func downloadEpisode(_ episode: PodcastEpisode) async throws -> URL {
        guard let url = URL(string: episode.audioUrl) else {
            throw URLError(.badURL)
        }
        
        let (downloadUrl, _) = try await URLSession.shared.download(from: url)
        let documentsPath = FileManager.default.temporaryDirectory
        let savedUrl = documentsPath.appendingPathComponent(episode.id + ".m4a")
        
        try? FileManager.default.removeItem(at: savedUrl)
        try FileManager.default.moveItem(at: downloadUrl, to: savedUrl)
        
        return savedUrl
    }
}

private struct ItunesSearchResponse: Codable {
    let results: [ItunesPodcast]
}

private struct ItunesPodcast: Codable {
    let trackId: String
    let trackName: String
    let description: String?
    let episodeUrl: String?
    let trackTimeMillis: Int?
    let releaseDate: String?
}
