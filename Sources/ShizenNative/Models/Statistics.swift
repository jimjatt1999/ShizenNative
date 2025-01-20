import Foundation

@MainActor
final class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()
    private let statsKey = "userStatistics"
    
    @Published private(set) var totalReviews: Int = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var accuracy: Double = 0.0
    @Published private(set) var newCards: Int = 0
    @Published private(set) var studyTime: TimeInterval = 0
    @Published private(set) var responseDistribution: [String: Int] = [
        "again": 0,
        "hard": 0,
        "good": 0,
        "easy": 0
    ]
    
    private var lastReviewDate: Date?
    private var sessionStartTime: Date?
    private var timer: Timer?
    
    private init() {
        print("[Stats] Initializing singleton")
        loadStats()
        setupNotifications()
        startSession()
    }
    
    private func setupNotifications() {
        DispatchQueue.main.async {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleReviewNotification(_:)),
                name: .reviewCompleted,
                object: nil
            )
        }
    }
    
    @objc private func handleReviewNotification(_ notification: Notification) {
        Task { @MainActor in
            guard let response = notification.userInfo?["response"] as? String,
                  let isNewCard = notification.userInfo?["isNewCard"] as? Bool else {
                print("[Stats] Invalid notification data")
                return
            }
            
            print("[Stats] Processing review: \(response)")
            await processReview(response: response, isNewCard: isNewCard)
        }
    }
    
    private func processReview(response: String, isNewCard: Bool) async {
        totalReviews += 1
        
        if isNewCard {
            newCards += 1
        }
        
        responseDistribution[response, default: 0] += 1
        
        let totalResponses = responseDistribution.values.reduce(0, +)
        let correctResponses = (responseDistribution["good"] ?? 0) + (responseDistribution["easy"] ?? 0)
        accuracy = totalResponses > 0 ? (Double(correctResponses) / Double(totalResponses)) * 100 : 0
        
        updateStreak()
        saveStats()
        objectWillChange.send()
    }
    
    private func startSession() {
        sessionStartTime = Date()
        
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateStudyTime()
                }
            }
        }
    }
    
    private func updateStudyTime() {
        if let startTime = sessionStartTime {
            studyTime = Date().timeIntervalSince(startTime)
            saveStats()
            objectWillChange.send()
        }
    }
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = Date()
        
        if let lastDate = lastReviewDate {
            if calendar.isDate(lastDate, inSameDayAs: today) {
                print("[Stats] Same day review")
            } else if calendar.isDate(lastDate, equalTo: calendar.date(byAdding: .day, value: -1, to: today)!, toGranularity: .day) {
                currentStreak += 1
                print("[Stats] Streak increased: \(currentStreak)")
            } else {
                currentStreak = 1
                print("[Stats] Streak reset")
            }
        } else {
            currentStreak = 1
            print("[Stats] First review")
        }
        
        lastReviewDate = today
    }
    
    private func saveStats() {
        let stats: [String: Any] = [
            "totalReviews": totalReviews,
            "currentStreak": currentStreak,
            "accuracy": accuracy,
            "newCards": newCards,
            "studyTime": studyTime,
            "responseDistribution": responseDistribution,
            "lastReviewDate": lastReviewDate ?? Date()
        ]
        
        UserDefaults.standard.set(stats, forKey: statsKey)
        UserDefaults.standard.synchronize()
    }
    
    private func loadStats() {
        guard let stats = UserDefaults.standard.dictionary(forKey: statsKey) else {
            print("[Stats] No saved stats found")
            return
        }
        
        totalReviews = stats["totalReviews"] as? Int ?? 0
        currentStreak = stats["currentStreak"] as? Int ?? 0
        accuracy = stats["accuracy"] as? Double ?? 0
        newCards = stats["newCards"] as? Int ?? 0
        studyTime = stats["studyTime"] as? TimeInterval ?? 0
        responseDistribution = stats["responseDistribution"] as? [String: Int] ?? [:]
        lastReviewDate = stats["lastReviewDate"] as? Date
    }
    
    func resetStats() async {
        // Simulate some async work
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        totalReviews = 0
        currentStreak = 0
        accuracy = 0
        newCards = 0
        studyTime = 0
        responseDistribution = ["again": 0, "hard": 0, "good": 0, "easy": 0]
        lastReviewDate = nil
        sessionStartTime = Date()
        
        saveStats()
        objectWillChange.send()
        
        print("[Stats] Reset complete")
    }
    
    deinit {
        timer?.invalidate()
        print("[Stats] Deinit")
    }
}
