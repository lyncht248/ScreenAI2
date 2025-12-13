import Foundation
import Supabase

/// Service for managing chat conversations and messages
@MainActor
class ChatService: ObservableObject {
    private let supabase = SupabaseService.shared.client
    
    /// Create a new conversation
    func createConversation(title: String? = nil) async throws -> UUID {
        guard let userId = SupabaseService.shared.currentUser?.id else {
            throw ChatServiceError.notAuthenticated
        }
        
        let newConversation: Conversation = try await supabase
            .from("conversations")
            .insert([
                "user_id": userId.uuidString,
                "title": title as Any,
                "metadata": [:] as [String: AnyJSON]
            ])
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
        functionCall: [String: Any]? = nil,
        functionName: String? = nil,
        sequenceOrder: Int
    ) async throws -> Message {
        var messageData: [String: Any] = [
            "conversation_id": conversationId.uuidString,
            "role": role,
            "content": content,
            "sequence_order": sequenceOrder
        ]
        
        if let functionCall = functionCall {
            // Store function_call as JSONB - Supabase will handle conversion
            messageData["function_call"] = functionCall
        }
        
        if let functionName = functionName {
            messageData["function_name"] = functionName
        }
        
        let message: Message = try await supabase
            .from("messages")
            .insert(messageData)
            .select()
            .single()
            .execute()
            .value
        
        return message
    }
    
    /// Save multiple messages in a batch
    func saveMessages(_ messages: [(role: String, content: String, functionCall: [String: Any]?, functionName: String?, sequenceOrder: Int)], to conversationId: UUID) async throws {
        guard let userId = SupabaseService.shared.currentUser?.id else {
            throw ChatServiceError.notAuthenticated
        }
        
        var messageDataArray: [[String: Any]] = []
        
        for (index, msg) in messages.enumerated() {
            var messageData: [String: Any] = [
                "conversation_id": conversationId.uuidString,
                "role": msg.role,
                "content": msg.content,
                "sequence_order": msg.sequenceOrder
            ]
            
            if let functionCall = msg.functionCall {
                // Store function_call as JSONB - Supabase will handle conversion
                messageData["function_call"] = functionCall
            }
            
            if let functionName = msg.functionName {
                messageData["function_name"] = functionName
            }
            
            messageDataArray.append(messageData)
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

