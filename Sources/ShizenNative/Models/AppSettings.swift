import SwiftUI

enum AppearanceMode: String, Codable, Equatable, CaseIterable {
    case system
    case light
    case dark
}

struct LearningSteps: Codable, Equatable {
    var steps: [Double]  // in minutes
    var againStep: Double
    var graduatingInterval: Int  // in days
    var easyInterval: Int      // in days
    var startingEase: Double
    
    static var `default`: LearningSteps {
        LearningSteps(
            steps: [1.0, 10.0],
            againStep: 1.0,
            graduatingInterval: 1,
            easyInterval: 4,
            startingEase: 2.5
        )
    }
}

struct UserSettings: Codable, Equatable {
    var newCardsPerDay: Int
    var cardsPerFeed: Int
    var appearanceMode: AppearanceMode
    var countFocusModeInSRS: Bool
    var darkMode: Bool
    var showTranscriptsByDefault: Bool
    var learningSteps: LearningSteps
    
    static var `default`: UserSettings {
        UserSettings(
            newCardsPerDay: 38,
            cardsPerFeed: 2,
            appearanceMode: .system,
            countFocusModeInSRS: true,
            darkMode: false,
            showTranscriptsByDefault: false,
            learningSteps: .default
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
