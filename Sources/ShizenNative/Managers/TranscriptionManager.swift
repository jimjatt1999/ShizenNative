import Foundation

class TranscriptionManager: ObservableObject {
    enum TranscriptionError: Error {
        case pythonError(String)
        case scriptNotFound
        case invalidOutput
        case pythonNotFound
    }
    
    private func findPythonPath() throws -> String {
        // Try different possible Python locations
        let possiblePaths = [
            "/opt/anaconda3/bin/python3",
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.9/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3"
        ]
        
        // Use `which python3` command to find Python
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["python3"]
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                print("Found Python at: \(path)")
                return path
            }
        } catch {
            print("Error finding Python with 'which': \(error)")
        }
        
        // Try the possible paths
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("Found Python at: \(path)")
                return path
            }
        }
        
        throw TranscriptionError.pythonNotFound
    }
    
    private func getScriptPath() -> String? {
        // Get the current working directory
        let currentPath = FileManager.default.currentDirectoryPath
        // Construct the path to the Scripts directory
        let scriptPath = (currentPath as NSString).appendingPathComponent("Scripts/transcribe.py")
        
        if FileManager.default.fileExists(atPath: scriptPath) {
            print("Found script at: \(scriptPath)")
            return scriptPath
        }
        
        // Try alternative locations
        let alternativePaths = [
            (currentPath as NSString).deletingLastPathComponent + "/Scripts/transcribe.py",
            Bundle.main.path(forResource: "transcribe", ofType: "py"),
            Bundle.main.path(forResource: "transcribe", ofType: "py", inDirectory: "Scripts")
        ]
        
        for path in alternativePaths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                print("Found script at: \(path)")
                return path
            }
        }
        
        print("Script not found in any location")
        return nil
    }
    
    func transcribe(audioPath: String) async throws -> [Segment] {
        let pythonPath = try findPythonPath()
        print("Using Python at: \(pythonPath)")
        
        guard let scriptPath = getScriptPath() else {
            print("Script not found")
            throw TranscriptionError.scriptNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath, audioPath]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        print("Starting transcription process...")
        print("Command: \(pythonPath) \(scriptPath) \(audioPath)")
        
        do {
            try process.run()
            
            // Read error output asynchronously
            Task {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    print("Progress output: \(errorOutput)")
                }
            }
            
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                throw TranscriptionError.invalidOutput
            }
            
            print("Processing output...")
            
            // Parse JSON output
            guard let jsonData = output.data(using: .utf8),
                  let segments = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                print("Failed to parse JSON: \(output)")
                throw TranscriptionError.invalidOutput
            }
            
            // Convert to segments
            return segments.map { segment in
                Segment(
                    text: segment["text"] as? String ?? "",
                    start: segment["start"] as? Double ?? 0,
                    end: segment["end"] as? Double ?? 0,
                    sourceId: ""  // This will be set later
                )
            }
        } catch {
            print("Process error: \(error)")
            throw error
        }
    }
}
