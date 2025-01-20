import SwiftUI

struct StatsView: View {
    @StateObject private var stats = StatisticsManager.shared
    @ObservedObject var reviewState: ReviewState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    StatBox(
                        title: "Reviews",
                        value: "\(stats.totalReviews)",
                        icon: "clock.fill",
                        color: .blue
                    )
                    
                    StatBox(
                        title: "Current Streak",
                        value: "\(stats.currentStreak) days",
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    StatBox(
                        title: "Accuracy",
                        value: String(format: "%.1f%%", stats.accuracy),
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatBox(
                        title: "New Cards",
                        value: "\(stats.newCards)",
                        icon: "star.fill",
                        color: .purple
                    )
                }
                .padding()
                
                // Response Distribution
                VStack(alignment: .leading, spacing: 10) {
                    Text("Response Distribution")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ForEach(["again", "hard", "good", "easy"], id: \.self) { response in
                        ResponseBar(
                            label: response.capitalized,
                            count: stats.responseDistribution[response] ?? 0,
                            total: stats.totalReviews,
                            color: responseColor(for: response)
                        )
                    }
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(10)
                
                // Study Time
                VStack(alignment: .leading) {
                    Text("Study Time")
                        .font(.headline)
                    Text(formatTime(stats.studyTime))
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Statistics")
    }
    
    private func responseColor(for response: String) -> Color {
        switch response {
        case "again": return .red
        case "hard": return .orange
        case "good": return .green
        case "easy": return .blue
        default: return .gray
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .foregroundColor(.secondary)
                .font(.caption)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ResponseBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(count)")
                    .foregroundColor(color)
            }
            .font(.caption)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage))
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

struct StudyTimeChart: View {
    let data: [(hour: Int, duration: TimeInterval)]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data, id: \.hour) { item in
                    VStack {
                        let height = getHeight(for: item.duration, in: geometry)
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(height: height)
                        
                        Text("\(item.hour)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: (geometry.size.width - CGFloat(data.count) * 4) / CGFloat(data.count))
                }
            }
        }
    }
    
    private func getHeight(for duration: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
        let maxDuration = data.map(\.duration).max() ?? 1
        return (CGFloat(duration) / CGFloat(maxDuration)) * (geometry.size.height - 20)
    }
}

struct TimeDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
        .font(.subheadline)
    }
}

#Preview {
    StatsView(reviewState: ReviewState(settings: AppSettings()))
}
