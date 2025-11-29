import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(apiKey: String, model: String = "gpt-4o-mini") {
        _viewModel = StateObject(wrappedValue: ChatViewModel(apiKey: apiKey, model: model))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages.filter { $0.role != .system }) { message in
                            messageBubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _ in
                    if let lastID = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Type a message…", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    Task { await viewModel.sendCurrentInput() }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(viewModel.isSending || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(.bar)
        }
        .navigationTitle("Chat")
    }

    @ViewBuilder
    private func messageBubble(for message: ChatMessage) -> some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: 0) }
            Text(message.content)
                .padding(10)
                .foregroundStyle(isUser ? .white : .primary)
                .background(isUser ? .blue : .gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !isUser { Spacer(minLength: 0) }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(apiKey: "YOUR_OPENAI_API_KEY")
    }
}
