import SwiftUI

@main
struct ShizenNativeApp: App {
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
