import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "gearshape")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Design TBD")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
