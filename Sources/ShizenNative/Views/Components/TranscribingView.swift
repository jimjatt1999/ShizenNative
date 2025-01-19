import SwiftUI

struct TranscribingView: View {
    let progress: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Processing Audio...")
                .font(.headline)
            
            Text(progress)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
    }
}
