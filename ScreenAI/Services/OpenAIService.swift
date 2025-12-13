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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        
        if role == "assistant" && tool_calls != nil && !tool_calls!.isEmpty {
            // Assistant message with tool calls - content can be null but must be present
            try container.encode(content, forKey: .content)
            try container.encode(tool_calls, forKey: .tool_calls)
        } else if role == "tool" {
            // Tool result message - requires content and tool_call_id
            try container.encode(content ?? "", forKey: .content)
            // tool_call_id is REQUIRED for tool messages
            if let tcId = tool_call_id, !tcId.isEmpty {
                try container.encode(tcId, forKey: .tool_call_id)
            }
        } else {
            // Regular messages (user, assistant without tools, system)
            try container.encodeIfPresent(content, forKey: .content)
        }
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
        print("📨 Converting \(messages.count) messages")
        let messagePayloads: [ChatMessagePayload] = messages.compactMap { msg in
            guard let role = msg["role"] as? String else {
                print("❌ Message missing role: \(msg)")
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
            
            // Validate tool messages - they MUST have a valid tool_call_id
            if role == "tool" {
                if toolCallId == nil || toolCallId!.isEmpty {
                    print("⚠️ Skipping invalid tool message (missing tool_call_id)")
                    return nil
                }
            }
            
            // Validate assistant messages with tool_calls
            if role == "assistant" && toolCalls != nil && !toolCalls!.isEmpty {
                // Make sure tool_calls have valid IDs
                let validToolCalls = toolCalls!.filter { !$0.id.isEmpty }
                if validToolCalls.isEmpty {
                    print("⚠️ Skipping assistant message with invalid tool_calls")
                    return nil
                }
                toolCalls = validToolCalls
            }
            
            print("📨 ✓ \(role)")
            
            return ChatMessagePayload(
                role: role,
                content: content,
                tool_calls: toolCalls?.isEmpty == false ? toolCalls : nil,
                tool_call_id: toolCallId
            )
        }
        
        // Validate tool_call/tool_result pairs
        // Collect all tool_call_ids from assistant messages
        var toolCallIds = Set<String>()
        for payload in messagePayloads {
            if let toolCalls = payload.tool_calls {
                for tc in toolCalls {
                    toolCallIds.insert(tc.id)
                }
            }
        }
        
        // Filter out tool messages that reference non-existent tool_calls
        let validatedPayloads = messagePayloads.filter { payload in
            if payload.role == "tool" {
                if let tcId = payload.tool_call_id, toolCallIds.contains(tcId) {
                    return true
                } else {
                    print("⚠️ Removing orphaned tool message with id: \(payload.tool_call_id ?? "nil")")
                    return false
                }
            }
            return true
        }
        
        print("📨 Final message payloads count: \(validatedPayloads.count) (filtered from \(messagePayloads.count))")
        
        // Convert tools to Encodable format if present
        print("🔧 Converting \(tools?.count ?? 0) tools")
        let toolPayloads: [ToolPayload]? = tools?.compactMap { tool -> ToolPayload? in
            guard let type = tool["type"] as? String else {
                print("❌ Tool missing 'type'")
                return nil
            }
            guard let function = tool["function"] as? [String: Any] else {
                print("❌ Tool missing 'function'")
                return nil
            }
            guard let name = function["name"] as? String else {
                print("❌ Tool missing 'function.name'")
                return nil
            }
            guard let description = function["description"] as? String else {
                print("❌ Tool missing 'function.description'")
                return nil
            }
            guard let parameters = function["parameters"] as? [String: Any] else {
                print("❌ Tool '\(name)' missing 'function.parameters'")
                return nil
            }
            guard let paramType = parameters["type"] as? String else {
                print("❌ Tool '\(name)' missing 'parameters.type'")
                return nil
            }
            // Handle empty properties dictionary
            let properties = (parameters["properties"] as? [String: Any]) ?? [:]
            // Handle empty required array
            let required = (parameters["required"] as? [String]) ?? []
            
            print("✅ Tool '\(name)' parsed successfully")
            
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
        
        print("🔧 Final tool payloads count: \(toolPayloads?.count ?? 0)")
        
        let requestBody = ChatCompletionRequest(
            messages: validatedPayloads,
            model: model,
            temperature: temperature,
            tools: toolPayloads
        )
        
        // Encode to JSON and invoke
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(requestBody)
        
        // Debug: Print the actual JSON being sent
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Sending to Edge Function: \(jsonString.prefix(500))...")
        }
        
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
