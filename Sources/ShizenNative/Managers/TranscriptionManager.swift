import Foundation
import Speech
import AVFoundation

enum TranscriptionError: Error {
    case initializationFailed(String)
    case authorizationDenied
    case recognitionFailed(String)
    case invalidAudio
    case transcriptionFailed(String)
    case noSpeechDetected
    
    var localizedDescription: String {
        switch self {
        case .initializationFailed(let message):
            return "Initialization failed: \(message)"
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .recognitionFailed(let message):
            return "Recognition failed: \(message)"
        case .invalidAudio:
            return "Invalid audio file"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .noSpeechDetected:
            return "No speech detected in this segment. Try adjusting the segment duration."
        }
    }
}

@MainActor
class TranscriptionManager: ObservableObject {
    private var recognizer: SFSpeechRecognizer?
    private var audioPlayer: AVAudioPlayer?
    
    init() {
        do {
            recognizer = try createRecognizer()
            try requestAuthorization()
        } catch {
            print("Failed to initialize transcription manager: \(error)")
            recognizer = nil
        }
    }
    
    private func createRecognizer() throws -> SFSpeechRecognizer {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")) else {
            throw TranscriptionError.initializationFailed("Could not create recognizer for Japanese")
        }
        return recognizer
    }
    
    private func requestAuthorization() throws {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("Speech recognition authorized")
            case .denied, .restricted, .notDetermined:
                print("Speech recognition not authorized")
            @unknown default:
                fatalError()
            }
        }
    }
    
    func transcribe(audioPath: String, segmentDuration: Double) async throws -> [Segment] {
        guard FileManager.default.fileExists(atPath: audioPath) else {
            throw TranscriptionError.invalidAudio
        }
        
        let audioURL = URL(fileURLWithPath: audioPath)
        let asset = AVAsset(url: audioURL)
        let duration = try await asset.load(.duration).seconds
        print("Total audio duration: \(duration) seconds")
        
        var segments: [Segment] = []
        var startTime: Double = 0.0
        var consecutiveEmptySegments = 0
        let maxEmptySegments = 3 // Maximum number of consecutive empty segments before skipping
        
        while startTime < duration {
            let endTime = min(startTime + segmentDuration, duration)
            print("Processing segment: \(startTime) to \(endTime)")
            
            let segmentURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("segment_\(UUID().uuidString).m4a")
            
            // Export the segment
            try await exportSegment(asset: asset, startTime: startTime, endTime: endTime, outputURL: segmentURL)
            
            do {
                let segmentText = try await transcribeAudioFile(at: segmentURL)
                let trimmedText = segmentText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !trimmedText.isEmpty {
                    let segment = Segment(
                        text: trimmedText,
                        start: startTime,
                        end: endTime
                    )
                    segments.append(segment)
                    consecutiveEmptySegments = 0
                } else {
                    consecutiveEmptySegments += 1
                    if consecutiveEmptySegments >= maxEmptySegments {
                        // Skip ahead by a larger increment if we've had too many empty segments
                        startTime += segmentDuration * 2
                        continue
                    }
                }
            } catch {
                print("Error transcribing segment: \(error)")
                // Continue to next segment instead of failing entirely
            }
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: segmentURL)
            
            startTime = endTime
        }
        
        if segments.isEmpty {
            throw TranscriptionError.noSpeechDetected
        }
        
        print("Transcription completed. Generated \(segments.count) segments")
        return segments
    }
    
    private func exportSegment(asset: AVAsset, startTime: Double, endTime: Double, outputURL: URL) async throws {
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)!
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 1000),
            end: CMTime(seconds: endTime, preferredTimescale: 1000)
        )
        
        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed("Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")"))
                default:
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed("Export ended with unexpected status"))
                }
            }
        }
    }
    
    private func transcribeAudioFile(at url: URL) async throws -> String {
        guard let recognizer = recognizer else {
            throw TranscriptionError.initializationFailed("Recognizer not initialized")
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                } else if let result = result {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else {
                    continuation.resume(throwing: TranscriptionError.recognitionFailed("No result returned"))
                }
            }
        }
    }
}
