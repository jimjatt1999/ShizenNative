import SwiftUI
import AVFoundation
import Speech

struct AudioEditorView: View {
    let audioURL: URL
    let onSave: (URL, Double, String) -> Void
    let onCancel: () -> Void
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var totalDuration: Double = 0
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var segmentDuration: Double
    @State private var showSegmentControls = false
    @State private var samples: [Float] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingRename = false
    @State private var newFileName = ""
    @State private var showDuplicateNameWarning = false
    
    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    init(audioURL: URL, initialSegmentDuration: Double, onSave: @escaping (URL, Double, String) -> Void, onCancel: @escaping () -> Void) {
        self.audioURL = audioURL
        self.onSave = onSave
        self.onCancel = onCancel
        let player = try? AVAudioPlayer(contentsOf: audioURL)
        let totalDuration = player?.duration ?? 0
        _segmentDuration = State(initialValue: min(initialSegmentDuration, totalDuration))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if showingRename {
                    TextField("Enter new name", text: $newFileName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                        .transition(.opacity)
                    
                    Button(action: {
                        withAnimation {
                            showingRename = false
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                } else {
                    Text("Edit Audio")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            showingRename.toggle()
                            if showingRename {
                                // Set initial name without the UUID part
                                newFileName = audioURL.lastPathComponent
                                    .replacingOccurrences(of: "trimmed_", with: "")
                                    .components(separatedBy: ".").first ?? ""
                            }
                        }
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: handleSave) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSaving)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Audio Trimmer
                    AudioTrimmerView(
                        samples: samples,
                        startTime: $startTime,
                        endTime: $endTime,
                        currentTime: $currentTime,
                        totalDuration: totalDuration,
                        isPlaying: isPlaying
                    )
                    .frame(height: 150)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Time display
                    HStack {
                        Text(timeString(time: startTime))
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text("Duration: \(timeString(time: endTime - startTime))")
                            .monospacedDigit()
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(timeString(time: endTime))
                            .monospacedDigit()
                    }
                    .font(.system(size: 14))
                    .padding(.horizontal)
                    
                    if let error = saveError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .padding()
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Improved Segment Duration Controls
                    SegmentDurationControls(
                        segmentDuration: $segmentDuration,
                        showControls: $showSegmentControls,
                        totalDuration: totalDuration
                    )
                    
                    // Playback control
                    Button(action: handlePlayback) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                }
                .padding(.vertical)
            }
            
            .alert("File Exists", isPresented: $showDuplicateNameWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A file with this name already exists. Please choose a different name.")
            }
        }
        .frame(width: 800, height: 600)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            setupAudioPlayer()
            loadAudioSamples()
        }
        .onDisappear {
            audioPlayer?.stop()
        }
        .onReceive(timer) { _ in
            if isPlaying, let player = audioPlayer {
                currentTime = player.currentTime
                if currentTime >= endTime {
                    isPlaying = false
                }
            }
        }
    }
    private func setupAudioPlayer() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            totalDuration = audioPlayer?.duration ?? 0
            endTime = totalDuration
        } catch {
            print("Error setting up audio player: \(error)")
            saveError = "Failed to load audio: \(error.localizedDescription)"
        }
    }
    
    private func loadAudioSamples() {
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try audioFile.read(into: buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            
            let samplesNeeded = 200
            let stride = Int(frameCount) / samplesNeeded
            samples = stride > 0 ? Array(0..<samplesNeeded).map { i in
                let idx = i * stride
                return abs(channelData[idx])
            } : []
        } catch {
            print("Error loading audio samples: \(error)")
        }
    }
    
    private func handlePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.currentTime = startTime
            audioPlayer?.play()
            isPlaying = true
        }
    }
    
    private func handleSave() {
        isSaving = true
        saveError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let trimmedURL = trimAudio() {
                let finalURL: URL
                let directory = trimmedURL.deletingLastPathComponent()
                let fileExtension = trimmedURL.pathExtension
                
                // Use the new filename if provided, otherwise use the original name without extension
                let sourceName: String
                if !newFileName.isEmpty {
                    sourceName = newFileName
                } else {
                    sourceName = audioURL.deletingPathExtension().lastPathComponent
                        .replacingOccurrences(of: "trimmed_", with: "")
                }
                
                finalURL = directory.appendingPathComponent("\(sourceName).\(fileExtension)")
                
                do {
                    try FileManager.default.moveItem(at: trimmedURL, to: finalURL)
                    DispatchQueue.main.async {
                        isSaving = false
                        onSave(finalURL, segmentDuration, sourceName)
                    }
                } catch {
                    DispatchQueue.main.async {
                        isSaving = false
                        saveError = "Failed to rename file: \(error.localizedDescription)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    isSaving = false
                    saveError = "Failed to save audio segment"
                }
            }
        }
    }
    
    private func trimAudio() -> URL? {
        guard let asset = AVAsset(url: audioURL) as? AVURLAsset else { return nil }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).m4a")
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else { return nil }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        let startTime = CMTime(seconds: self.startTime, preferredTimescale: 1000)
        let endTime = CMTime(seconds: self.endTime, preferredTimescale: 1000)
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        
        let semaphore = DispatchSemaphore(value: 0)
        var exportSuccessful = false
        
        exportSession.exportAsynchronously {
            exportSuccessful = exportSession.status == .completed
            semaphore.signal()
        }
        
        semaphore.wait()
        
        return exportSuccessful ? outputURL : nil
    }
    
    private func timeString(time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct SegmentDurationControls: View {
    @Binding var segmentDuration: Double
    @Binding var showControls: Bool
    let totalDuration: Double
    
    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls.toggle()
                }
            }) {
                HStack {
                    Text("Segment Duration")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showControls ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if showControls {
                VStack(spacing: 16) {
                    HStack {
                        Text("Duration:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(segmentDuration)) seconds")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                    
                    VStack(spacing: 4) {
                        Slider(
                            value: $segmentDuration,
                            in: 5...totalDuration,
                            step: 1
                        )
                        .tint(.blue)
                        
                        HStack {
                            Text("5s")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(totalDuration))s")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([5, 10, 15, 30, 60], id: \.self) { duration in
                                QuickSelectButton(
                                    duration: duration,
                                    isSelected: segmentDuration == Double(duration),
                                    action: { segmentDuration = Double(duration) }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
    }
}

struct QuickSelectButton: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(duration)s")
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview provider
struct AudioEditorView_Previews: PreviewProvider {
    static var previews: some View {
        AudioEditorView(
            audioURL: URL(fileURLWithPath: ""),
            initialSegmentDuration: 30,
            onSave: { _, _, _ in },
            onCancel: {}
        )
    }
}
struct AudioTrimmerView: View {
    let samples: [Float]
    @Binding var startTime: Double
    @Binding var endTime: Double
    @Binding var currentTime: Double
    let totalDuration: Double
    let isPlaying: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                
                // Waveform visualization
                AudioWaveformShape(samples: samples)
                    .foregroundColor(.blue.opacity(0.3))
                    .frame(height: geometry.size.height * 0.8)
                    .padding(.horizontal, 28)
                
                // Selected region
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(
                        width: max(0, geometry.size.width * CGFloat((endTime - startTime) / totalDuration)),
                        height: geometry.size.height
                    )
                    .offset(x: geometry.size.width * CGFloat(startTime / totalDuration))
                
                // Handles
                Group {
                    // Left handle
                    AudioTrimHandle(
                        position: $startTime,
                        totalDuration: totalDuration,
                        width: geometry.size.width,
                        isStart: true,
                        otherPosition: endTime
                    )
                    
                    // Right handle
                    AudioTrimHandle(
                        position: $endTime,
                        totalDuration: totalDuration,
                        width: geometry.size.width,
                        isStart: false,
                        otherPosition: startTime
                    )
                }
                
                // Playhead
                if isPlaying {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .frame(height: geometry.size.height)
                        .offset(x: geometry.size.width * CGFloat(currentTime / totalDuration))
                        .animation(.linear(duration: 0.03), value: currentTime)
                }
            }
        }
    }
}

struct AudioWaveformShape: View {
    let samples: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2
                let sampleWidth = width / CGFloat(samples.count)
                
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * sampleWidth
                    let sampleHeight = CGFloat(sample) * height * 0.8 // Scale height to 80%
                    
                    path.move(to: CGPoint(x: x, y: midY - sampleHeight/2))
                    path.addLine(to: CGPoint(x: x, y: midY + sampleHeight/2))
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

struct AudioTrimHandle: View {
    @Binding var position: Double
    let totalDuration: Double
    let width: CGFloat
    let isStart: Bool
    let otherPosition: Double
    
    // For smooth dragging
    @GestureState private var isDragging: Bool = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle knob
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.15), radius: 3)
                .overlay(
                    Image(systemName: isStart ? "arrow.left" : "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                )
            
            // Handle bar
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 28)
        .position(x: width * CGFloat(position / totalDuration), y: 75)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    let newPosition = Double(value.location.x / width) * totalDuration
                    if isStart {
                        position = max(0, min(newPosition, otherPosition - 1))
                    } else {
                        position = min(totalDuration, max(newPosition, otherPosition + 1))
                    }
                }
        )
        .animation(isDragging ? nil : .interactiveSpring(), value: position)
    }
}

// Helper extension for smooth animations
extension Animation {
    static func interactiveSpring() -> Animation {
        .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    }
}