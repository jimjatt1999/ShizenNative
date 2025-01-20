import Foundation

final class ProcessController {
    private let process: Process
    private let pipe: Pipe
    private let fileHandle: FileHandle
    private var outputData = Data()
    
    init(process: Process, pipe: Pipe) {
        self.process = process
        self.pipe = pipe
        self.fileHandle = pipe.fileHandleForReading
    }
    
    func appendData(_ data: Data) {
        outputData.append(data)
    }
    
    func getOutput() -> Data {
        return outputData
    }
    
    func start() throws {
        try process.run()
    }
    
    func stop() {
        fileHandle.readabilityHandler = nil
        try? fileHandle.close()
        if process.isRunning {
            process.terminate()
        }
    }
    
    deinit {
        stop()
    }
}

@MainActor
final class YoutubeManager: ObservableObject {
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var isDownloading = false
    
    private var processController: ProcessController?
    
    deinit {
        processController?.stop()
        processController = nil
    }
    
    func downloadAudio(from url: String) async throws -> URL {
        guard !isDownloading else {
            throw NSError(domain: "", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Download already in progress"])
        }
        
        // Clean up any existing process
        processController?.stop()
        processController = nil
        
        downloadProgress = 0
        isDownloading = true
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let process = Process()
                let pipe = Pipe()
                
                let controller = ProcessController(process: process, pipe: pipe)
                self.processController = controller
                
                process.currentDirectoryPath = tempDir.path
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["python3", "-c", """
                import sys
                import json
                import yt_dlp
                
                def download_audio(url):
                    try:
                        ydl_opts = {
                            'format': 'bestaudio/best',
                            'postprocessors': [{
                                'key': 'FFmpegExtractAudio',
                                'preferredcodec': 'mp3',
                                'preferredquality': '192',
                            }],
                            'outtmpl': '%(id)s.%(ext)s',
                        }
                        
                        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                            info = ydl.extract_info(url, download=True)
                            video_id = info['id']
                            output_path = f"{video_id}.mp3"
                            result = {
                                'success': True,
                                'path': output_path,
                                'title': info.get('title', ''),
                                'duration': info.get('duration', 0)
                            }
                            print(json.dumps(result))
                            sys.stdout.flush()
                    except Exception as e:
                        print(json.dumps({'success': False, 'error': str(e)}))
                        sys.exit(1)
                
                if len(sys.argv) > 1:
                    download_audio(sys.argv[1])
                """, url]
                
                process.standardOutput = pipe
                process.standardError = pipe
                
                pipe.fileHandleForReading.readabilityHandler = { [weak controller] handle in
                    let data = handle.availableData
                    if data.isEmpty { return }
                    
                    controller?.appendData(data)
                    if let output = String(data: data, encoding: .utf8) {
                        print("Python output: \(output)")
                        
                        if output.contains("[download]") {
                            if let percentStr = output.components(separatedBy: "% of").first?
                                .components(separatedBy: " ").last,
                               let percent = Double(percentStr) {
                                Task { @MainActor [weak self] in
                                    self?.downloadProgress = percent
                                }
                            }
                        }
                    }
                }
                
                process.terminationHandler = { [weak self, weak controller] _ in
                    Task { @MainActor [weak self] in
                        defer {
                            self?.processController = nil
                            self?.isDownloading = false
                            self?.downloadProgress = 0
                        }
                        
                        guard let outputData = controller?.getOutput(),
                              let output = String(data: outputData, encoding: .utf8) else {
                            continuation.resume(throwing: NSError(domain: "", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid output"]))
                            return
                        }
                        
                        for line in output.components(separatedBy: .newlines).reversed() {
                            if line.contains("{") && line.contains("}"),
                               let jsonData = line.data(using: .utf8),
                               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let success = result["success"] as? Bool {
                                
                                if success, let outputPath = result["path"] as? String {
                                    let fileURL = tempDir.appendingPathComponent(outputPath)
                                    if FileManager.default.fileExists(atPath: fileURL.path) {
                                        continuation.resume(returning: fileURL)
                                        return
                                    }
                                }
                            }
                        }
                        
                        continuation.resume(throwing: NSError(domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Download failed"]))
                    }
                }
                
                try controller.start()
                
            } catch {
                self.processController = nil
                self.isDownloading = false
                self.downloadProgress = 0
                continuation.resume(throwing: error)
            }
        }
    }
}
