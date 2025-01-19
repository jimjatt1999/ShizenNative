import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        GroupBox(title) {
            content
                .padding()
        }
    }
}

struct SettingsRow: View {
    let title: String
    let detail: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(detail)
                .bold()
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsNumberField: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var value: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                TextField("", value: $value, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                
                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
        }
    }
}
