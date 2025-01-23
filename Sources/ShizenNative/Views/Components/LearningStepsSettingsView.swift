import SwiftUI

struct LearningStepsSettingsView: View {
    @Binding var learningSteps: LearningSteps
    @State private var stepsText: String
    @State private var showingHelp = false
    
    init(learningSteps: Binding<LearningSteps>) {
        self._learningSteps = learningSteps
        self._stepsText = State(initialValue: learningSteps.wrappedValue.steps.map { String($0) }.joined(separator: " "))
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Learning Steps")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                // Learning steps
                VStack(alignment: .leading, spacing: 4) {
                    Text("Steps (minutes)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("1 10", text: $stepsText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: stepsText) { newValue in
                            parseSteps(newValue)
                        }
                    
                    Text("Space-separated numbers (e.g., \"1 10\" for 1min, 10min)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Again step
                VStack(alignment: .leading, spacing: 4) {
                    Text("'Again' interval (minutes)")
                    HStack {
                        TextField("", value: $learningSteps.againStep, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Stepper("", value: $learningSteps.againStep, in: 1...60)
                            .labelsHidden()
                    }
                }
                
                // Graduating interval
                VStack(alignment: .leading, spacing: 4) {
                    Text("Graduating interval (days)")
                    HStack {
                        TextField("", value: $learningSteps.graduatingInterval, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Stepper("", value: $learningSteps.graduatingInterval, in: 1...30)
                            .labelsHidden()
                    }
                }
                
                // Easy interval
                VStack(alignment: .leading, spacing: 4) {
                    Text("'Easy' interval (days)")
                    HStack {
                        TextField("", value: $learningSteps.easyInterval, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Stepper("", value: $learningSteps.easyInterval, in: 1...30)
                            .labelsHidden()
                    }
                }
                
                // Starting ease
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starting ease")
                    HStack {
                        TextField("", value: $learningSteps.startingEase, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Stepper("", value: $learningSteps.startingEase, in: 1.3...3.0, step: 0.1)
                            .labelsHidden()
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingHelp) {
            SRSHelpView(isPresented: $showingHelp)
        }
    }
    
    private func parseSteps(_ input: String) {
        let components = input.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        let newSteps = components.compactMap { Double($0) }
        if !newSteps.isEmpty {
            learningSteps.steps = newSteps
        }
    }
}

struct SRSHelpView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Spaced Repetition System (SRS)")
                            .font(.title)
                            .bold()
                        
                        Text("Learning Steps")
                            .font(.headline)
                        Text("When you first learn a card, it goes through learning steps. For example, with steps \"1 10\", selecting \"Good\" shows the card again in 1 minute, then 10 minutes. After completing all steps, the card graduates to review.")
                        
                        Text("'Again' Button")
                            .font(.headline)
                        Text("If you select 'Again', the card returns to the first step. The 'Again interval' determines how soon you'll see it.")
                        
                        Text("Graduating & Easy")
                            .font(.headline)
                        Text("After completing learning steps, cards graduate to review with the 'Graduating interval'. Selecting 'Easy' skips remaining steps and uses the 'Easy interval'.")
                        
                        Text("Starting Ease")
                            .font(.headline)
                        Text("The ease factor determines how quickly intervals increase. Higher values mean larger increases between reviews.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .frame(width: 500, height: 400)
            
            // Close button with "Close" text, centered
            VStack {
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Text("Close")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(5)
                }
                .padding(.bottom, 10)
            }
        }
    }
}