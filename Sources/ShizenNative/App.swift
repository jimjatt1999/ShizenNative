import SwiftUI
import Speech

@main
struct ShizenNativeApp: App {
    init() {
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1024, minHeight: 768)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.styleMask.insert(.resizable)
                        window.setContentSize(NSSize(width: 1024, height: 768))
                    }
                }
        }
    }
}
