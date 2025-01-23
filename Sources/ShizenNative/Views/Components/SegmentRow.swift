import SwiftUI

enum DifficultyTag: String, CaseIterable {
    case easy
    case medium
    case hard
    case veryHard
    
    var name: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .veryHard: return "Very Hard"
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .blue
        case .hard: return .orange
        case .veryHard: return .red
        }
    }
}

struct SegmentRow: View {
    let segment: Segment
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var reviewState: ReviewState
    var isPlaying: Bool
    var isCurrentSegment: Bool
    var isSelected: Bool
    
    // Computed properties for segment status
    var reviewStatus: ReviewStatus {
        let segmentId = segment.id.uuidString
        if let card = reviewState.reviewCards[segmentId] {
            if card.dueDate <= Date() {
                return .due
            } else {
                return .scheduled(date: card.dueDate)
            }
        }
        return .new
    }
    
    var difficultyColor: Color {
        let segmentId = segment.id.uuidString
        if let card = reviewState.reviewCards[segmentId] {
            switch card.ease {
            case ..<1.5: return .red
            case 1.5..<2.0: return .orange
            case 2.0..<2.5: return .yellow
            case 2.5..<3.0: return .green
            default: return .blue
            }
        }
        return .gray
    }
    
    var body: some View {
        HStack {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            } else {
                Button(action: {
                    handlePlayback()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading) {
                Text(segment.text)
                    .lineLimit(2)
                    .foregroundColor(isCurrentSegment ? .blue : .primary)
                
                HStack(spacing: 8) {
                    ReviewStatusBadge(status: reviewStatus)
                    
                    Circle()
                        .fill(difficultyColor)
                        .frame(width: 8, height: 8)
                    
                    if segment.isDuplicate {
                        Text("Duplicate")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if segment.isHiddenFromSRS {
                        Text("Hidden")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(timeString(start: segment.start, end: segment.end))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .background(
            Group {
                if isSelected {
                    Color.blue.opacity(0.1)
                } else if isCurrentSegment {
                    Color.blue.opacity(0.05)
                } else {
                    Color.clear
                }
            }
        )
        .contextMenu {
            Button(action: {
                var updatedSegment = segment
                updatedSegment.isHiddenFromSRS.toggle()
            }) {
                Label(segment.isHiddenFromSRS ? "Show in SRS" : "Hide from SRS", 
                      systemImage: "eye")
            }
            
            Menu("Tag Difficulty") {
                ForEach(DifficultyTag.allCases, id: \.self) { tag in
                    Button(action: {
                    }) {
                        Label(tag.name, systemImage: "tag.fill")
                            .foregroundColor(tag.color)
                    }
                }
            }
            
            Button(action: {
            }) {
                Label("Add Tag...", systemImage: "tag.fill")
            }
        }
    }
    
    private func handlePlayback() {
        if isPlaying {
            audioPlayer.pause()
        } else {
            // Important: Stop any existing playback first
            audioPlayer.stop()
            // Small delay to ensure clean state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                audioPlayer.playSegment(segment: segment)
            }
        }
    }
    
    private func timeString(start: Double, end: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return "\(formatter.string(from: start) ?? "0:00") - \(formatter.string(from: end) ?? "0:00")"
    }
}
