import Foundation
import Supabase

// MARK: - Request/Response types for Edge Function

struct ChatCompletionRequest: Encodable {
    let messages: [ChatMessagePayload]
    let model: String
    let temperature: Double
    let tools: [ToolPayload]?
}

struct ChatMessagePayload: Encodable {
    let role: String
    let content: String?
    let tool_calls: [ToolCallPayload]?
    let tool_call_id: String?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case tool_calls = "tool_calls"
        case tool_call_id = "tool_call_id"
    }
}

struct ToolCallPayload: Encodable {
    let id: String
    let type: String
    let function: ToolCallFunctionPayload
}

struct ToolCallFunctionPayload: Encodable {
    let name: String
    let arguments: String
}

struct ToolPayload: Encodable {
    let type: String
    let function: ToolFunctionPayload
}

struct ToolFunctionPayload: Encodable {
    let name: String
    let description: String
    let parameters: ToolParametersPayload
}

struct ToolParametersPayload: Encodable {
    let type: String
    let properties: [String: ToolPropertyPayload]
    let required: [String]
}

struct ToolPropertyPayload: Encodable {
    let type: String
    let description: String
    let enum_values: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case type, description
        case enum_values = "enum"
    }
}

/// Service for proxying OpenAI API requests through Supabase Edge Function
@MainActor
class OpenAIService: ObservableObject {
    private let supabase = SupabaseService.shared.client
    
    /// Convert AnyJSON to [String: Any] for flexible handling
    private func convertAnyJSONToDict(_ json: AnyJSON) -> [String: Any] {
        switch json {
        case .object(let dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = convertAnyJSONToAny(value)
            }
            return result
        default:
            return [:]
        }
    }
    
    /// Convert AnyJSON to Any
    private func convertAnyJSONToAny(_ json: AnyJSON) -> Any {
        switch json {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .integer(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let arr):
            return arr.map { convertAnyJSONToAny($0) }
        case .object(let dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = convertAnyJSONToAny(value)
            }
            return result
        }
    }
    
    /// Send a chat completion request through the Edge Function proxy
    func completeChat(
        messages: [[String: Any]],
        model: String = "gpt-4o-mini",
        temperature: Double = 0.7,
        tools: [[String: Any]]? = nil
    ) async throws -> [String: Any] {
        guard SupabaseService.shared.isAuthenticated else {
            throw OpenAIServiceError.notAuthenticated
        }
        
        // Convert messages to Encodable format
        let messagePayloads: [ChatMessagePayload] = messages.compactMap { msg in
            guard let role = msg["role"] as? String else {
                return nil
            }
            
            // Handle content (can be String, NSNull, or nil)
            var content: String? = nil
            if let contentValue = msg["content"] {
                if let stringContent = contentValue as? String {
                    content = stringContent.isEmpty ? nil : stringContent
                } else if contentValue is NSNull {
                    content = nil
                }
            }
            
            // Handle tool_calls
            var toolCalls: [ToolCallPayload]? = nil
            if let toolCallsArray = msg["tool_calls"] as? [[String: Any]] {
                toolCalls = toolCallsArray.compactMap { toolCallDict -> ToolCallPayload? in
                    guard let id = toolCallDict["id"] as? String,
                          let type = toolCallDict["type"] as? String,
                          let functionDict = toolCallDict["function"] as? [String: Any],
                          let functionName = functionDict["name"] as? String,
                          let functionArgs = functionDict["arguments"] as? String else {
                        return nil
                    }
                    return ToolCallPayload(
                        id: id,
                        type: type,
                        function: ToolCallFunctionPayload(name: functionName, arguments: functionArgs)
                    )
                }
            }
            
            // Handle tool_call_id
            let toolCallId = msg["tool_call_id"] as? String
            
            return ChatMessagePayload(
                role: role,
                content: content,
                tool_calls: toolCalls?.isEmpty == false ? toolCalls : nil,
                tool_call_id: toolCallId
            )
        }
        
        // Convert tools to Encodable format if present
        let toolPayloads: [ToolPayload]? = tools?.compactMap { tool -> ToolPayload? in
            guard let type = tool["type"] as? String,
                  let function = tool["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let description = function["description"] as? String,
                  let parameters = function["parameters"] as? [String: Any],
                  let paramType = parameters["type"] as? String,
                  let properties = parameters["properties"] as? [String: Any],
                  let required = parameters["required"] as? [String] else {
                return nil
            }
            
            var propertyPayloads: [String: ToolPropertyPayload] = [:]
            for (key, propAny) in properties {
                guard let prop = propAny as? [String: Any],
                      let propType = prop["type"] as? String,
                      let propDesc = prop["description"] as? String else {
                    continue
                }
                
                // Handle enum (array of integers)
                var enumValues: [Int]? = nil
                if let enumArray = prop["enum"] as? [Int] {
                    enumValues = enumArray
                } else if let enumArrayAny = prop["enum"] as? [Any] {
                    enumValues = enumArrayAny.compactMap { $0 as? Int }
                }
                
                propertyPayloads[key] = ToolPropertyPayload(
                    type: propType,
                    description: propDesc,
                    enum_values: enumValues
                )
            }
            
            return ToolPayload(
                type: type,
                function: ToolFunctionPayload(
                    name: name,
                    description: description,
                    parameters: ToolParametersPayload(
                        type: paramType,
                        properties: propertyPayloads,
                        required: required
                    )
                )
            )
        }
        
        let requestBody = ChatCompletionRequest(
            messages: messagePayloads,
            model: model,
            temperature: temperature,
            tools: toolPayloads
        )
        
        // Encode to JSON and invoke
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(requestBody)
        
        // Call the Edge Function - specify return type explicitly
        let response: AnyJSON = try await supabase.functions.invoke(
            "openai-chat",
            options: FunctionInvokeOptions(body: jsonData)
        )
        
        // Convert AnyJSON to [String: Any]
        let json = convertAnyJSONToDict(response)
        
        // Check for errors in the response
        if let errorDict = json["error"] as? [String: Any] {
            throw OpenAIServiceError.apiError(message: errorDict["message"] as? String ?? "Unknown error")
        } else if let errorString = json["error"] as? String {
            throw OpenAIServiceError.apiError(message: errorString)
        }
        
        return json
    }
}

enum OpenAIServiceError: LocalizedError {
    case notAuthenticated
    case noData
    case invalidResponse
    case apiError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use this feature"
        case .noData:
            return "No data received from server"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}
