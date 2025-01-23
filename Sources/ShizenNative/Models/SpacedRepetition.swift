import Foundation

struct ReviewScheduler {
    // Ease factors
    private static let AGAIN_PENALTY: Double = 0.2
    private static let HARD_PENALTY: Double = 0.15
    private static let EASY_BONUS: Double = 0.15
    
    // Default values to use when settings aren't available
    private static let DEFAULT_LEARNING_STEPS = LearningSteps(
        steps: [1.0, 10.0],
        againStep: 1.0,
        graduatingInterval: 1,
        easyInterval: 4,
        startingEase: 2.5
    )
    
    // Use UserDefaults directly instead of AppSettings
    private static func getLearningSteps() -> LearningSteps {
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            return settings.learningSteps
        }
        return DEFAULT_LEARNING_STEPS
    }
    
    struct Card: Codable, Equatable {
        var interval: Double      // Current interval in days
        var ease: Double         // Ease factor (starts at 2.5)
        var reviews: Int         // Number of reviews
        var lapses: Int          // Number of times card went back to learning
        var state: State         // Current learning state
        var dueDate: Date        // Next review date
        var step: Int           // Current step in learning phase
        
        enum State: String, Codable {
            case new
            case learning
            case review
            case relearning
        }
        
        init() {
            let steps = ReviewScheduler.getLearningSteps()
            self.interval = 0
            self.ease = steps.startingEase
            self.reviews = 0
            self.lapses = 0
            self.state = .new
            self.dueDate = Date()
            self.step = 0
        }
    }
    
    // Rest of the implementation remains the same...
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
        let steps = getLearningSteps()
        card.step = 0
        
        switch card.state {
        case .new, .learning:
            card.state = .learning
            return Date().addingTimeInterval(steps.againStep * 60)
            
        case .review, .relearning:
            card.lapses += 1
            card.state = .relearning
            card.ease = max(1.3, card.ease - AGAIN_PENALTY)
            return Date().addingTimeInterval(steps.againStep * 60)
        }
    }
    
    private static func processHard(_ card: inout Card) -> Date {
        let steps = getLearningSteps()
        
        switch card.state {
        case .new, .learning:
            // Stay at current step
            if card.step < steps.steps.count {
                return Date().addingTimeInterval(steps.steps[card.step] * 60)
            }
            return Date().addingTimeInterval(steps.steps.last! * 60)
            
        case .review, .relearning:
            card.ease = max(1.3, card.ease - HARD_PENALTY)
            card.interval *= 1.2
            return Calendar.current.date(byAdding: .day, value: Int(card.interval), to: Date())!
        }
    }
    
    private static func processGood(_ card: inout Card) -> Date {
        let steps = getLearningSteps()
        
        switch card.state {
        case .new, .learning:
            if card.step < steps.steps.count - 1 {
                // Move to next learning step
                card.step += 1
                card.state = .learning
                return Date().addingTimeInterval(steps.steps[card.step] * 60)
            } else {
                // Graduate to review
                card.state = .review
                card.interval = Double(steps.graduatingInterval)
                return Calendar.current.date(byAdding: .day, value: steps.graduatingInterval, to: Date())!
            }
            
        case .review:
            card.interval *= card.ease
            return Calendar.current.date(byAdding: .day, value: Int(card.interval), to: Date())!
            
        case .relearning:
            card.state = .review
            return Calendar.current.date(byAdding: .day, value: steps.graduatingInterval, to: Date())!
        }
    }
    
    private static func processEasy(_ card: inout Card) -> Date {
        let steps = getLearningSteps()
        card.ease = min(3.0, card.ease + EASY_BONUS)
        
        switch card.state {
        case .new, .learning, .relearning:
            // Graduate immediately with longer interval
            card.state = .review
            card.interval = Double(steps.easyInterval)
            return Calendar.current.date(byAdding: .day, value: steps.easyInterval, to: Date())!
            
        case .review:
            card.interval *= (card.ease * 1.3)
            return Calendar.current.date(byAdding: .day, value: Int(card.interval), to: Date())!
        }
    }
}
