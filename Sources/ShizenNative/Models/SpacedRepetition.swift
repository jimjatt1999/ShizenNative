import Foundation

struct ReviewScheduler {
    // Ease factors
    private static let AGAIN_PENALTY: Double = 0.2
    private static let HARD_PENALTY: Double = 0.15
    private static let EASY_BONUS: Double = 0.15
    
    // Intervals (in days)
    private static let AGAIN_INTERVAL: Double = 1
    private static let LEARNING_STEPS: [TimeInterval] = [1.0, 10.0]  // minutes
    private static let GRADUATING_INTERVAL = 1   // days
    private static let EASY_INTERVAL = 4         // days
    
    struct Card: Codable, Equatable {
        var interval: Double      // Current interval in days
        var ease: Double         // Ease factor (starts at 2.5)
        var reviews: Int         // Number of reviews
        var lapses: Int          // Number of times card went back to learning
        var state: State         // Current learning state
        var dueDate: Date        // Next review date
        
        enum State: String, Codable {
            case new
            case learning
            case review
            case relearning
        }
        
        init() {
            self.interval = 0
            self.ease = 2.5
            self.reviews = 0
            self.lapses = 0
            self.state = .new
            self.dueDate = Date()
        }
    }
    static func processReview(card: inout Card, response: String) -> Date {
        switch response {
        case "again":
            return processAgain(&card)
        case "hard":
            return processHard(&card)
        case "good":
            return processGood(&card)
        case "easy":
            return processEasy(&card)
        default:
            return card.dueDate
        }
    }
    
    private static func processAgain(_ card: inout Card) -> Date {
        card.lapses += 1
        card.ease = max(1.3, card.ease - AGAIN_PENALTY)
        
        switch card.state {
        case .new, .learning:
            card.state = .learning
            return Date().addingTimeInterval(LEARNING_STEPS[0] * 60.0)
        case .review, .relearning:
            card.state = .relearning
            card.interval = AGAIN_INTERVAL
            return Calendar.current.date(byAdding: .day, value: Int(AGAIN_INTERVAL), to: Date())!
        }
    }
    
    private static func processHard(_ card: inout Card) -> Date {
        card.ease = max(1.3, card.ease - HARD_PENALTY)
        
        switch card.state {
        case .new, .learning:
            card.state = .learning
            return Date().addingTimeInterval(LEARNING_STEPS[1] * 60.0)
        case .review, .relearning:
            card.interval *= 1.2
            return Calendar.current.date(byAdding: .day, value: Int(card.interval), to: Date())!
        }
    }
    
    private static func processGood(_ card: inout Card) -> Date {
        switch card.state {
        case .new:
            card.state = .learning
            return Date().addingTimeInterval(LEARNING_STEPS[0] * 60.0)
        case .learning:
            card.state = .review
            card.interval = Double(GRADUATING_INTERVAL)
            return Calendar.current.date(byAdding: .day, value: GRADUATING_INTERVAL, to: Date())!
        case .review, .relearning:
            card.interval *= card.ease
            return Calendar.current.date(byAdding: .day, value: Int(card.interval), to: Date())!
        }
    }
    
    private static func processEasy(_ card: inout Card) -> Date {
        card.ease = min(3.0, card.ease + EASY_BONUS)
        
        switch card.state {
        case .new, .learning, .relearning:
            card.state = .review
            card.interval = Double(EASY_INTERVAL)
            return Calendar.current.date(byAdding: .day, value: EASY_INTERVAL, to: Date())!
        case .review:
            card.interval *= (card.ease * 1.3)
            return Calendar.current.date(byAdding: .day, value: Int(card.interval), to: Date())!
        }
    }
}
