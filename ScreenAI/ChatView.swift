import SwiftUI

struct BubbleShape: Shape {
    enum Direction { case left, right }
    var direction: Direction
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 16)
        // Tail triangle
        let tailSize: CGFloat = 8
        let y = rect.maxY - 14
        if direction == .right {
            path.move(to: CGPoint(x: rect.maxX - 16, y: y))
            path.addLine(to: CGPoint(x: rect.maxX + tailSize, y: y + 6))
            path.addLine(to: CGPoint(x: rect.maxX - 16, y: y + 2))
            path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: rect.minX + 16, y: y))
            path.addLine(to: CGPoint(x: rect.minX - tailSize, y: y + 6))
            path.addLine(to: CGPoint(x: rect.minX + 16, y: y + 2))
            path.closeSubpath()
        }
        return path
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
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nudge")
                        .font(.headline)
                        .redacted(reason: showHeader ? [] : .placeholder)
                    Text(isAssistantTyping ? "Typing…" : "Online")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                Spacer()
                
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
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())

                Button {
                    Task { await viewModel.sendCurrentInput() }
                } label: {
                    Image(systemName: viewModel.isSending ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(viewModel.isSending ? Color.gray : Color.accentColor)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.isSending || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SettingsView(blockedStatus: $viewModel.areBadAppsBlocked)) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
            }
        }
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
            if !isUser {
                // Assistant avatar
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 28, height: 28)
                    .overlay(Image(systemName: "sparkles").font(.caption2).foregroundStyle(.secondary))
            }

            if isUser { Spacer(minLength: 40) }

            Text(message.content)
                .font(.body)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    BubbleShape(direction: isUser ? .right : .left)
                        .fill(isUser ? Color(red: 0.0, green: 0.478, blue: 1.0) : Color(.secondarySystemBackground))
                )
                .overlay(
                    BubbleShape(direction: isUser ? .right : .left)
                        .stroke(Color.black.opacity(isUser ? 0.0 : 0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isUser ? 0.12 : 0.03), radius: isUser ? 8 : 3, x: 0, y: 2)

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
