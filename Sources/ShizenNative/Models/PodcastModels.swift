import Foundation

struct ItunesSearchResponse: Codable {
    let resultCount: Int
    let results: [ItunesPodcastResponse]
}

struct ItunesPodcastResponse: Codable, Identifiable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let description: String?
    let releaseDate: String?
    let artworkUrl30: String?
    let artworkUrl60: String?
    let artworkUrl100: String?
    let artworkUrl600: String?
    let genres: [String]?
    let feedUrl: String?
    let episodeUrl: String?
    let trackTimeMillis: Int?
    let country: String?
    let primaryGenreName: String?
    let contentAdvisoryRating: String?
    
    var id: Int { trackId }
    
    enum CodingKeys: String, CodingKey {
        case trackId
        case trackName
        case artistName
        case collectionName
        case description
        case releaseDate
        case artworkUrl30
        case artworkUrl60
        case artworkUrl100
        case artworkUrl600
        case genres
        case feedUrl
        case episodeUrl
        case trackTimeMillis
        case country
        case primaryGenreName
        case contentAdvisoryRating
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackId = try container.decode(Int.self, forKey: .trackId)
        trackName = try container.decode(String.self, forKey: .trackName)
        artistName = try container.decode(String.self, forKey: .artistName)
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        artworkUrl30 = try container.decodeIfPresent(String.self, forKey: .artworkUrl30)
        artworkUrl60 = try container.decodeIfPresent(String.self, forKey: .artworkUrl60)
        artworkUrl100 = try container.decodeIfPresent(String.self, forKey: .artworkUrl100)
        artworkUrl600 = try container.decodeIfPresent(String.self, forKey: .artworkUrl600)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
        feedUrl = try container.decodeIfPresent(String.self, forKey: .feedUrl)
        episodeUrl = try container.decodeIfPresent(String.self, forKey: .episodeUrl)
        trackTimeMillis = try container.decodeIfPresent(Int.self, forKey: .trackTimeMillis)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        primaryGenreName = try container.decodeIfPresent(String.self, forKey: .primaryGenreName)
        contentAdvisoryRating = try container.decodeIfPresent(String.self, forKey: .contentAdvisoryRating)
    }
}

struct PodcastEpisode: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let audioUrl: String
    let duration: TimeInterval
    let publishDate: Date
    let thumbnailUrl: String?
    let author: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case audioUrl
        case duration
        case publishDate
        case thumbnailUrl
        case author
    }
    
    init(id: String, title: String, description: String, audioUrl: String, duration: TimeInterval, publishDate: Date, thumbnailUrl: String?, author: String) {
        self.id = id
        self.title = title
        self.description = description
        self.audioUrl = audioUrl
        self.duration = duration
        self.publishDate = publishDate
        self.thumbnailUrl = thumbnailUrl
        self.author = author
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        audioUrl = try container.decode(String.self, forKey: .audioUrl)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        publishDate = try container.decode(Date.self, forKey: .publishDate)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        author = try container.decode(String.self, forKey: .author)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(audioUrl, forKey: .audioUrl)
        try container.encode(duration, forKey: .duration)
        try container.encode(publishDate, forKey: .publishDate)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encode(author, forKey: .author)
    }
    
    static func == (lhs: PodcastEpisode, rhs: PodcastEpisode) -> Bool {
        lhs.id == rhs.id
    }
}

enum PodcastError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case feedParsingError
    case downloadError
    case noEpisodes
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode podcast data"
        case .feedParsingError:
            return "Failed to parse podcast feed"
        case .downloadError:
            return "Failed to download episode"
        case .noEpisodes:
            return "No episodes found"
        }
    }
}

extension PodcastEpisode {
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    var formattedPublishDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: publishDate)
    }
    
    var isRecent: Bool {
        Calendar.current.dateComponents([.day], from: publishDate, to: Date()).day ?? 0 < 7
    }
}

extension ItunesPodcastResponse {
    var bestArtwork: String? {
        artworkUrl600 ?? artworkUrl100 ?? artworkUrl60 ?? artworkUrl30
    }
    
    var formattedDuration: String? {
        guard let millis = trackTimeMillis else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(millis) / 1000)
    }
}
