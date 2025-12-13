import Foundation

/// Central place to store configuration values for the app.
/// NOTE: Do not commit real secrets to source control. For production, prefer:
/// - Fetching the key from your server and storing it in the Keychain
/// - Using an .xcconfig file excluded from version control
/// - Or proxying requests through your server so the key never ships in the app
struct AppConfig {
    /// OpenAI API key loaded from Info.plist or environment. Do not hard-code secrets.
    static var openAIAPIKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty {
            return key
        }
        // Fallback to environment variable (useful for CI or local runs)
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        #if DEBUG
        print("[AppConfig] Info OPENAI_API_KEY:", (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String).map { AppConfig.mask($0) } ?? "nil")
        print("[AppConfig] Env OPENAI_API_KEY:", ProcessInfo.processInfo.environment["OPENAI_API_KEY"].map { AppConfig.mask($0) } ?? "nil")
        print("[AppConfig] Bundle path:", Bundle.main.bundlePath)
        if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist") {
            print("[AppConfig] Info.plist path:", infoPath)
        } else {
            print("[AppConfig] No physical Info.plist in bundle (synthesized).")
        }
        fatalError("Missing OpenAI API key. Define MY_API_KEY in Secrets.xcconfig and expose it as OPENAI_API_KEY in Info.plist, or set the OPENAI_API_KEY environment variable. See README_SECRET_SETUP.md.")
        #else
        return ""
        #endif
    }

    /// Default OpenAI chat model. You can change this centrally.
    static let openAIModel: String = "gpt-4o-mini"
    
    /// Supabase project URL
    static var supabaseURL: String {
        if let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, !url.isEmpty {
            return url
        }
        if let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"], !envURL.isEmpty {
            return envURL
        }
        #if DEBUG
        fatalError("Missing Supabase URL. Add SUPABASE_URL to Info.plist or environment variables.")
        #else
        return ""
        #endif
    }
    
    /// Supabase anon/public key
    static var supabaseAnonKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !key.isEmpty {
            return key
        }
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !envKey.isEmpty {
            return envKey
        }
        #if DEBUG
        fatalError("Missing Supabase anon key. Add SUPABASE_ANON_KEY to Info.plist or environment variables.")
        #else
        return ""
        #endif
    }

    // Masks a secret for debug logging (shows first/last 4 characters).
    private static func mask(_ value: String) -> String {
        let count = value.count
        guard count > 8 else { return String(repeating: "•", count: count) }
        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        return "\(prefix)••••\(suffix)"
    }
}
