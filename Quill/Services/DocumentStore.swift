import Foundation
import Combine

@MainActor
class DocumentStore: ObservableObject {
    @Published var document: Document
    @Published var selectedAnnotationId: UUID?

    private let saveURL: URL
    private let exportURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        // ~/.quill/document.json for CLI integration
        let quillDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".quill")

        try? FileManager.default.createDirectory(at: quillDir, withIntermediateDirectories: true)

        self.saveURL = quillDir.appendingPathComponent("state.json")
        self.exportURL = quillDir.appendingPathComponent("document.json")

        // Load saved state or create new
        if let data = try? Data(contentsOf: saveURL),
           let saved = try? JSONDecoder().decode(Document.self, from: data) {
            self.document = saved
        } else {
            self.document = Document()
        }
    }

    // MARK: - Document Actions

    func updateTitle(_ title: String) {
        document.title = title
        document.updatedAt = Date()
        scheduleSave()
    }

    func updateContent(_ content: String) {
        document.content = content
        document.updatedAt = Date()
        scheduleSave()
    }

    func openFile(at url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        document = Document(
            title: url.deletingPathExtension().lastPathComponent,
            content: content,
            filename: url.lastPathComponent,
            filepath: url.path
        )
        scheduleSave()
    }

    func newDocument() {
        document = Document()
        selectedAnnotationId = nil
        scheduleSave()
    }

    // MARK: - Annotation Actions

    func addAnnotation(range: TextRange, selectedText: String, category: AnnotationCategory?, comment: String) {
        let annotation = Annotation(
            range: range,
            selectedText: selectedText,
            category: category,
            comment: comment
        )
        document.annotations.append(annotation)
        document.updatedAt = Date()
        scheduleSave()
    }

    func resolveAnnotation(_ id: UUID) {
        if let index = document.annotations.firstIndex(where: { $0.id == id }) {
            document.annotations[index].isResolved = true
            document.annotations[index].updatedAt = Date()
            document.updatedAt = Date()
            scheduleSave()
        }
    }

    func unresolveAnnotation(_ id: UUID) {
        if let index = document.annotations.firstIndex(where: { $0.id == id }) {
            document.annotations[index].isResolved = false
            document.annotations[index].updatedAt = Date()
            document.updatedAt = Date()
            scheduleSave()
        }
    }

    func clearResolvedAnnotations() {
        document.annotations.removeAll { $0.isResolved }
        document.updatedAt = Date()
        scheduleSave()
    }

    func deleteAnnotation(_ id: UUID) {
        document.annotations.removeAll { $0.id == id }
        if selectedAnnotationId == id {
            selectedAnnotationId = nil
        }
        document.updatedAt = Date()
        scheduleSave()
    }

    func selectAnnotation(_ id: UUID?) {
        selectedAnnotationId = id
    }

    func navigateToNext() {
        let unresolved = document.unresolvedAnnotations.sorted { $0.range.startOffset < $1.range.startOffset }
        guard !unresolved.isEmpty else { return }

        if let currentId = selectedAnnotationId,
           let currentIndex = unresolved.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % unresolved.count
            selectedAnnotationId = unresolved[nextIndex].id
        } else {
            selectedAnnotationId = unresolved.first?.id
        }
    }

    func navigateToPrevious() {
        let unresolved = document.unresolvedAnnotations.sorted { $0.range.startOffset < $1.range.startOffset }
        guard !unresolved.isEmpty else { return }

        if let currentId = selectedAnnotationId,
           let currentIndex = unresolved.firstIndex(where: { $0.id == currentId }) {
            let prevIndex = currentIndex == 0 ? unresolved.count - 1 : currentIndex - 1
            selectedAnnotationId = unresolved[prevIndex].id
        } else {
            selectedAnnotationId = unresolved.last?.id
        }
    }

    // MARK: - Export

    func exportForCLI() throws {
        let export = ExportData(
            filename: document.filename,
            filepath: document.filepath,
            title: document.title,
            content: document.content,
            wordCount: document.wordCount,
            annotations: document.unresolvedAnnotations.map { ann in
                ExportAnnotation(
                    id: ann.id.uuidString,
                    text: ann.selectedText,
                    category: ann.category?.rawValue,
                    severity: ann.severity.rawValue,
                    comment: ann.comment,
                    startOffset: ann.range.startOffset,
                    endOffset: ann.range.endOffset
                )
            },
            prompt: generatePrompt()
        )

        let data = try JSONEncoder().encode(export)
        try data.write(to: exportURL)
    }

    func generatePrompt() -> String {
        var sections: [String] = []

        // Document header
        let docRef = document.filepath ?? document.filename ?? document.title
        sections.append("## Document: \(docRef)\n")

        // Context
        sections.append("I'm working on a piece of writing (\(document.wordCount) words).")

        // Annotations by category
        let grouped = Dictionary(grouping: document.unresolvedAnnotations) { $0.category }

        if !grouped.isEmpty {
            sections.append("\n## Feedback\n")

            for category in AnnotationCategory.allCases {
                if let annotations = grouped[category], !annotations.isEmpty {
                    sections.append("### \(category.label)")
                    for ann in annotations.sorted(by: { $0.severity.sortOrder < $1.severity.sortOrder }) {
                        sections.append("- [\(ann.severity.label)] \"\(ann.selectedText.prefix(50))...\" - \(ann.comment)")
                    }
                }
            }

            // General (nil category)
            if let general = grouped[nil], !general.isEmpty {
                sections.append("### General")
                for ann in general.sorted(by: { $0.severity.sortOrder < $1.severity.sortOrder }) {
                    sections.append("- [\(ann.severity.label)] \"\(ann.selectedText.prefix(50))...\" - \(ann.comment)")
                }
            }
        }

        sections.append("\n## Request\n")
        sections.append("Please revise the text addressing the feedback above.")

        return sections.joined(separator: "\n")
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(document)
            try data.write(to: saveURL)
            try exportForCLI() // Also update CLI export
        } catch {
            print("Failed to save: \(error)")
        }
    }
}

// MARK: - Export Types

struct ExportData: Codable {
    let filename: String?
    let filepath: String?
    let title: String
    let content: String
    let wordCount: Int
    let annotations: [ExportAnnotation]
    let prompt: String
}

struct ExportAnnotation: Codable {
    let id: String
    let text: String
    let category: String?
    let severity: String
    let comment: String
    let startOffset: Int
    let endOffset: Int
}
