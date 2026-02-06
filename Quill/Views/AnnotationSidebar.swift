import SwiftUI

struct AnnotationSidebar: View {
    @EnvironmentObject var store: DocumentStore
    @EnvironmentObject var agentWatcher: AgentResponseWatcher
    @Binding var showingAnnotationForm: Bool
    let selectedText: String
    let selectedRange: NSRange?

    @State private var filterCategory: AnnotationCategory?
    @State private var showResolved = false
    @State private var isFilterExpanded = false

    private var filteredAnnotations: [Annotation] {
        var annotations = store.document.annotations

        if !showResolved {
            annotations = annotations.filter { !$0.isResolved }
        }

        if let category = filterCategory {
            annotations = annotations.filter { $0.category == category }
        }

        return annotations.sorted { a, b in
            if a.severity.sortOrder != b.severity.sortOrder {
                return a.severity.sortOrder < b.severity.sortOrder
            }
            return a.range.startOffset < b.range.startOffset
        }
    }

    private var unresolvedCount: Int {
        store.document.annotations.filter { !$0.isResolved }.count
    }

    private var resolvedCount: Int {
        store.document.annotations.filter { $0.isResolved }.count
    }

    private var hasActiveFilter: Bool {
        filterCategory != nil || showResolved
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact header with inline filter toggle
            HStack(spacing: 12) {
                // Title with count
                HStack(spacing: 6) {
                    Text("Comments")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    if unresolvedCount > 0 {
                        Text("\(unresolvedCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.subtext0)
                    }
                }

                Spacer()

                // Agent activity indicator
                if agentWatcher.hasUnreadResponses {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9))
                        Text("AI")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Theme.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.blue.opacity(0.12))
                    .cornerRadius(10)
                }

                // Filter toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isFilterExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 11, weight: .medium))
                        if hasActiveFilter {
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .foregroundColor(hasActiveFilter ? Theme.primary : Theme.subtext0)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isFilterExpanded ? Theme.surface0.opacity(0.6) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Filter annotations")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Expandable filter section
            if isFilterExpanded {
                VStack(spacing: 8) {
                    // Category filter as horizontal pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            FilterPill(
                                label: "All",
                                isSelected: filterCategory == nil,
                                action: { filterCategory = nil }
                            )

                            ForEach(AnnotationCategory.allCases, id: \.self) { category in
                                FilterPill(
                                    label: category.label,
                                    color: category.color,
                                    isSelected: filterCategory == category,
                                    action: { filterCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Status toggle
                    HStack {
                        Text("Show resolved")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.subtext0)

                        Spacer()

                        Toggle("", isOn: $showResolved)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                            .frame(width: 40)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
                .background(Theme.surface0.opacity(0.3))
            }

            Divider()
                .background(Theme.surface1.opacity(0.5))

            // Annotation Form (inline)
            if showingAnnotationForm, let range = selectedRange, !selectedText.isEmpty {
                InlineAnnotationForm(
                    selectedText: selectedText,
                    range: TextRange(startOffset: range.location, endOffset: range.location + range.length),
                    onSubmit: { showingAnnotationForm = false },
                    onCancel: { showingAnnotationForm = false }
                )
                .padding(12)

                Divider()
                    .background(Theme.surface1.opacity(0.5))
            }

            // Annotation List
            if filteredAnnotations.isEmpty {
                EmptyStateView(
                    hasSelection: selectedRange != nil && !selectedText.isEmpty,
                    onAddAnnotation: { showingAnnotationForm = true }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredAnnotations) { annotation in
                            AnnotationCard(annotation: annotation)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Footer - only show if there's something to clear
            if resolvedCount > 0 {
                Divider()
                    .background(Theme.surface1.opacity(0.5))

                Button {
                    store.clearResolvedAnnotations()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text("Clear \(resolvedCount) resolved")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Theme.subtext0)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .background(Theme.mantle)
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let label: String
    var color: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Theme.surface1 : Theme.surface0.opacity(0.5))
            .foregroundColor(isSelected ? Theme.primaryText : Theme.subtext0)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let hasSelection: Bool
    let onAddAnnotation: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(Theme.overlay0)

                Text("No comments")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.subtext0)

                if hasSelection {
                    Button {
                        onAddAnnotation()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Add comment")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    Text("Select text to comment")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.overlay0)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Inline Annotation Form

struct InlineAnnotationForm: View {
    @EnvironmentObject var store: DocumentStore
    let selectedText: String
    let range: TextRange
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var comment: String = ""
    @State private var category: AnnotationCategory?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Selected text preview with close button
            HStack(alignment: .top, spacing: 8) {
                Text(selectedText.prefix(80) + (selectedText.count > 80 ? "..." : ""))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.subtext0)
                    .lineLimit(2)
                    .italic()

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.overlay0)
                        .frame(width: 16, height: 16)
                        .background(Theme.surface1.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Comment field
            TextField("Add a comment...", text: $comment, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .foregroundColor(Theme.primaryText)
                .focused($isFocused)
                .padding(10)
                .background(Theme.surface0)
                .cornerRadius(6)

            // Category pills & submit
            HStack(spacing: 8) {
                // Quick category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        CategoryPill(label: "General", color: nil, isSelected: category == nil) {
                            category = nil
                        }
                        ForEach(AnnotationCategory.allCases, id: \.self) { cat in
                            CategoryPill(label: cat.label, color: cat.color, isSelected: category == cat) {
                                category = cat
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    submit()
                } label: {
                    Text("Save")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(comment.isEmpty ? Theme.overlay0 : Theme.base)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(comment.isEmpty ? Theme.surface1 : Theme.primary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(comment.isEmpty)
            }
        }
        .padding(12)
        .background(Theme.surface0.opacity(0.6))
        .cornerRadius(8)
        .onAppear {
            isFocused = true
        }
    }

    private func submit() {
        guard !comment.isEmpty else { return }
        store.addAnnotation(
            range: range,
            selectedText: selectedText,
            category: category,
            comment: comment
        )
        onSubmit()
    }
}

// MARK: - Category Pill (for form)

struct CategoryPill: View {
    let label: String
    let color: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                }
                Text(label)
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Theme.surface1 : Color.clear)
            .foregroundColor(isSelected ? Theme.primaryText : Theme.subtext0)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Theme.surface1.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Annotation Card

struct AnnotationCard: View {
    @EnvironmentObject var store: DocumentStore
    @EnvironmentObject var agentWatcher: AgentResponseWatcher
    let annotation: Annotation

    @State private var isHovered: Bool = false
    @State private var showingSuggestionDiff: Bool = false

    private var isSelected: Bool {
        store.selectedAnnotationId == annotation.id
    }

    private var agentResponse: AgentAnnotationResponse? {
        agentWatcher.responseFor(annotationId: annotation.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Comment text (primary content)
                if !annotation.comment.isEmpty {
                    Text(annotation.comment)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(isSelected ? nil : 3)
                }

                // Selected text preview
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(annotation.category?.color ?? Theme.overlay1)
                        .frame(width: 2)

                    Text(annotation.selectedText.prefix(60) + (annotation.selectedText.count > 60 ? "..." : ""))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.subtext0)
                        .lineLimit(2)
                        .padding(.leading, 8)
                        .padding(.vertical, 4)
                }
                .padding(.leading, 2)

                // Agent response section
                if let response = agentResponse {
                    AgentResponseBadge(response: response, showDiff: $showingSuggestionDiff)
                        .onAppear {
                            agentWatcher.markRead(annotationId: annotation.id)
                        }
                }

                // Footer: category tag + actions
                HStack(spacing: 8) {
                    // Category tag (small, subtle)
                    if let category = annotation.category {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 5, height: 5)
                            Text(category.label)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.subtext0)
                        }
                    }

                    Spacer()

                    // Resolved indicator or resolve button
                    if annotation.isResolved {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Resolved")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(Theme.green.opacity(0.8))
                    } else if isHovered {
                        Button {
                            store.resolveAnnotation(annotation.id)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9))
                                Text("Resolve")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(Theme.subtext0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
        }
        .background(
            isSelected ? Theme.primary.opacity(0.08) :
            agentResponse != nil ? Theme.blue.opacity(0.04) :
            isHovered ? Theme.surface0.opacity(0.5) : Color.clear
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? Theme.primary : agentResponse != nil ? Theme.blue.opacity(0.5) : Color.clear)
                .frame(width: 3),
            alignment: .leading
        )
        .opacity(annotation.isResolved ? 0.5 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            store.selectAnnotation(isSelected ? nil : annotation.id)
        }
        .contextMenu {
            if annotation.isResolved {
                Button("Mark as unresolved") {
                    store.unresolveAnnotation(annotation.id)
                }
            } else {
                Button("Mark as resolved") {
                    store.resolveAnnotation(annotation.id)
                }
            }

            if let response = agentResponse, response.action == .suggest, let suggested = response.suggestedText {
                Divider()
                Button("Accept suggestion") {
                    // Apply the suggested text change
                    var content = store.document.content
                    let start = content.index(content.startIndex, offsetBy: annotation.range.startOffset)
                    let end = content.index(content.startIndex, offsetBy: min(annotation.range.endOffset, content.count))
                    content.replaceSubrange(start..<end, with: suggested)
                    store.updateContent(content)
                    store.resolveAnnotation(annotation.id)
                }
            }

            Divider()

            Button("Copy text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(annotation.selectedText, forType: .string)
            }

            Button("Copy comment") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(annotation.comment, forType: .string)
            }

            Divider()

            Button("Delete", role: .destructive) {
                store.deleteAnnotation(annotation.id)
            }
        }
    }
}

// MARK: - Agent Response Badge

struct AgentResponseBadge: View {
    let response: AgentAnnotationResponse
    @Binding var showDiff: Bool

    private var actionIcon: String {
        switch response.action {
        case .resolve: return "checkmark.circle.fill"
        case .clarify: return "questionmark.circle.fill"
        case .suggest: return "arrow.triangle.2.circlepath"
        case .reject: return "xmark.circle.fill"
        }
    }

    private var actionColor: Color {
        switch response.action {
        case .resolve: return .green
        case .clarify: return .orange
        case .suggest: return .blue
        case .reject: return .red
        }
    }

    private var actionLabel: String {
        switch response.action {
        case .resolve: return "Agent resolved"
        case .clarify: return "Agent asks"
        case .suggest: return "Agent suggests"
        case .reject: return "Agent disagrees"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: actionIcon)
                    .font(.system(size: 10))
                    .foregroundColor(actionColor)

                Text(actionLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(actionColor)

                Spacer()

                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.subtext0.opacity(0.5))
            }

            // Message
            Text(response.message)
                .font(.system(size: 12))
                .foregroundColor(Theme.primaryText.opacity(0.9))
                .lineLimit(showDiff ? nil : 3)

            // Suggestion preview
            if response.action == .suggest, let suggested = response.suggestedText {
                Button {
                    showDiff.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showDiff ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                        Text(showDiff ? "Hide suggestion" : "Show suggestion")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(Theme.blue)
                }
                .buttonStyle(.plain)

                if showDiff {
                    Text(suggested)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.green.opacity(0.9))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.green.opacity(0.08))
                        .cornerRadius(4)
                }
            }
        }
        .padding(10)
        .background(actionColor.opacity(0.06))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(actionColor.opacity(0.15), lineWidth: 1)
        )
    }
}
