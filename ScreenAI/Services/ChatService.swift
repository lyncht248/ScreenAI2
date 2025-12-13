import Foundation
import Supabase

// MARK: - Insert Models (for Supabase inserts)

private struct ConversationInsert: Codable {
    let user_id: String
    let title: String?
    let metadata: [String: String]?
}

private struct MessageInsert: Codable {
    let conversation_id: String
    let role: String
    let content: String
    let function_call: [String: String]?
    let function_name: String?
    let sequence_order: Int
}

/// Service for managing chat conversations and messages
@MainActor
class ChatService: ObservableObject {
    private let supabase = SupabaseService.shared.client
    
    /// Create a new conversation
    func createConversation(title: String? = nil) async throws -> UUID {
        guard let userId = SupabaseService.shared.currentUser?.id else {
            throw ChatServiceError.notAuthenticated
        }
        
        let insertData = ConversationInsert(
            user_id: userId.uuidString,
            title: title,
            metadata: nil
        )
        
        let newConversation: Conversation = try await supabase
            .from("conversations")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
        
        return newConversation.id
    }
    
    /// Get all conversations for the current user
    func getConversations() async throws -> [Conversation] {
        guard let userId = SupabaseService.shared.currentUser?.id else {
            throw ChatServiceError.notAuthenticated
        }
        
        let conversations: [Conversation] = try await supabase
            .from("conversations")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return conversations
    }
    
    /// Get a specific conversation
    func getConversation(id: UUID) async throws -> Conversation {
        let conversation: Conversation = try await supabase
            .from("conversations")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return conversation
    }
    
    /// Get all messages for a conversation
    func getMessages(conversationId: UUID) async throws -> [Message] {
        let messages: [Message] = try await supabase
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .order("sequence_order", ascending: true)
            .execute()
            .value
        
        return messages
    }
    
    /// Save a message to the database
    func saveMessage(
        conversationId: UUID,
        role: String,
        content: String,
        functionCall: [String: String]? = nil,
        functionName: String? = nil,
        sequenceOrder: Int
    ) async throws -> Message {
        let insertData = MessageInsert(
            conversation_id: conversationId.uuidString,
            role: role,
            content: content,
            function_call: functionCall,
            function_name: functionName,
            sequence_order: sequenceOrder
        )
        
        let message: Message = try await supabase
            .from("messages")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
        
        return message
    }
    
    /// Save multiple messages in a batch
    func saveMessages(_ messages: [(role: String, content: String, functionCall: [String: String]?, functionName: String?, sequenceOrder: Int)], to conversationId: UUID) async throws {
        let messageDataArray = messages.map { msg in
            MessageInsert(
                conversation_id: conversationId.uuidString,
                role: msg.role,
                content: msg.content,
                function_call: msg.functionCall,
                function_name: msg.functionName,
                sequence_order: msg.sequenceOrder
            )
        }
        
        try await supabase
            .from("messages")
            .insert(messageDataArray)
            .execute()
    }
    
    /// Delete a conversation and all its messages
    func deleteConversation(id: UUID) async throws {
        try await supabase
            .from("conversations")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    /// Update conversation title
    func updateConversationTitle(id: UUID, title: String) async throws {
        try await supabase
            .from("conversations")
            .update(["title": title])
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    /// Update conversation metadata
    func updateConversationMetadata(id: UUID, metadata: [String: Any]) async throws {
        // Get current metadata and merge
        let conversation = try await getConversation(id: id)
        var currentMetadata = (conversation.metadata?.compactMapValues { value -> Any? in
            switch value {
            case .null: return nil
            case .bool(let v): return v
            case .integer(let v): return v
            case .double(let v): return v
            case .string(let v): return v
            case .array(let arr): return arr.map { convertAnyJSONToAny($0) }
            case .object(let dict):
                var result: [String: Any] = [:]
                for (key, val) in dict {
                    result[key] = convertAnyJSONToAny(val)
                }
                return result
            }
        }) ?? [:]
        
        // Merge new metadata
        for (key, value) in metadata {
            currentMetadata[key] = value
        }
        
        // Convert back to AnyJSON
        var metadataJSON: [String: AnyJSON] = [:]
        for (key, value) in currentMetadata {
            metadataJSON[key] = convertAnyToAnyJSON(value)
        }
        
        try await supabase
            .from("conversations")
            .update(["metadata": metadataJSON])
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Helper to convert Any to AnyJSON
    private func convertAnyToAnyJSON(_ value: Any) -> AnyJSON {
        if let bool = value as? Bool {
            return .bool(bool)
        } else if let int = value as? Int {
            return .integer(int)
        } else if let double = value as? Double {
            return .double(double)
        } else if let string = value as? String {
            return .string(string)
        } else if let array = value as? [Any] {
            return .array(array.map { convertAnyToAnyJSON($0) })
        } else if let dict = value as? [String: Any] {
            var result: [String: AnyJSON] = [:]
            for (key, val) in dict {
                result[key] = convertAnyToAnyJSON(val)
            }
            return .object(result)
        }
        return .null
    }
    
    // Helper to convert AnyJSON to Any
    private func convertAnyJSONToAny(_ json: AnyJSON) -> Any {
        switch json {
        case .null: return NSNull()
        case .bool(let value): return value
        case .integer(let value): return value
        case .double(let value): return value
        case .string(let value): return value
        case .array(let arr): return arr.map { convertAnyJSONToAny($0) }
        case .object(let dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = convertAnyJSONToAny(value)
            }
            return result
        }
    }
}

enum ChatServiceError: LocalizedError {
    case notAuthenticated
    case invalidConversation
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .invalidConversation:
            return "Invalid conversation"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

