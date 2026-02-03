import Foundation

struct Document: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var filename: String?
    var filepath: String?
    var annotations: [Annotation]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Untitled Document",
        content: String = "Start writing your content here...\n\nSelect text and press Cmd+Shift+A to add annotations.",
        filename: String? = nil,
        filepath: String? = nil,
        annotations: [Annotation] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.filename = filename
        self.filepath = filepath
        self.annotations = annotations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var unresolvedAnnotations: [Annotation] {
        annotations.filter { !$0.isResolved }
    }
}
