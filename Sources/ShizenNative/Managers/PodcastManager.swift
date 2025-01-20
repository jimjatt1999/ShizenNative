import Foundation

@MainActor
class PodcastManager: ObservableObject {
    @Published var searchResults: [ItunesPodcastResponse] = []
    @Published var popularPodcasts: [ItunesPodcastResponse] = []
    @Published var recentPodcasts: [ItunesPodcastResponse] = []
    @Published var isSearching = false
    @Published var isDownloading = false
    @Published var error: String?
    
    private let baseUrl = "https://itunes.apple.com/search"
    private let popularPodcastFeeds = [
        (id: "1441789754", url: "https://feeds.libsyn.com/391779/rss"), // Learning Japanese with Noriko
        (id: "1493137578", url: "https://feeds.megaphone.fm/japaneseclass101"), // JapanesePod101
        (id: "932508256", url: "https://feeds.megaphone.fm/newsinjapanese"), // News in Slow Japanese
        (id: "1233698354", url: "https://feeds.buzzsprout.com/1411126.rss"), // Japanese Podcast for Beginners
        (id: "595981406", url: "https://www3.nhk.or.jp/rj/podcast/rss/english.xml") // NHK World Radio Japan
    ]
    
    private let rfc822DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    func searchPodcasts(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseUrl)?term=\(encodedQuery)&entity=podcast&language=ja&limit=20") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ItunesSearchResponse.self, from: data)
            self.searchResults = response.results
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func loadPopularPodcasts() async {
        do {
            var podcasts: [ItunesPodcastResponse] = []
            
            for feed in popularPodcastFeeds {
                guard let url = URL(string: "\(baseUrl)?id=\(feed.id)&entity=podcast") else { continue }
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(ItunesSearchResponse.self, from: data)
                if let podcast = response.results.first {
                    podcasts.append(podcast)
                }
            }
            
            self.popularPodcasts = podcasts
        } catch {
            print("Error loading popular podcasts: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    func loadRecentPodcasts() async {
        guard let url = URL(string: "\(baseUrl)?term=japanese&entity=podcast&language=ja&limit=20&sort=recent") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ItunesSearchResponse.self, from: data)
            self.recentPodcasts = response.results
        } catch {
            print("Error loading recent podcasts: \(error)")
            self.error = error.localizedDescription
        }
    }
    
    func loadEpisodes(from feedUrl: String) async throws -> [PodcastEpisode] {
        guard let url = URL(string: feedUrl) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = XMLParser(data: data)
        let feedParser = RSSFeedParser(dateFormatter: rfc822DateFormatter)
        parser.delegate = feedParser
        
        guard parser.parse() else {
            throw NSError(domain: "PodcastManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse feed"])
        }
        
        return feedParser.episodes.map { episode in
            PodcastEpisode(
                id: episode.guid,
                title: episode.title,
                description: episode.description,
                audioUrl: episode.audioUrl,
                duration: episode.duration,
                publishDate: episode.publishDate,
                thumbnailUrl: episode.imageUrl,
                author: episode.author
            )
        }
    }
    
    func downloadEpisode(_ episode: PodcastEpisode) async throws -> URL {
        isDownloading = true
        defer { isDownloading = false }
        
        guard var urlString = episode.audioUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // If URL is not HTTPS, try to convert it
        if urlString.hasPrefix("http://") {
            urlString = "https://" + urlString.dropFirst("http://".count)
        }
        
        let (downloadUrl, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Create a safe filename from the episode ID
        let safeFileName = episode.id.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        let documentsPath = FileManager.default.temporaryDirectory
        let savedUrl = documentsPath.appendingPathComponent("\(safeFileName).mp3")
        
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: savedUrl)
        
        // Move downloaded file to final location
        try FileManager.default.moveItem(at: downloadUrl, to: savedUrl)
        
        return savedUrl
    }
}
