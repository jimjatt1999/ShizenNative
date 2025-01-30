import Foundation

class ReviewState: ObservableObject {
    @Published var reviewCards: [String: ReviewScheduler.Card]
    @Published var userNotes: [String: UserNote]
    @Published var todayNewCards: Int
    @Published var currentIndex: Int
    @Published var segments: [Segment] = []
    @Published var audioFiles: [String: URL] = [:]
    
    // Make these @Published computed properties
    @Published private(set) var dueCount: Int = 0
    @Published private(set) var newCount: Int = 0
    
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
        
        // Load user notes
        if let data = UserDefaults.standard.data(forKey: "userNotes"),
           let notes = try? JSONDecoder().decode([String: UserNote].self, from: data) {
            self.userNotes = notes
        } else {
            self.userNotes = [:]
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
        
        // Save user notes
        if let encoded = try? JSONEncoder().encode(userNotes) {
            UserDefaults.standard.set(encoded, forKey: "userNotes")
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
    
    func saveNote(_ note: UserNote, for segmentId: String) {
        userNotes[segmentId] = note
        save()
    }
    
    func removeNote(for segmentId: String) {
        userNotes.removeValue(forKey: segmentId)
        save()
    }
    
    func getNote(for segmentId: String) -> UserNote? {
        return userNotes[segmentId]
    }
    
    var learningCount: Int {
        reviewCards.values.filter { card in 
            // Cards in learning phase have interval = 0 and have been seen
            card.interval == 0 && card.dueDate != .distantFuture
        }.count
    }
    
    func updateCounts() {
        dueCount = reviewCards.values.filter { card in
            card.interval > 0 && 
            card.dueDate <= Date()
        }.count
        
        newCount = reviewCards.values.filter { card in
            card.dueDate == .distantFuture
        }.count
        
        objectWillChange.send()
    }
    
    // Call updateCounts() whenever cards are modified
    func updateCard(_ id: String, with response: String) {
        // ... existing update logic ...
        updateCounts()
    }
    
    func addSegment(_ segment: Segment) {
        segments.append(segment)
        objectWillChange.send()
    }
    
    func addAudioFile(_ url: URL, for segmentId: String) {
        audioFiles[segmentId] = url
        objectWillChange.send()
    }
}
