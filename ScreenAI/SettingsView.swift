import SwiftUI

struct SettingsView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var isSigningOut = false
    
    var body: some View {
        Form {
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
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
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
        SettingsView()
    }
}
