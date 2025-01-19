import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let settingsKey = "settings"
    private let reviewCardsKey = "reviewCards"
    private let todayNewCardsKey = "todayNewCards"
    private let lastReviewDateKey = "lastReviewDate"
    private let statisticsKey = "statistics"
    
    private init() {}
    
    func resetAll() {
        // Reset settings
        UserDefaults.standard.removeObject(forKey: settingsKey)
        
        // Reset SRS progress
        UserDefaults.standard.removeObject(forKey: reviewCardsKey)
        UserDefaults.standard.removeObject(forKey: todayNewCardsKey)
        UserDefaults.standard.removeObject(forKey: lastReviewDateKey)
        
        // Reset statistics
        UserDefaults.standard.removeObject(forKey: statisticsKey)
        
        // Synchronize changes
        UserDefaults.standard.synchronize()
        
        // Post notifications
        NotificationCenter.default.post(name: .settingsReset, object: nil)
        NotificationCenter.default.post(name: .reviewProgressReset, object: nil)
        NotificationCenter.default.post(name: .statisticsReset, object: nil)
    }
    
    func resetProgress() {
        // Reset SRS progress
        UserDefaults.standard.removeObject(forKey: reviewCardsKey)
        UserDefaults.standard.removeObject(forKey: todayNewCardsKey)
        UserDefaults.standard.removeObject(forKey: lastReviewDateKey)
        
        // Reset statistics
        UserDefaults.standard.removeObject(forKey: statisticsKey)
        
        // Synchronize changes
        UserDefaults.standard.synchronize()
        
        // Post notifications
        NotificationCenter.default.post(name: .reviewProgressReset, object: nil)
        NotificationCenter.default.post(name: .statisticsReset, object: nil)
    }
    
    func exportSettings() -> Data? {
        let settings = UserDefaults.standard.dictionaryRepresentation()
        return try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
    }
    
    func importSettings(from data: Data) throws {
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SettingsError.invalidData
        }
        
        for (key, value) in settings {
            UserDefaults.standard.set(value, forKey: key)
        }
        
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

enum SettingsError: Error {
    case invalidData
    case importFailed
}
