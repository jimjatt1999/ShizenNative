import Foundation
import PythonKit

@MainActor
class YoutubeManager: ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var error: String?
    
    func downloadAudio(from url: String) async throws -> URL {
        isDownloading = true
        defer { isDownloading = false }
        
        let yt_dlp = Python.import("yt_dlp")
        
        let outputTemplate = FileManager.default.temporaryDirectory.appendingPathComponent("%(id)s.%(ext)s").path
        
        let progressHook = PythonFunction { [weak self] args in
            if let dict = args[0].checking.__dict__,
               let status = String(dict["status"]),
               status == "downloading",
               let progressStr = String(dict["_percent_str"]),
               let progress = Double(progressStr.replacingOccurrences(of: "%", with: "")) {
                Task { @MainActor in
                    self?.downloadProgress = progress
                }
            }
            return Python.None
        }
        
        let ydl_opts = Python.dict(
            format: "bestaudio/best",
            postprocessors: [
                [
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                ]
            ],
            outtmpl: outputTemplate,
            progress_hooks: [progressHook]
        )
        
        let ydl = yt_dlp.YoutubeDL(ydl_opts)
        
        do {
            let info = await Task {
                ydl.extract_info(url, download: true)
            }.value
            
            guard let id = String(info.id),
                  let ext = String(info.ext) else {
                throw URLError(.badServerResponse)
            }
            
            let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).\(ext)")
            return outputPath
            
        } catch let error as PythonError {
            self.error = error.localizedDescription
            throw error
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
}
