import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let functionCall: FunctionCall?
    let functionName: String? // For function role messages
    
    init(role: Role, content: String, functionCall: FunctionCall? = nil, functionName: String? = nil) {
        self.role = role
        self.content = content
        self.functionCall = functionCall
        self.functionName = functionName
    }

    enum Role: String {
        case system, user, assistant, tool
    }
    
    struct FunctionCall: Equatable {
        let name: String
        let arguments: String
    }
}
