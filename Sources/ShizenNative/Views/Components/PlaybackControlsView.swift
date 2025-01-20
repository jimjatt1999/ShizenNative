import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    let segments: [Segment]
    @Binding var currentIndex: Int
    @Binding var isPlaying: Bool
    @Binding var playbackSpeed: Float
    
    private let availableSpeeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            HStack {
                Text(timeString(time: audioPlayer.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * (audioPlayer.currentTime - segments[currentIndex].start) / (segments[currentIndex].end - segments[currentIndex].start), height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
                
                Text(timeString(time: segments[currentIndex].end))
                    .font(.caption)
                    .monospacedDigit()
            }
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    if currentIndex > 0 {
                        currentIndex -= 1
                        playCurrentSegment()
                    }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .disabled(currentIndex == 0)
                
                Button(action: {
                    if isPlaying {
                        audioPlayer.pause()
                        isPlaying = false
                    } else {
                        playCurrentSegment()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                }
                
                Button(action: {
                    if currentIndex < segments.count - 1 {
                        currentIndex += 1
                        playCurrentSegment()
                    }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .disabled(currentIndex >= segments.count - 1)
                
                // Speed control
                Menu {
                    ForEach(availableSpeeds, id: \.self) { speed in
                        Button(action: {
                            playbackSpeed = speed
                            audioPlayer.setPlaybackRate(speed)
                        }) {
                            HStack {
                                Text("\(String(format: "%.2fx", speed))")
                                if speed == playbackSpeed {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text("\(String(format: "%.2fx", playbackSpeed))")
                    }
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.vertical, 5)
        }
        .padding(.bottom)
    }
    
    private func playCurrentSegment() {
        let segment = segments[currentIndex]
        audioPlayer.playSegment(segment: segment) { [self] in
            if currentIndex < segments.count - 1 {
                DispatchQueue.main.async {
                    currentIndex += 1
                    playCurrentSegment()
                }
            }
        }
        isPlaying = true
    }
    
    private func timeString(time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
