import SwiftUI

// MARK: - Color Palette
extension Color {
    static let oatBackground = Color(red: 235/255, green: 230/255, blue: 225/255)
    static let oatLighter = Color(red: 245/255, green: 242/255, blue: 238/255)
    static let oatBubble = Color(red: 220/255, green: 215/255, blue: 210/255)
    static let warmGray = Color(red: 120/255, green: 115/255, blue: 110/255)
}

struct BubbleShape: Shape {
    enum Direction { case left, right }
    var direction: Direction
    func path(in rect: CGRect) -> Path {
        return Path(roundedRect: rect, cornerRadius: 16)
    }
}

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var showHeader: Bool = false
    @State private var isAssistantTyping: Bool = false

    init(model: String = "gpt-4o-mini") {
        _viewModel = StateObject(wrappedValue: ChatViewModel(model: model))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Person bar (Messages-like header)
            HStack(spacing: 12) {
                // Avatar (person bubble)
                ZStack {
                    Circle()
                        .fill(Color.oatBubble)
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.warmGray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nudge")
                        .font(.headline)
                        .foregroundStyle(Color(red: 50/255, green: 45/255, blue: 40/255))
                        .redacted(reason: showHeader ? [] : .placeholder)
                    Text(isAssistantTyping ? "Typing…" : "Online")
                        .font(.caption)
                        .foregroundStyle(Color.warmGray)
                        .contentTransition(.opacity)
                }
                Spacer()
                
                // Settings button
                NavigationLink(destination: SettingsView(blockedStatus: $viewModel.areBadAppsBlocked)) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.warmGray)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .opacity(showHeader ? 1 : 0)
            .offset(y: showHeader ? 0 : -8)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showHeader)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.messages.filter { $0.role != .system && $0.role != .tool && $0.functionCall == nil }) { message in
                            messageBubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages) { _ in
                    if let lastID = viewModel.messages.filter({ $0.role != .system && $0.role != .tool && $0.functionCall == nil }).last?.id {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            // Modern input bar
            HStack(spacing: 10) {
                HStack {
                    TextField("Message Nudge…", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                }
                .background(Color.oatLighter)
                .clipShape(Capsule())

                Button {
                    Task { await viewModel.sendCurrentInput() }
                } label: {
                    Image(systemName: viewModel.isSending ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(viewModel.isSending ? Color.oatBubble : Color(red: 0.0, green: 0.478, blue: 1.0))
                        .clipShape(Capsule())
                }
                .disabled(viewModel.isSending || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.oatBackground)
        }
        .background(Color.oatBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { showHeader = true }
        .onChange(of: viewModel.isSending) { sending in
            withAnimation(.easeInOut(duration: 0.25)) {
                isAssistantTyping = sending
            }
        }
    }

    @ViewBuilder
    private func messageBubble(for message: ChatMessage) -> some View {
        let isUser = message.role == .user
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            Text(message.content)
                .font(.body)
                .foregroundStyle(isUser ? .white : Color(red: 50/255, green: 45/255, blue: 40/255))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    BubbleShape(direction: isUser ? .right : .left)
                        .fill(isUser ? Color(red: 0.0, green: 0.478, blue: 1.0) : Color.oatBubble)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 2)
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
