import Foundation
import Supabase

/// Service for interacting with Supabase backend
@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    
    private init() {
        // Initialize Supabase client
        let urlString = AppConfig.supabaseURL
        #if DEBUG
        print("[SupabaseService] URL string: '\(urlString)'")
        print("[SupabaseService] URL string length: \(urlString.count)")
        if let url = URL(string: urlString) {
            print("[SupabaseService] Parsed URL host: \(url.host ?? "nil")")
        } else {
            print("[SupabaseService] Failed to parse URL!")
        }
        #endif
        
        guard let supabaseURL = URL(string: urlString), supabaseURL.host != nil else {
            fatalError("Invalid Supabase URL: '\(urlString)'. Make sure SUPABASE_URL is set correctly in Secrets.xcconfig")
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    /// Check if user has an active session
    func checkSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    /// Sign up a new user
    func signUp(email: String, password: String, username: String? = nil) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "username": .string(username ?? "user_\(UUID().uuidString.prefix(8))"),
                "display_name": .string(username ?? "User")
            ]
        )
        
        await checkSession()
        return response.user
    }
    
    /// Sign in an existing user
    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(email: email, password: password)
        
        await checkSession()
        return response.user
    }
    
    /// Sign out the current user
    func signOut() async throws {
        try await client.auth.signOut()
        await checkSession()
    }
    
    /// Get current user's profile
    func getProfile() async throws -> Profile? {
        guard let userId = currentUser?.id else { return nil }
        
        let response: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    /// Update user profile
    func updateProfile(username: String?, displayName: String?) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updates: [String: AnyJSON] = [:]
        if let username = username {
            updates["username"] = .string(username)
        }
        if let displayName = displayName {
            updates["display_name"] = .string(displayName)
        }
        updates["updated_at"] = .string(ISO8601DateFormatter().string(from: Date()))
        
        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId)
            .execute()
    }
}

// MARK: - Database Models

struct Profile: Codable {
    let id: UUID
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Conversation: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String?
    let metadata: [String: AnyJSON]?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Message: Codable, Identifiable {
    let id: UUID
    let conversationId: UUID
    let role: String
    let content: String
    let functionCall: [String: AnyJSON]?
    let functionName: String?
    let sequenceOrder: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case functionCall = "function_call"
        case functionName = "function_name"
        case sequenceOrder = "sequence_order"
        case createdAt = "created_at"
    }
}

