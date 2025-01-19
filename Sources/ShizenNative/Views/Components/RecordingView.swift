import SwiftUI

struct RecordingView: View {
    @StateObject private var recordingManager = RecordingManager()
    @State private var recordedFileURL: URL?
    var onRecordingComplete: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            if recordingManager.isRecording {
                Text(timeString(from: recordingManager.recordingTime))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
            } else {
                Text("Ready to Record")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                if recordingManager.isRecording {
                    if let url = recordingManager.stopRecording() {
                        recordedFileURL = url
                        onRecordingComplete(url)
                    }
                } else {
                    recordedFileURL = recordingManager.startRecording()
                }
            }) {
                Image(systemName: recordingManager.isRecording ? "stop.circle.fill" : "record.circle")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundColor(recordingManager.isRecording ? .red : .blue)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
