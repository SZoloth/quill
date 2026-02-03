import Foundation
import SwiftUI

struct Annotation: Codable, Identifiable {
    let id: UUID
    var range: TextRange
    var selectedText: String
    var category: AnnotationCategory?
    var severity: AnnotationSeverity
    var comment: String
    var isResolved: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        range: TextRange,
        selectedText: String,
        category: AnnotationCategory? = nil,
        severity: AnnotationSeverity = .shouldFix,
        comment: String = "",
        isResolved: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.range = range
        self.selectedText = selectedText
        self.category = category
        self.severity = severity
        self.comment = comment.isEmpty ? (category?.defaultComment ?? "Needs attention") : comment
        self.isResolved = isResolved
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TextRange: Codable, Equatable {
    var startOffset: Int
    var endOffset: Int

    var length: Int {
        endOffset - startOffset
    }
}

enum AnnotationCategory: String, Codable, CaseIterable {
    case voice = "VOICE"
    case clarity = "CLARITY"
    case structure = "STRUCTURE"
    case expand = "EXPAND"
    case condense = "CONDENSE"
    case rephrase = "REPHRASE"

    var label: String {
        switch self {
        case .voice: return "Voice"
        case .clarity: return "Clarity"
        case .structure: return "Structure"
        case .expand: return "Expand"
        case .condense: return "Condense"
        case .rephrase: return "Rephrase"
        }
    }

    var color: Color {
        switch self {
        case .voice: return .purple
        case .clarity: return .blue
        case .structure: return .green
        case .expand: return .orange
        case .condense: return .pink
        case .rephrase: return .teal
        }
    }

    var defaultComment: String {
        "Needs \(label.lowercased()) improvement"
    }
}

enum AnnotationSeverity: String, Codable, CaseIterable {
    case mustFix = "must-fix"
    case shouldFix = "should-fix"
    case consider = "consider"

    var label: String {
        switch self {
        case .mustFix: return "Must Fix"
        case .shouldFix: return "Should Fix"
        case .consider: return "Consider"
        }
    }

    var color: Color {
        switch self {
        case .mustFix: return .red
        case .shouldFix: return .orange
        case .consider: return .gray
        }
    }

    var sortOrder: Int {
        switch self {
        case .mustFix: return 0
        case .shouldFix: return 1
        case .consider: return 2
        }
    }
}
