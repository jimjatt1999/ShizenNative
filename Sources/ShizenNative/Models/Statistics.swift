import Foundation

struct CurrentStats {
    var reviews: Int = 0
    var newCards: Int = 0
    var accuracy: Double = 0
    var distribution: (again: Int, hard: Int, good: Int, easy: Int, total: Int) = (0, 0, 0, 0, 0)
    var totalStudyTime: TimeInterval = 0
    var averageSessionTime: TimeInterval = 0
    var longestSession: TimeInterval = 0
    var totalSessions: Int = 0
    var studyTimeData: [(hour: Int, duration: TimeInterval)] = []
}

struct StudySession: Codable {
    var date: Date
    var duration: TimeInterval
    var reviews: Int
    var newCards: Int
    var responses: [String: Int]
    
    init(date: Date, duration: TimeInterval = 0, reviews: Int = 0, newCards: Int = 0, responses: [String: Int] = [:]) {
        self.date = date
        self.duration = duration
        self.reviews = reviews
        self.newCards = newCards
        self.responses = responses
    }
}

struct Statistics: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastReviewDate: Date?
    var studySessions: [StudySession] = []
    
    mutating func recordSession(_ session: StudySession) {
        studySessions.append(session)
        updateStreak(date: session.date)
    }
    
    private mutating func updateStreak(date: Date) {
        let calendar = Calendar.current
        if let last = lastReviewDate {
            if calendar.isDate(last, inSameDayAs: date) {
                // Same day, streak continues
            } else if calendar.isDate(last, equalTo: calendar.date(byAdding: .day, value: -1, to: date)!, toGranularity: .day) {
                // Yesterday, streak continues
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                // Streak broken
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        lastReviewDate = date
    }
}

class StatisticsManager: ObservableObject {
    @Published private(set) var stats: Statistics
    @Published private(set) var currentStats = CurrentStats()
    private var currentSession: StudySession?
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "statistics"),
           let loadedStats = try? JSONDecoder().decode(Statistics.self, from: data) {
            self.stats = loadedStats
        } else {
            self.stats = Statistics()
        }
    }
    
    func updateStats(for timeRange: StatsView.TimeRange) {
        let calendar = Calendar.current
        let now = Date()
        
        let filteredSessions: [StudySession]
        switch timeRange {
        case .day:
            filteredSessions = stats.studySessions.filter {
                calendar.isDate($0.date, inSameDayAs: now)
            }
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            filteredSessions = stats.studySessions.filter {
                $0.date >= weekAgo
            }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            filteredSessions = stats.studySessions.filter {
                $0.date >= monthAgo
            }
        case .allTime:
            filteredSessions = stats.studySessions
        }
        
        calculateCurrentStats(from: filteredSessions)
    }
    
    private func calculateCurrentStats(from sessions: [StudySession]) {
        var stats = CurrentStats()
        
        // Calculate totals
        stats.reviews = sessions.reduce(0) { $0 + $1.reviews }
        stats.newCards = sessions.reduce(0) { $0 + $1.newCards }
        stats.totalStudyTime = sessions.reduce(0) { $0 + $1.duration }
        stats.totalSessions = sessions.count
        
        // Calculate averages
        stats.averageSessionTime = stats.totalStudyTime / Double(max(1, stats.totalSessions))
        stats.longestSession = sessions.map(\.duration).max() ?? 0
        
        // Calculate response distribution
        var responses = [String: Int]()
        sessions.forEach { session in
            session.responses.forEach { response in
                responses[response.key, default: 0] += response.value
            }
        }
        
        let total = responses.values.reduce(0, +)
        stats.distribution = (
            again: responses["again"] ?? 0,
            hard: responses["hard"] ?? 0,
            good: responses["good"] ?? 0,
            easy: responses["easy"] ?? 0,
            total: total
        )
        
        // Calculate accuracy
        let correct = (responses["good"] ?? 0) + (responses["easy"] ?? 0)
        stats.accuracy = total > 0 ? (Double(correct) / Double(total)) * 100 : 0
        
        // Calculate study time data
        var hourlyData: [Int: TimeInterval] = [:]
        sessions.forEach { session in
            let hour = Calendar.current.component(.hour, from: session.date)
            hourlyData[hour, default: 0] += session.duration
        }
        
        stats.studyTimeData = (0..<24).map { hour in
            (hour: hour, duration: hourlyData[hour] ?? 0)
        }
        
        currentStats = stats
    }
    
    func beginSession() {
        currentSession = StudySession(date: Date())
    }
    
    func endSession(duration: TimeInterval) {
        guard var session = currentSession else { return }
        session.duration = duration
        stats.recordSession(session)
        save()
        currentSession = nil
    }
    
    func recordReview(response: String, isNewCard: Bool = false) {
        if currentSession == nil {
            beginSession()
        }
        
        if var session = currentSession {
            session.reviews += 1
            if isNewCard {
                session.newCards += 1
            }
            var responses = session.responses
            responses[response, default: 0] += 1
            session.responses = responses
            currentSession = session
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: "statistics")
            UserDefaults.standard.synchronize()
        }
    }
}
