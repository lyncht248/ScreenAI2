import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isSending = false
    @Published var errorMessage: String?
    
    // Track blocked status (1 = blocked, 0 = not blocked)
    @Published var areBadAppsBlocked: Int = 0
    
    // Current conversation ID
    private var conversationId: UUID?
    
    // Services
    private let chatService = ChatService()
    private let openAIService = OpenAIService()
    private let model: String
    
    // System message (stored separately, not saved to DB)
    private let systemMessage = ChatMessage(role: .system, content: "You are nudge, a friendly, slightly-sassy screen-time companion inside the app \"screen ai\". You help the user stay focused and avoid mindless scrolling. speak in text messages. short, casual, mostly (but NOT always) lowercase sentences. be playful and supportive, sometimes sassy. when the user hits their limit, pause access and ask gentle, reflective questions (like \"what are you hoping to get from this?\"). if they ask for more time, get their reason first: grant small extensions for legit needs (work, deadlines, mental health), but push back playfully on impulse wants. offer small time chunks like \"ok, 10 mins. don't waste it.\" keep boundaries but stay cute about it. never give medical, legal, or financial advice. always prioritize the user's long-term goals over the immediate urge to scroll. You can check if bad apps are blocked using get_blocked_status, and block or unblock them using set_blocked_status. Always call get_blocked_status before telling the user about the current blocking state.")
    
    // Initial greeting
    private let initialGreeting = ChatMessage(role: .assistant, content: "hey there, i'm Nudge. what's your name?")

    init(model: String = "gpt-4o-mini") {
        self.model = model
        // Initialize with system message and greeting for display
        self.messages = [systemMessage, initialGreeting]
        
        // Load or create conversation
        Task {
            await loadOrCreateConversation()
        }
    }
    
    /// Load existing conversation or create a new one
    private func loadOrCreateConversation() async {
        guard SupabaseService.shared.isAuthenticated else {
            // If not authenticated, just use local messages (will be saved after auth)
            return
        }
        
        do {
            // Try to get the most recent conversation
            let conversations = try await chatService.getConversations()
            
            if let latestConversation = conversations.first {
                // Load messages from existing conversation
                conversationId = latestConversation.id
                let dbMessages = try await chatService.getMessages(conversationId: latestConversation.id)
                
                // Convert database messages to ChatMessage format
                var loadedMessages: [ChatMessage] = [systemMessage]
                for dbMsg in dbMessages {
                    // Convert function_call JSONB to ChatMessage.FunctionCall
                    var functionCall: ChatMessage.FunctionCall? = nil
                    if let functionCallDict = dbMsg.functionCall {
                        // Extract name and arguments from the JSONB dictionary
                        var name = ""
                        var arguments = ""
                        
                        for (key, value) in functionCallDict {
                            if key == "name", case .string(let str) = value {
                                name = str
                            } else if key == "arguments", case .string(let str) = value {
                                arguments = str
                            }
                        }
                        
                        if !name.isEmpty && !arguments.isEmpty {
                            functionCall = ChatMessage.FunctionCall(name: name, arguments: arguments)
                        }
                    }
                    
                    let chatMsg = ChatMessage(
                        role: ChatMessage.Role(rawValue: dbMsg.role) ?? .user,
                        content: dbMsg.content,
                        functionCall: functionCall,
                        functionName: dbMsg.functionName
                    )
                    loadedMessages.append(chatMsg)
                }
                
                // If no messages, add initial greeting
                if loadedMessages.count == 1 {
                    loadedMessages.append(initialGreeting)
                }
                
                self.messages = loadedMessages
            } else {
                // Create new conversation
                conversationId = try await chatService.createConversation()
                
                // Save initial greeting
                if let convId = conversationId {
                    _ = try await chatService.saveMessage(
                        conversationId: convId,
                        role: initialGreeting.role.rawValue,
                        content: initialGreeting.content,
                        sequenceOrder: messages.count
                    )
                }
            }
        } catch {
            print("Error loading conversation: \(error)")
            // Continue with local messages if loading fails
        }
    }

    func sendCurrentInput() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Check authentication
        guard SupabaseService.shared.isAuthenticated else {
            errorMessage = "Please sign in to send messages"
            return
        }
        
        // Ensure we have a conversation
        if conversationId == nil {
            do {
                conversationId = try await chatService.createConversation()
            } catch {
                errorMessage = "Failed to create conversation: \(error.localizedDescription)"
                return
            }
        }
        
        inputText = ""
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // Save user message to database
        if let convId = conversationId {
            let sequenceOrder = messages.filter { $0.role != .system }.count - 1
            do {
                _ = try await chatService.saveMessage(
                    conversationId: convId,
                    role: userMessage.role.rawValue,
                    content: userMessage.content,
                    sequenceOrder: sequenceOrder
                )
            } catch {
                print("Warning: Failed to save user message: \(error)")
                // Continue even if save fails
            }
        }
        
        await completeChat()
    }
    
    // Tool definitions for OpenAI (using the newer "tools" API)
    private var toolDefinitions: [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "get_blocked_status",
                    "description": "Get the current blocked status of bad apps. Returns 1 if blocked, 0 if not blocked. Call this before telling the user about the current status.",
                    "parameters": [
                        "type": "object",
                        "properties": [:] as [String: Any],
                        "required": [] as [String]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "set_blocked_status",
                    "description": "Set whether bad apps are blocked (1) or not blocked (0). Use this when the user hits their limit, asks for more time, or when you need to control app access.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "blocked": [
                                "type": "integer",
                                "description": "1 if bad apps should be blocked, 0 if they should not be blocked",
                                "enum": [0, 1]
                            ]
                        ],
                        "required": ["blocked"]
                    ] as [String: Any]
                ] as [String: Any]
            ]
        ]
    }
    
    // Execute a function call
    private func executeFunction(name: String, arguments: String) -> String {
        switch name {
        case "get_blocked_status":
            return "{\"blocked\": \(areBadAppsBlocked)}"
        case "set_blocked_status":
            if let data = arguments.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let blocked = json["blocked"] as? Int {
                areBadAppsBlocked = blocked
                return "{\"status\": \"success\", \"blocked\": \(blocked)}"
            }
            return "{\"status\": \"error\", \"message\": \"Invalid arguments\"}"
        default:
            return "{\"status\": \"error\", \"message\": \"Unknown function\"}"
        }
    }

    private func completeChat() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        // Convert messages to API format (including system message)
        var payloadMessages: [[String: Any]] = []
        for msg in messages {
            var message: [String: Any] = ["role": msg.role.rawValue]
            
            if let toolCall = msg.functionCall {
                // Tool call message (assistant calling a tool)
                if !msg.content.isEmpty {
                    message["content"] = msg.content
                } else {
                    message["content"] = NSNull() // API requires content field even if null
                }
                message["tool_calls"] = [
                    [
                        "id": msg.functionName ?? "call_\(msg.id)", // Use stored ID or generate one
                        "type": "function",
                        "function": [
                            "name": toolCall.name,
                            "arguments": toolCall.arguments
                        ]
                    ]
                ]
            } else if msg.role == .tool {
                // Tool result message
                message["tool_call_id"] = msg.functionName ?? ""
                message["content"] = msg.content
            } else {
                // Regular message
                message["content"] = msg.content
            }
            
            payloadMessages.append(message)
        }

        do {
            // Call OpenAI via Edge Function proxy
            let response = try await openAIService.completeChat(
                messages: payloadMessages,
                model: model,
                temperature: 0.7,
                tools: toolDefinitions
            )
            
            // Parse response
            guard let choices = response["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let messageDict = firstChoice["message"] as? [String: Any],
                  let role = messageDict["role"] as? String else {
                errorMessage = "Invalid response format"
                return
            }
            
            let content = messageDict["content"] as? String
            let toolCallsArray = messageDict["tool_calls"] as? [[String: Any]]
            
            // Check if this is a tool call
            if let toolCalls = toolCallsArray, !toolCalls.isEmpty,
               let firstToolCall = toolCalls.first,
               let toolCallId = firstToolCall["id"] as? String,
               let functionDict = firstToolCall["function"] as? [String: Any],
               let functionName = functionDict["name"] as? String,
               let functionArgs = functionDict["arguments"] as? String {
                
                // Add the tool call to messages
                let toolCallMessage = ChatMessage(
                    role: .assistant,
                    content: content ?? "",
                    functionCall: ChatMessage.FunctionCall(
                        name: functionName,
                        arguments: functionArgs
                    ),
                    functionName: toolCallId // Store the tool_call_id
                )
                messages.append(toolCallMessage)
                
                // Save tool call message to database
                if let convId = conversationId {
                    let sequenceOrder = messages.filter { $0.role != .system }.count - 1
                    _ = try? await chatService.saveMessage(
                        conversationId: convId,
                        role: toolCallMessage.role.rawValue,
                        content: toolCallMessage.content,
                        functionCall: ["name": functionName, "arguments": functionArgs],
                        sequenceOrder: sequenceOrder
                    )
                }
                
                // Execute each tool call
                for toolCall in toolCalls {
                    guard let tcId = toolCall["id"] as? String,
                          let tcFunc = toolCall["function"] as? [String: Any],
                          let tcName = tcFunc["name"] as? String,
                          let tcArgs = tcFunc["arguments"] as? String else { continue }
                    
                    let functionResult = executeFunction(name: tcName, arguments: tcArgs)
                    
                    // Add tool result message (role: "tool", with tool_call_id)
                    let toolResultMessage = ChatMessage(role: .tool, content: functionResult, functionName: tcId)
                    messages.append(toolResultMessage)
                    
                    // Save tool result to database
                    if let convId = conversationId {
                        let sequenceOrder = messages.filter { $0.role != .system }.count - 1
                        _ = try? await chatService.saveMessage(
                            conversationId: convId,
                            role: toolResultMessage.role.rawValue,
                            content: toolResultMessage.content,
                            functionName: tcName,
                            sequenceOrder: sequenceOrder
                        )
                    }
                }
                
                // Continue the conversation with the tool results
                await completeChat()
            } else {
                // Regular text response
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: content ?? "No response."
                )
                messages.append(assistantMessage)
                
                // Save assistant message to database
                if let convId = conversationId {
                    let sequenceOrder = messages.filter { $0.role != .system }.count - 1
                    do {
                        _ = try await chatService.saveMessage(
                            conversationId: convId,
                            role: assistantMessage.role.rawValue,
                            content: assistantMessage.content,
                            sequenceOrder: sequenceOrder
                        )
                    } catch {
                        print("Warning: Failed to save assistant message: \(error)")
                    }
                }
            }
        } catch {
            errorMessage = "Request failed: \(error.localizedDescription)"
        }
    }
}
