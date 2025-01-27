import SwiftUI
import UniformTypeIdentifiers

struct UploadPromptView: View {
    @Binding var showingFilePicker: Bool
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Upload Audio")
                .font(.title)
                .foregroundColor(.primary)
            
            VStack(spacing: 20) {
                Image(systemName: "arrow.up.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60)
                    .foregroundColor(.blue)
                
                Text("Drag and drop audio files here")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showingFilePicker = true
                }) {
                    Text("Choose File")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isDragging ? Color.blue : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
            )
            .padding(.horizontal, 40)
            
            Text("Supported: MP3, WAV, M4A")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onDrop(
            of: [UTType.audio],
            delegate: AudioDropDelegate(isDragging: $isDragging, showingFilePicker: $showingFilePicker)
        )
    }
}

struct AudioDropDelegate: DropDelegate {
    @Binding var isDragging: Bool
    @Binding var showingFilePicker: Bool
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.audio])
    }
    
    func dropEntered(info: DropInfo) {
        isDragging = true
    }
    
    func dropExited(info: DropInfo) {
        isDragging = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isDragging = false
        showingFilePicker = true
        return true
    }
}
