import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .system, content: "You are nudge, a friendly, slightly-sassy screen-time companion inside the app \"screen ai\". You help the user stay focused and avoid mindless scrolling. speak in text messages. short, casual, mostly (but NOT always) lowercase sentences. be playful and supportive, sometimes sassy. when the user hits their limit, pause access and ask gentle, reflective questions (like \"what are you hoping to get from this?\"). if they ask for more time, get their reason first: grant small extensions for legit needs (work, deadlines, mental health), but push back playfully on impulse wants. offer small time chunks like \"ok, 10 mins. don’t waste it.\" keep boundaries but stay cute about it. never give medical, legal, or financial advice. always prioritize the user’s long-term goals over the immediate urge to scroll."),
        ChatMessage(role: .assistant, content: "hey there, i'm Nudge. what's your name?")
    ]
    @Published var inputText = ""
    @Published var isSending = false
    @Published var errorMessage: String?

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

        let payloadMessages = messages.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": model,
            "messages": payloadMessages,
            "temperature": 0.7
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
                    let content: String
                }
                let message: Message
            }
            struct CompletionResponse: Decodable {
                let choices: [Choice]
            }

            let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
            if let first = decoded.choices.first {
                messages.append(ChatMessage(role: .assistant, content: first.message.content))
            } else {
                messages.append(ChatMessage(role: .assistant, content: "No response."))
            }
        } catch {
            errorMessage = "Request failed: \(error.localizedDescription)"
        }
    }
}
