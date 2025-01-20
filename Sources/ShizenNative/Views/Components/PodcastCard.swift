import SwiftUI

struct PodcastCard: View {
    let podcast: ItunesPodcastResponse
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                if let thumbnailUrl = podcast.artworkUrl600,
                   let url = URL(string: thumbnailUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(podcast.collectionName ?? podcast.trackName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(podcast.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let description = podcast.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding()
            }
            .background(Color(.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
