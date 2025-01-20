import SwiftUI

enum ReviewStatus: Equatable {
    case new
    case due
    case scheduled(date: Date)
    
    static func == (lhs: ReviewStatus, rhs: ReviewStatus) -> Bool {
        switch (lhs, rhs) {
        case (.new, .new): return true
        case (.due, .due): return true
        case (.scheduled(let date1), .scheduled(let date2)):
            return Calendar.current.isDate(date1, inSameDayAs: date2)
        default: return false
        }
    }
    
    var color: Color {
        switch self {
        case .new: return .blue
        case .due: return .orange
        case .scheduled: return .green
        }
    }
    
    var text: String {
        switch self {
        case .new: return "New"
        case .due: return "Due"
        case .scheduled(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

struct ReviewStatusBadge: View {
    let status: ReviewStatus
    
    var body: some View {
        Text(status.text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.1))
            .foregroundColor(status.color)
            .cornerRadius(4)
    }
}
