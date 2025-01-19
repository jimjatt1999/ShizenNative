import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @State private var showingResetAlert = false
    @State private var showingConfirmation = false
    @State private var showingNotification = false
    @State private var notificationMessage = ""
    @State private var tempSettings: UserSettings
    @Environment(\.colorScheme) var systemColorScheme
    
    init() {
        _tempSettings = State(initialValue: UserSettings(
            newCardsPerDay: 38,
            cardsPerFeed: 2,
            appearanceMode: .system,
            countFocusModeInSRS: true,
            darkMode: false,
            showTranscriptsByDefault: false
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Review Settings
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Review Settings")
                            .font(.headline)
                        
                        // New cards per day
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New cards per day")
                            HStack {
                                TextField("", value: Binding(
                                    get: { tempSettings.newCardsPerDay },
                                    set: { tempSettings.newCardsPerDay = max(1, min($0, 999)) }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                
                                Stepper("", value: Binding(
                                    get: { tempSettings.newCardsPerDay },
                                    set: { tempSettings.newCardsPerDay = $0 }
                                ), in: 1...999)
                                .labelsHidden()
                            }
                        }
                        
                        // Cards per feed
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cards shown in feed")
                            HStack {
                                TextField("", value: Binding(
                                    get: { tempSettings.cardsPerFeed },
                                    set: { tempSettings.cardsPerFeed = max(1, min($0, 10)) }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                
                                Stepper("", value: Binding(
                                    get: { tempSettings.cardsPerFeed },
                                    set: { tempSettings.cardsPerFeed = $0 }
                                ), in: 1...10)
                                .labelsHidden()
                            }
                            
                            Text("Quick select:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                ForEach([1, 2, 3, 4, 5], id: \.self) { number in
                                    Button("\(number)") {
                                        tempSettings.cardsPerFeed = number
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(tempSettings.cardsPerFeed == number ? .blue : .gray)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // Review Options
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Review Options")
                            .font(.headline)
                        
                        Toggle("Show transcripts by default", isOn: Binding(
                            get: { tempSettings.showTranscriptsByDefault },
                            set: { tempSettings.showTranscriptsByDefault = $0 }
                        ))
                        
                        Text("You can still toggle individual transcripts with the eye button")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Focus Mode
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Focus Mode")
                            .font(.headline)
                        
                        Toggle("Count Focus Mode in SRS", isOn: Binding(
                            get: { tempSettings.countFocusModeInSRS },
                            set: { tempSettings.countFocusModeInSRS = $0 }
                        ))
                    }
                    .padding()
                }
                
                // Appearance
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance")
                            .font(.headline)
                        
                        Picker("Theme", selection: Binding(
                            get: { tempSettings.appearanceMode },
                            set: { tempSettings.appearanceMode = $0 }
                        )) {
                            Label("System", systemImage: "circle.lefthalf.filled")
                                .tag(AppearanceMode.system)
                            Label("Light", systemImage: "sun.max.fill")
                                .tag(AppearanceMode.light)
                            Label("Dark", systemImage: "moon.fill")
                                .tag(AppearanceMode.dark)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        
                        if tempSettings.appearanceMode == .system {
                            Text("Following system appearance (\(systemColorScheme == .dark ? "dark" : "light") mode)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                // Data Management
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Management")
                            .font(.headline)
                        
                        Button(action: {
                            tempSettings = .default
                            settings.resetToDefaults()
                            forceRefresh()
                            showFeedback("Settings have been restored to defaults")
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("Reset All Settings")
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            showingResetAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                Text("Reset Progress & Statistics")
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                
                // Apply Button
                Button("Apply Settings") {
                    showingConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Settings")
        .frame(minWidth: 400, minHeight: 600)
        .overlay(
            Group {
                if showingNotification {
                    VStack {
                        Text(notificationMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)
                }
            }
            .animation(.easeInOut, value: showingNotification)
        )
        .alert("Reset Progress & Statistics", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSRSProgress()
            }
        } message: {
            Text("This will reset all review progress and statistics. This action cannot be undone.")
        }
        .alert("Apply Settings", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Apply", role: .destructive) {
                settings.settings = tempSettings
                settings.save()
                forceRefresh()
                showFeedback("Settings have been updated")
            }
        } message: {
            Text("Apply these settings? This will refresh your current review session.")
        }
        .onAppear {
            tempSettings = settings.settings
        }
    }
    
    private func showFeedback(_ message: String) {
        notificationMessage = message
        showingNotification = true
        
        // Hide the notification after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingNotification = false
            }
        }
    }
    
    private func forceRefresh() {
        NotificationCenter.default.post(
            name: .settingsChanged,
            object: nil,
            userInfo: ["stopAudio": true]
        )
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .settingsChanged,
                object: nil,
                userInfo: ["refresh": true]
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: .settingsChanged,
                object: nil,
                userInfo: ["refresh": true]
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .settingsChanged,
                object: nil,
                userInfo: ["hardRefresh": true]
            )
        }
    }
    
    private func resetSRSProgress() {
        // Reset SRS progress
        UserDefaults.standard.removeObject(forKey: "reviewCards")
        UserDefaults.standard.removeObject(forKey: "todayNewCards")
        UserDefaults.standard.removeObject(forKey: "lastReviewDate")
        
        // Reset statistics
        UserDefaults.standard.removeObject(forKey: "statistics")
        
        // Update UI
        NotificationCenter.default.post(
            name: .reviewProgressReset,
            object: nil
        )
        
        // Show feedback
        showFeedback("Progress and statistics have been reset")
        
        // Force refresh views
        forceRefresh()
    }
}
