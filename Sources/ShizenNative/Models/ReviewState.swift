import Foundation

class ReviewState: ObservableObject {
    @Published var reviewCards: [String: ReviewScheduler.Card]
    @Published var todayNewCards: Int
    @Published var currentIndex: Int
    
    private let settings: AppSettings
    
    init(settings: AppSettings) {
        self.settings = settings
        
        // Load review cards
        if let data = UserDefaults.standard.data(forKey: "reviewCards"),
           let cards = try? JSONDecoder().decode([String: ReviewScheduler.Card].self, from: data) {
            self.reviewCards = cards
        } else {
            self.reviewCards = [:]
        }
        
        // Load or reset today's new cards
        if let lastReviewDate = UserDefaults.standard.object(forKey: "lastReviewDate") as? Date,
           Calendar.current.isDate(lastReviewDate, inSameDayAs: Date()) {
            self.todayNewCards = UserDefaults.standard.integer(forKey: "todayNewCards")
        } else {
            self.todayNewCards = 0
            UserDefaults.standard.set(0, forKey: "todayNewCards")
            UserDefaults.standard.set(Date(), forKey: "lastReviewDate")
        }
        
        self.currentIndex = 0
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(reviewCards) {
            UserDefaults.standard.set(encoded, forKey: "reviewCards")
            UserDefaults.standard.set(todayNewCards, forKey: "todayNewCards")
            UserDefaults.standard.set(Date(), forKey: "lastReviewDate")
            UserDefaults.standard.synchronize()
        }
    }
    
    func createBackup() {
        if let encoded = try? JSONEncoder().encode(reviewCards) {
            UserDefaults.standard.set(encoded, forKey: "reviewCards.backup")
        }
        UserDefaults.standard.set(todayNewCards, forKey: "todayNewCards.backup")
        UserDefaults.standard.synchronize()
    }
    
    func restoreFromBackup() {
        if let data = UserDefaults.standard.data(forKey: "reviewCards.backup"),
           let cards = try? JSONDecoder().decode([String: ReviewScheduler.Card].self, from: data) {
            reviewCards = cards
        }
        todayNewCards = UserDefaults.standard.integer(forKey: "todayNewCards.backup")
        save()
    }
}
