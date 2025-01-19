import SwiftUI

enum AppearanceMode: String, Codable, Equatable, CaseIterable {
    case system
    case light
    case dark
}

struct UserSettings: Codable, Equatable {
    var newCardsPerDay: Int
    var cardsPerFeed: Int
    var appearanceMode: AppearanceMode
    var countFocusModeInSRS: Bool
    var darkMode: Bool
    var showTranscriptsByDefault: Bool
    
    static var `default`: UserSettings {
        UserSettings(
            newCardsPerDay: 38,
            cardsPerFeed: 2,
            appearanceMode: .system,
            countFocusModeInSRS: true,
            darkMode: false,
            showTranscriptsByDefault: false
        )
    }
}

@MainActor
class AppSettings: ObservableObject {
    @Published var settings: UserSettings {
        didSet {
            save()
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settings = settings
        } else {
            self.settings = .default
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "settings")
            UserDefaults.standard.synchronize()
        }
    }
    
    func resetToDefaults() {
        settings = .default
        save()
    }
}
