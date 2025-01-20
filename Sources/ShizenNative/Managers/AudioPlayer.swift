import AVFoundation

class AudioPlayer: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var currentSegmentId: String?
    @Published var playbackRate: Float = 1.0
    
    private var timer: Timer?
    private var currentEndTime: Double?
    private var autoAdvanceHandler: (() -> Void)?
    
    func load(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.enableRate = true
            audioPlayer?.prepareToPlay()
            print("Audio loaded successfully: \(url.lastPathComponent)")
        } catch {
            print("Error loading audio: \(error)")
        }
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
    }
    
    func playSegment(segment: Segment, onComplete: (() -> Void)? = nil) {
        print("Playing segment: \(segment.id)")
        autoAdvanceHandler = onComplete
        
        guard let player = audioPlayer else {
            print("No audio player available")
            return
        }
        
        // Set up playback
        player.currentTime = segment.start
        currentEndTime = segment.end
        currentSegmentId = segment.id.uuidString
        player.rate = playbackRate
        
        // Start playback
        player.play()
        isPlaying = true
        
        // Start timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer,
                  let endTime = self.currentEndTime else { return }
            
            self.currentTime = player.currentTime
            
            if player.currentTime >= endTime {
                let handler = self.autoAdvanceHandler
                self.autoAdvanceHandler = nil
                handler?()
            }
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    func stop() {
        audioPlayer?.pause()
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentSegmentId = nil
        autoAdvanceHandler = nil
    }
    
    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
}
