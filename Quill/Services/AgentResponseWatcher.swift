import Foundation
import Combine

/// Watches ~/.quill/agent-response.json for changes from AI agents.
/// When an agent responds to annotations or pushes document updates,
/// this service detects the change and updates the UI.
@MainActor
class AgentResponseWatcher: ObservableObject {
    @Published var responses: AgentResponseFile?
    @Published var hasUnreadResponses: Bool = false
    @Published var lastError: String?

    private let responseURL: URL
    private var timer: Timer?
    private var lastModified: Date?
    private var readAnnotationIds: Set<String> = []

    init() {
        let quillDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".quill")
        self.responseURL = quillDir.appendingPathComponent("agent-response.json")
    }

    /// Start polling for agent response changes
    func startWatching(interval: TimeInterval = 1.0) {
        stopWatching()
        loadResponses()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    /// Check if the file was modified since last read
    private func checkForChanges() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: responseURL.path),
              let modified = attrs[.modificationDate] as? Date else {
            return
        }

        if lastModified == nil || modified > lastModified! {
            loadResponses()
        }
    }

    /// Load and parse the agent response file
    private func loadResponses() {
        guard FileManager.default.fileExists(atPath: responseURL.path) else {
            responses = nil
            hasUnreadResponses = false
            return
        }

        do {
            let data = try Data(contentsOf: responseURL)
            let decoded = try JSONDecoder().decode(AgentResponseFile.self, from: data)
            responses = decoded

            // Check for unread responses
            let allIds = Set(decoded.annotationResponses.map(\.annotationId))
            hasUnreadResponses = !allIds.subtracting(readAnnotationIds).isEmpty

            // Update last modified
            if let attrs = try? FileManager.default.attributesOfItem(atPath: responseURL.path) {
                lastModified = attrs[.modificationDate] as? Date
            }

            lastError = nil
        } catch {
            lastError = "Failed to parse agent-response.json: \(error.localizedDescription)"
        }
    }

    /// Get the agent response for a specific annotation
    func responseFor(annotationId: UUID) -> AgentAnnotationResponse? {
        responses?.annotationResponses.first { $0.annotationId == annotationId.uuidString }
    }

    /// Mark an annotation's agent response as read
    func markRead(annotationId: UUID) {
        readAnnotationIds.insert(annotationId.uuidString)
        updateUnreadStatus()
    }

    /// Mark all responses as read
    func markAllRead() {
        if let responses = responses {
            for response in responses.annotationResponses {
                readAnnotationIds.insert(response.annotationId)
            }
        }
        hasUnreadResponses = false
    }

    /// Accept an agent's document update (apply to document store)
    func acceptDocumentUpdate(_ update: AgentDocumentUpdate, store: DocumentStore) {
        store.updateContent(update.content)

        // Resolve the annotations the agent addressed
        for idString in update.addressedAnnotationIds {
            if let uuid = UUID(uuidString: idString) {
                store.resolveAnnotation(uuid)
            }
        }
    }

    /// Clear all agent responses (reset for new editing session)
    func clearResponses() {
        try? FileManager.default.removeItem(at: responseURL)
        responses = nil
        hasUnreadResponses = false
        readAnnotationIds.removeAll()
    }

    private func updateUnreadStatus() {
        guard let responses = responses else {
            hasUnreadResponses = false
            return
        }
        let allIds = Set(responses.annotationResponses.map(\.annotationId))
        hasUnreadResponses = !allIds.subtracting(readAnnotationIds).isEmpty
    }
}
