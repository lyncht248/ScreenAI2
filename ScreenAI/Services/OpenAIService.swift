import Foundation
import Supabase

/// Service for proxying OpenAI API requests through Supabase Edge Function
@MainActor
class OpenAIService: ObservableObject {
    private let supabase = SupabaseService.shared.client
    
    /// Send a chat completion request through the Edge Function proxy
    func completeChat(
        messages: [[String: Any]],
        model: String = "gpt-4o-mini",
        temperature: Double = 0.7,
        functions: [[String: Any]]? = nil
    ) async throws -> [String: Any] {
        guard SupabaseService.shared.isAuthenticated else {
            throw OpenAIServiceError.notAuthenticated
        }
        
        var requestBody: [String: Any] = [
            "messages": messages,
            "model": model,
            "temperature": temperature
        ]
        
        if let functions = functions {
            requestBody["functions"] = functions
        }
        
        // Call the Edge Function
        let response = try await supabase.functions.invoke(
            "openai-chat",
            options: FunctionInvokeOptions(
                body: requestBody,
                headers: [:]
            )
        )
        
        guard let data = response.data else {
            throw OpenAIServiceError.noData
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIServiceError.invalidResponse
        }
        
        // Check for errors in the response
        if let error = json["error"] as? [String: Any] ?? json["error"] as? String {
            throw OpenAIServiceError.apiError(error: error)
        }
        
        return json
    }
}

enum OpenAIServiceError: LocalizedError {
    case notAuthenticated
    case noData
    case invalidResponse
    case apiError(error: Any)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use this feature"
        case .noData:
            return "No data received from server"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let error):
            if let errorDict = error as? [String: Any],
               let message = errorDict["message"] as? String {
                return "API error: \(message)"
            } else if let errorString = error as? String {
                return "API error: \(errorString)"
            }
            return "API error occurred"
        }
    }
}

