import SwiftUI

struct SettingsView: View {
    @Binding var blockedStatus: Int
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Bad Apps Status")
                    Spacer()
                    Text(blockedStatus == 1 ? "BLOCKED" : "NOT BLOCKED")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(blockedStatus == 1 ? .red : .green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(blockedStatus == 1 ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        )
                }
            } header: {
                Text("Screen Time")
            } footer: {
                Text("Nudge controls whether distracting apps are blocked based on your conversation.")
            }
            
            Section {
                Text("More settings coming soon...")
                    .foregroundStyle(.secondary)
            } header: {
                Text("General")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView(blockedStatus: .constant(1))
    }
}
