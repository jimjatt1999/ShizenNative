import Foundation

class RSSFeedParser: NSObject, XMLParserDelegate {
    var episodes: [RSSEpisode] = []
    private var currentElement = ""
    private var currentEpisode: RSSEpisode?
    private var elementContent = ""
    private var currentImageUrl: String?
    private var channelImageUrl: String?
    private var channelAuthor: String?
    private let dateFormatter: DateFormatter
    
    init(dateFormatter: DateFormatter) {
        self.dateFormatter = dateFormatter
        super.init()
    }
    
    struct RSSEpisode {
        var guid: String = UUID().uuidString
        var title: String = ""
        var description: String = ""
        var audioUrl: String = ""
        var duration: TimeInterval = 0
        var publishDate: Date = Date()
        var imageUrl: String?
        var author: String = ""
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        elementContent = ""
        
        switch elementName {
        case "item":
            currentEpisode = RSSEpisode()
            currentEpisode?.imageUrl = channelImageUrl
            currentEpisode?.author = channelAuthor ?? ""
        case "enclosure":
            if attributeDict["type"]?.contains("audio") == true {
                currentEpisode?.audioUrl = attributeDict["url"] ?? ""
            }
        case "itunes:image":
            if let href = attributeDict["href"] {
                if currentEpisode != nil {
                    currentEpisode?.imageUrl = href
                } else {
                    channelImageUrl = href
                }
            }
        case "image":
            if currentEpisode == nil {
                currentImageUrl = attributeDict["href"]
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        elementContent += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let content = elementContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if currentEpisode == nil {
            // Handle channel-level elements
            switch elementName {
            case "itunes:author":
                channelAuthor = content
            case "url":
                if channelImageUrl == nil {
                    channelImageUrl = content
                }
            default:
                break
            }
            return
        }
        
        switch elementName {
        case "title":
            currentEpisode?.title = content
        case "description":
            currentEpisode?.description = content
        case "pubDate":
            if let date = dateFormatter.date(from: content) {
                currentEpisode?.publishDate = date
            }
        case "itunes:duration":
            if content.contains(":") {
                let components = content.split(separator: ":")
                if components.count == 3,
                   let hours = Int(components[0]),
                   let minutes = Int(components[1]),
                   let seconds = Int(components[2]) {
                    currentEpisode?.duration = TimeInterval(hours * 3600 + minutes * 60 + seconds)
                } else if components.count == 2,
                          let minutes = Int(components[0]),
                          let seconds = Int(components[1]) {
                    currentEpisode?.duration = TimeInterval(minutes * 60 + seconds)
                }
            } else if let seconds = TimeInterval(content) {
                currentEpisode?.duration = seconds
            }
        case "itunes:author":
            currentEpisode?.author = content
        case "guid":
            currentEpisode?.guid = content
        case "item":
            if let episode = currentEpisode,
               !episode.audioUrl.isEmpty {
                episodes.append(episode)
            }
            currentEpisode = nil
        default:
            break
        }
    }
}
