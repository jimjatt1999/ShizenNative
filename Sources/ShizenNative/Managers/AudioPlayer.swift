import AVFoundation

class AudioPlayer: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var currentSegmentId: String?
    @Published var playbackRate: Float = 1.0
    
    private var timer: Timer?
    private var currentEndTime: Double?
    
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
    
    func playSegment(segment: Segment) {
        print("Playing segment:")
        print("ID: \(segment.id)")
        print("Start: \(segment.start)")
        print("End: \(segment.end)")
        print("Text: \(segment.text)")
        
        playSegment(start: segment.start, end: segment.end, segmentId: segment.id.uuidString)
    }
    
    func playSegment(start: Double, end: Double, segmentId: String? = nil) {
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
        
        print("Current time after seek: \(player.currentTime)")
        
        // Start playback
        player.play()
        isPlaying = true
        
        // Start timer to track progress and handle segment end
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = player.currentTime
            
            if let endTime = self.currentEndTime, player.currentTime >= endTime {
                self.stop()
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
        audioPlayer?.stop()
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentSegmentId = nil
    }
    
    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
        print("Seeked to time: \(time)")
    }
}
