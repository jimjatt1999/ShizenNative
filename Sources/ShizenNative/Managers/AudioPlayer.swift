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
        playSegment(start: segment.start, end: segment.end, segmentId: segment.id.uuidString, onComplete: onComplete)
    }
    
    func playSegment(start: Double, end: Double, segmentId: String, onComplete: (() -> Void)? = nil) {
        guard let player = audioPlayer else {
            print("No audio player available")
            return
        }
        
        // Stop any existing playback and timer
        stop()
        
        print("Setting up playback:")
        print("Start time: \(start)")
        print("End time: \(end)")
        print("Current time before seek: \(player.currentTime)")
        
        // Set up new playback
        player.currentTime = start
        currentEndTime = end
        currentSegmentId = segmentId
        player.rate = playbackRate
        autoAdvanceHandler = onComplete
        
        print("Current time after seek: \(player.currentTime)")
        
        // Start playback
        player.play()
        isPlaying = true
        
        // Start timer to track progress and handle segment end
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer,
                  let endTime = self.currentEndTime else { return }
            
            self.currentTime = player.currentTime
            
            if player.currentTime >= endTime {
                self.stop()
                self.autoAdvanceHandler?()
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
        print("Seeked to time: \(time)")
    }
}
