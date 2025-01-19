import SwiftUI

struct WaveformView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    let segment: Segment
    
    private let barCount = 50
    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 3
    private let animationDuration = 0.6
    
    var isCurrentlyPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentSegmentId == segment.id.uuidString
    }
    
    var currentProgress: Double {
        if audioPlayer.currentSegmentId == segment.id.uuidString {
            return (audioPlayer.currentTime - segment.start) / (segment.end - segment.start)
        }
        return 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        height: barHeight(at: index, maxHeight: geometry.size.height),
                        color: barColor(at: index),
                        isAnimating: isCurrentlyPlaying,
                        animationDelay: Double(index) * 0.02
                    )
                    .frame(width: barWidth(in: geometry.size.width))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = value.location.x / geometry.size.width
                        let time = segment.start + (segment.end - segment.start) * Double(progress)
                        audioPlayer.seek(to: time)
                    }
                    .onEnded { value in
                        let progress = value.location.x / geometry.size.width
                        let time = segment.start + (segment.end - segment.start) * Double(progress)
                        audioPlayer.playSegment(start: time, end: segment.end, segmentId: segment.id.uuidString)
                    }
            )
            .contentShape(Rectangle())
        }
    }
    
    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        let totalSpacing = CGFloat(barCount - 1) * barSpacing
        return (totalWidth - totalSpacing) / CGFloat(barCount)
    }
    
    private func barHeight(at index: Int, maxHeight: CGFloat) -> CGFloat {
        let progress = Double(index) / Double(barCount)
        let baseHeight = maxHeight * 0.4
        let amplitude = maxHeight * 0.3
        
        if isCurrentlyPlaying {
            // Create a wave-like pattern
            let phase = Double(index) * 0.3 + Date().timeIntervalSinceReferenceDate * 4
            let wave = sin(phase)
            let wave2 = cos(phase * 0.5)
            return baseHeight + amplitude * (wave * 0.7 + wave2 * 0.3)
        } else {
            // Static pattern with variation
            let variation = sin(progress * .pi * 2) * 0.5 + 0.5
            return max(minBarHeight, baseHeight + (progress < currentProgress ? amplitude * variation : 0))
        }
    }
    
    private func barColor(at index: Int) -> Color {
        let progress = Double(index) / Double(barCount)
        
        if progress <= currentProgress {
            if isCurrentlyPlaying {
                // Create a gradient effect for playing state
                let hue = (progress + Date().timeIntervalSinceReferenceDate * 0.1).truncatingRemainder(dividingBy: 1.0)
                return Color(hue: hue, saturation: 0.6, brightness: 0.9)
            } else {
                return .blue
            }
        }
        return .blue.opacity(0.3)
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let color: Color
    let isAnimating: Bool
    let animationDelay: Double
    
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(height: height)
            .scaleEffect(y: 1.0 + animationPhase * 0.3)
            .animation(
                isAnimating ?
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(animationDelay) :
                    nil,
                value: animationPhase
            )
            .onAppear {
                if isAnimating {
                    animationPhase = 1.0
                }
            }
            .onChange(of: isAnimating) { newValue in
                animationPhase = newValue ? 1.0 : 0.0
            }
    }
}
