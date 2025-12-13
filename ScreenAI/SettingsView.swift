import SwiftUI

struct SettingsView: View {
    @Binding var blockedStatus: Int
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var isSigningOut = false
    
    var body: some View {
        Form {
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
                .listRowBackground(Color.oatLighter)
            } header: {
                Text("Screen Time")
            } footer: {
                Text("Nudge controls whether distracting apps are blocked based on your conversation.")
            }
            
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.oatLighter)
                } else if let profile = profile {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName ?? profile.username ?? "User")
                                .font(.headline)
                            if let email = supabaseService.currentUser?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.oatLighter)
                }
            } header: {
                Text("Profile")
            }
            
            Section {
                Button(role: .destructive) {
                    Task {
                        await signOut()
                    }
                } label: {
                    HStack {
                        if isSigningOut {
                            ProgressView()
                        } else {
                            Text("Sign Out")
                        }
                    }
                }
                .disabled(isSigningOut)
                .listRowBackground(Color.oatLighter)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.oatBackground)
        .task {
            await loadProfile()
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            profile = try await supabaseService.getProfile()
        } catch {
            print("Error loading profile: \(error)")
        }
    }
    
    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        
        do {
            try await supabaseService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(blockedStatus: .constant(1))
    }
}
