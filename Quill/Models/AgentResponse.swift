import Foundation

/// Response from an AI agent to a specific annotation
struct AgentAnnotationResponse: Codable, Identifiable {
    var id: String { annotationId }
    let annotationId: String
    let action: AgentAction
    let message: String
    let suggestedText: String?
    let timestamp: String
}

enum AgentAction: String, Codable {
    case resolve
    case clarify
    case suggest
    case reject
    case acknowledge
}

/// A document update pushed by an agent
struct AgentDocumentUpdate: Codable, Identifiable {
    var id: String { timestamp }
    let content: String
    let summary: String
    let addressedAnnotationIds: [String]
    let timestamp: String
}

// MARK: - Threaded conversations

enum ThreadRole: String, Codable {
    case human
    case agent
}

struct ThreadMessage: Codable, Identifiable {
    let id: String
    let role: ThreadRole
    let message: String
    let timestamp: String

    init(id: String = UUID().uuidString, role: ThreadRole, message: String, timestamp: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.role = role
        self.message = message
        self.timestamp = timestamp
    }
}

struct AnnotationThread: Codable {
    let annotationId: String
    var messages: [ThreadMessage]
}

/// The agent-response.json file structure
struct AgentResponseFile: Codable {
    let version: Int
    var annotationResponses: [AgentAnnotationResponse]
    var documentUpdates: [AgentDocumentUpdate]
    var threads: [AnnotationThread]?
    var lastUpdated: String
}
