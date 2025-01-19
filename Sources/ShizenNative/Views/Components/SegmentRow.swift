import SwiftUI

struct SegmentRow: View {
    let segment: Segment
    @ObservedObject var audioPlayer: AudioPlayer
    @Binding var isPlaying: Bool
    var isCurrentSegment: Bool
    var isSelected: Bool
    
    var body: some View {
        HStack {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            } else {
                Button(action: {
                    if isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.stop()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            audioPlayer.playSegment(segment: segment)
                        }
                    }
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
                    if segment.isDuplicate {
                        Text("Duplicate")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if segment.isHiddenFromSRS {
                        Text("Hidden from SRS")
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
    }
    
    private func timeString(start: Double, end: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return "\(formatter.string(from: start) ?? "0:00") - \(formatter.string(from: end) ?? "0:00")"
    }
}
