import Foundation

@MainActor
class SettingsManager {
    static let shared = SettingsManager()
    
    private let settingsKey = "settings"
    private let reviewCardsKey = "reviewCards"
    private let todayNewCardsKey = "todayNewCards"
    private let lastReviewDateKey = "lastReviewDate"
    private let statisticsKey = "statistics"
    
    private init() {}
    
    func resetAll() async {
        print("[Settings] Resetting all settings and progress")
        
        // Reset settings
        UserDefaults.standard.removeObject(forKey: settingsKey)
        
        // Reset SRS progress
        UserDefaults.standard.removeObject(forKey: reviewCardsKey)
        UserDefaults.standard.removeObject(forKey: todayNewCardsKey)
        UserDefaults.standard.removeObject(forKey: lastReviewDateKey)
        
        // Reset statistics
        UserDefaults.standard.removeObject(forKey: statisticsKey)
        await StatisticsManager.shared.resetStats()
        
        // Synchronize changes
        UserDefaults.standard.synchronize()
        
        // Post notifications
        NotificationCenter.default.post(name: .settingsReset, object: nil)
        NotificationCenter.default.post(name: .reviewProgressReset, object: nil)
        NotificationCenter.default.post(name: .statisticsReset, object: nil)
    }
    
    func resetProgress() async {
        print("[Settings] Resetting progress and statistics")
        
        // Reset SRS progress
        UserDefaults.standard.removeObject(forKey: reviewCardsKey)
        UserDefaults.standard.removeObject(forKey: todayNewCardsKey)
        UserDefaults.standard.removeObject(forKey: lastReviewDateKey)
        
        // Reset statistics
        UserDefaults.standard.removeObject(forKey: statisticsKey)
        await StatisticsManager.shared.resetStats()
        
        // Synchronize changes
        UserDefaults.standard.synchronize()
        
        // Post notifications
        NotificationCenter.default.post(name: .reviewProgressReset, object: nil)
        NotificationCenter.default.post(name: .statisticsReset, object: nil)
    }
}
