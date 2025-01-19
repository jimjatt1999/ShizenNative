import Foundation

enum AudioSourceType {
    case fileUpload
    case recording
    case podcast
    case youtube
}

struct PodcastEpisode: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let audioUrl: String
    let duration: TimeInterval
    let publishDate: Date
}
