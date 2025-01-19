import Foundation
import AVFoundation

class RecordingManager: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    private var timer: Timer?
    
    func startRecording() -> URL? {
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let audioFilename = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingTime = self?.audioRecorder?.currentTime ?? 0
            }
            
            return audioFilename
        } catch {
            print("Recording failed: \(error)")
            return nil
        }
    }
    
    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        
        guard let recorder = audioRecorder else { return nil }
        let url = recorder.url
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        recordingTime = 0
        
        return url
    }
}
