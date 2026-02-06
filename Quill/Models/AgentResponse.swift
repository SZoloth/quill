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
}

/// A document update pushed by an agent
struct AgentDocumentUpdate: Codable, Identifiable {
    var id: String { timestamp }
    let content: String
    let summary: String
    let addressedAnnotationIds: [String]
    let timestamp: String
}

/// The agent-response.json file structure
struct AgentResponseFile: Codable {
    let version: Int
    var annotationResponses: [AgentAnnotationResponse]
    var documentUpdates: [AgentDocumentUpdate]
    var lastUpdated: String
}
