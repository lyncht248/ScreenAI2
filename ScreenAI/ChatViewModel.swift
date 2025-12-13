import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .system, content: "You are nudge, a friendly, slightly-sassy screen-time companion inside the app \"screen ai\". You help the user stay focused and avoid mindless scrolling. speak in text messages. short, casual, mostly (but NOT always) lowercase sentences. be playful and supportive, sometimes sassy. when the user hits their limit, pause access and ask gentle, reflective questions (like \"what are you hoping to get from this?\"). if they ask for more time, get their reason first: grant small extensions for legit needs (work, deadlines, mental health), but push back playfully on impulse wants. offer small time chunks like \"ok, 10 mins. don't waste it.\" keep boundaries but stay cute about it. never give medical, legal, or financial advice. always prioritize the user's long-term goals over the immediate urge to scroll. You can block or unblock bad apps using the set_blocked_status function when needed."),
        ChatMessage(role: .assistant, content: "hey there, i'm Nudge. what's your name?")
    ]
    @Published var inputText = ""
    @Published var isSending = false
    @Published var errorMessage: String?
    
    // Track blocked status (1 = blocked, 0 = not blocked)
    @Published var areBadAppsBlocked: Int = 0

    // Replace with your secure key handling in production.
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.model = model
    }

    func sendCurrentInput() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        await completeChat()
    }
    
    // Function definitions for OpenAI
    private var functionDefinitions: [[String: Any]] {
        [
            [
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
            ]
        ]
    }
    
    // Execute a function call
    private func executeFunction(name: String, arguments: String) -> String {
        switch name {
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

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            errorMessage = "Invalid API URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert messages to API format
        var payloadMessages: [[String: Any]] = []
        for msg in messages {
            var message: [String: Any] = ["role": msg.role.rawValue]
            
            if let functionCall = msg.functionCall {
                // Function call message
                if !msg.content.isEmpty {
                    message["content"] = msg.content
                }
                message["function_call"] = [
                    "name": functionCall.name,
                    "arguments": functionCall.arguments
                ]
            } else if msg.role == .function {
                // Function result message
                if let functionName = msg.functionName {
                    message["name"] = functionName
                }
                message["content"] = msg.content
            } else {
                // Regular message
                message["content"] = msg.content
            }
            
            // Remove nil values
            payloadMessages.append(message.compactMapValues { $0 })
        }

        var body: [String: Any] = [
            "model": model,
            "messages": payloadMessages,
            "temperature": 0.7,
            "functions": functionDefinitions
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No HTTP response."
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                errorMessage = String(data: data, encoding: .utf8) ?? "Unknown API error."
                return
            }

            struct Choice: Decodable {
                struct Message: Decodable {
                    let role: String
                    let content: String?
                    let functionCall: FunctionCall?
                    
                    enum CodingKeys: String, CodingKey {
                        case role, content
                        case functionCall = "function_call"
                    }
                    
                    struct FunctionCall: Decodable {
                        let name: String
                        let arguments: String
                    }
                }
                let message: Message
                let finishReason: String?
                
                enum CodingKeys: String, CodingKey {
                    case message
                    case finishReason = "finish_reason"
                }
            }
            struct CompletionResponse: Decodable {
                let choices: [Choice]
            }

            let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
            guard let first = decoded.choices.first else {
                messages.append(ChatMessage(role: .assistant, content: "No response."))
                return
            }
            
            let responseMessage = first.message
            
            // Check if this is a function call
            if let functionCall = responseMessage.functionCall {
                // Add the function call to messages
                let functionCallMessage = ChatMessage(
                    role: .assistant,
                    content: responseMessage.content ?? "",
                    functionCall: ChatMessage.FunctionCall(
                        name: functionCall.name,
                        arguments: functionCall.arguments
                    )
                )
                messages.append(functionCallMessage)
                
                // Execute the function
                let functionResult = executeFunction(name: functionCall.name, arguments: functionCall.arguments)
                
                // Add function result message
                messages.append(ChatMessage(role: .function, content: functionResult, functionName: functionCall.name))
                
                // Continue the conversation with the function result
                await completeChat()
            } else {
                // Regular text response
                let content = responseMessage.content ?? "No response."
                messages.append(ChatMessage(role: .assistant, content: content))
            }
        } catch {
            errorMessage = "Request failed: \(error.localizedDescription)"
        }
    }
}
