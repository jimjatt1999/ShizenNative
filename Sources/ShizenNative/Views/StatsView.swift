import SwiftUI

struct StatsView: View {
    @StateObject private var statsManager = StatisticsManager()
    @State private var selectedTimeRange = TimeRange.day
    
    enum TimeRange: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Time range selector
                HStack {
                    Text("Time Range")
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTimeRange) { _ in
                        statsManager.updateStats(for: selectedTimeRange)
                    }
                }
                .padding(.horizontal)
                
                // Main stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    StatBox(
                        title: "Reviews",
                        value: "\(statsManager.currentStats.reviews)",
                        icon: "clock.fill",
                        color: .blue
                    )
                    
                    StatBox(
                        title: "Streak",
                        value: "\(statsManager.stats.currentStreak) days",
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    StatBox(
                        title: "Accuracy",
                        value: String(format: "%.1f%%", statsManager.currentStats.accuracy),
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatBox(
                        title: "New Cards",
                        value: "\(statsManager.currentStats.newCards)",
                        icon: "star.fill",
                        color: .purple
                    )
                }
                .padding()
                
                // Response distribution
                VStack(alignment: .leading, spacing: 15) {
                    Text("Response Distribution")
                        .font(.headline)
                    
                    let distribution = statsManager.currentStats.distribution
                    ResponseBar(label: "Again", count: distribution.again, total: distribution.total, color: .red)
                    ResponseBar(label: "Hard", count: distribution.hard, total: distribution.total, color: .orange)
                    ResponseBar(label: "Good", count: distribution.good, total: distribution.total, color: .green)
                    ResponseBar(label: "Easy", count: distribution.easy, total: distribution.total, color: .blue)
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Study time
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Study Time")
                            .font(.headline)
                        Spacer()
                        Text(formatStudyTime(statsManager.currentStats.totalStudyTime))
                            .foregroundColor(.secondary)
                    }
                    
                    // Study time chart
                    StudyTimeChart(data: statsManager.currentStats.studyTimeData)
                        .frame(height: 200)
                    
                    // Time details
                    VStack(alignment: .leading, spacing: 8) {
                        TimeDetailRow(
                            label: "Average Session",
                            value: formatStudyTime(statsManager.currentStats.averageSessionTime)
                        )
                        TimeDetailRow(
                            label: "Longest Session",
                            value: formatStudyTime(statsManager.currentStats.longestSession)
                        )
                        TimeDetailRow(
                            label: "Total Sessions",
                            value: "\(statsManager.currentStats.totalSessions)"
                        )
                    }
                    .padding(.top, 10)
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Statistics")
        .onAppear {
            statsManager.updateStats(for: selectedTimeRange)
        }
    }
    
    private func formatStudyTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
