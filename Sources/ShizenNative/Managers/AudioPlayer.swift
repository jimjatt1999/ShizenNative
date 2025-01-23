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
        // First try loading directly
        if tryLoadDirectly(url: url) {
            return
        }
        
        // If direct loading fails, try converting
        print("Direct loading failed, attempting conversion...")
        Task {
            await convertAndLoadAudio(url: url)
        }
    }
    
    private func tryLoadDirectly(url: URL) -> Bool {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.enableRate = true
            self.audioPlayer = player
            print("Audio loaded successfully: \(url.lastPathComponent)")
            return true
        } catch {
            print("Direct loading failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func convertAndLoadAudio(url: URL) async {
        do {
            // Create asset
            let asset = AVAsset(url: url)
            
            // Create export session with different presets based on file type
            let presets = [
                AVAssetExportPresetAppleM4A,
                AVAssetExportPresetHighestQuality,
                AVAssetExportPresetMediumQuality
            ]
            
            var exportSession: AVAssetExportSession?
            
            // Try different presets until one works
            for preset in presets {
                if let session = AVAssetExportSession(asset: asset, presetName: preset) {
                    exportSession = session
                    break
                }
            }
            
            guard let export = exportSession else {
                print("Could not create export session with any preset")
                return
            }
            
            // Create temporary directory if it doesn't exist
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("AudioConversion", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, 
                                                  withIntermediateDirectories: true)
            
            // Set up export parameters
            let convertedUrl = tempDir
                .appendingPathComponent("converted_\(UUID().uuidString).m4a")
            
            export.outputURL = convertedUrl
            export.outputFileType = .m4a
            export.audioTimePitchAlgorithm = .spectral
            
            // Add audio mix if needed
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            if let audioTrack = tracks.first {
                let audioMix = AVMutableAudioMix()
                let inputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
                inputParameters.setVolume(1.0, at: .zero)
                audioMix.inputParameters = [inputParameters]
                export.audioMix = audioMix
            }
            
            // Convert the file
            print("Starting audio conversion...")
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                export.exportAsynchronously {
                    switch export.status {
                    case .completed:
                        print("Conversion completed successfully")
                        do {
                            self.audioPlayer = try AVAudioPlayer(contentsOf: convertedUrl)
                            self.audioPlayer?.enableRate = true
                            print("Converted audio loaded successfully")
                            continuation.resume()
                        } catch {
                            print("Error loading converted audio: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                        
                    case .failed:
                        let error = export.error ?? NSError(domain: "AudioConversion", code: -1, userInfo: nil)
                        print("Export failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        
                    case .cancelled:
                        print("Export cancelled")
                        continuation.resume(throwing: NSError(domain: "AudioConversion", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                        
                    default:
                        print("Export ended with status: \(export.status.rawValue)")
                        continuation.resume(throwing: NSError(domain: "AudioConversion", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unknown export status"]))
                    }
                    
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: convertedUrl)
                }
            }
            
        } catch {
            print("Error during audio conversion setup: \(error.localizedDescription)")
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
        print("Total duration: \(player.duration)")
        print("Current time before seek: \(player.currentTime)")
        
        // Validate timestamps
        let validStart = max(0, min(start, player.duration))
        let validEnd = max(validStart, min(end, player.duration))
        
        // Set up new playback
        player.currentTime = validStart
        currentEndTime = validEnd
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
        guard let player = audioPlayer else { return }
        let validTime = max(0, min(time, player.duration))
        player.currentTime = validTime
        currentTime = validTime
        print("Seeked to time: \(validTime)")
    }
}