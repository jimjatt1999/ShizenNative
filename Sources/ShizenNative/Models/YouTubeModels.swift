import Foundation

struct YouTubeVideo: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailUrl: String
    let duration: String
    let url: String
    let description: String?
    let publishedAt: Date?
    let viewCount: Int?
    let likeCount: Int?
    let channelId: String?
    let channelThumbnailUrl: String?
    let tags: [String]?
    
    init(
        id: String,
        title: String,
        channelTitle: String,
        thumbnailUrl: String,
        duration: String,
        url: String,
        description: String? = nil,
        publishedAt: Date? = nil,
        viewCount: Int? = nil,
        likeCount: Int? = nil,
        channelId: String? = nil,
        channelThumbnailUrl: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.url = url
        self.description = description
        self.publishedAt = publishedAt
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.channelId = channelId
        self.channelThumbnailUrl = channelThumbnailUrl
        self.tags = tags
    }
}

extension YouTubeVideo {
    var formattedViewCount: String? {
        guard let count = viewCount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count))
    }
    
    var formattedLikeCount: String? {
        guard let count = likeCount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count))
    }
    
    var formattedPublishDate: String? {
        guard let date = publishedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var shortDuration: String {
        let components = duration.split(separator: ":")
        if components.count == 3 {
            return "\(components[0]):\(components[1]):\(components[2])"
        } else if components.count == 2 {
            return "\(components[0]):\(components[1])"
        }
        return duration
    }
}
