import Foundation

enum AudioSourceType: String, Codable, CaseIterable {
    case fileUpload = "File"
    case recording = "Record"
    case podcast = "Podcast"
    case youtube = "YouTube"
    
    var icon: String {
        switch self {
        case .fileUpload:
            return "doc"
        case .recording:
            return "mic"
        case .podcast:
            return "radio"
        case .youtube:
            return "play.tv"
        }
    }
}

enum AudioSourceError: Error {
    case invalidURL
    case downloadFailed
    case conversionFailed
    case saveFailed
    case unsupportedFormat
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .downloadFailed:
            return "Failed to download audio"
        case .conversionFailed:
            return "Failed to convert audio format"
        case .saveFailed:
            return "Failed to save audio file"
        case .unsupportedFormat:
            return "Unsupported audio format"
        }
    }
}

struct AudioFile: Identifiable, Codable {
    let id: String
    let url: URL
    let sourceType: AudioSourceType
    let metadata: AudioMetadata
    
    struct AudioMetadata: Codable {
        let title: String
        let author: String?
        let duration: TimeInterval
        let createdAt: Date
        let format: String
        let fileSize: Int64
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
        case sourceType
        case metadata
    }
    
    init(id: String, url: URL, sourceType: AudioSourceType, metadata: AudioMetadata) {
        self.id = id
        self.url = url
        self.sourceType = sourceType
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        sourceType = try container.decode(AudioSourceType.self, forKey: .sourceType)
        metadata = try container.decode(AudioMetadata.self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(metadata, forKey: .metadata)
    }
}