import SwiftUI
import AppKit

struct EditorView: View {
    @EnvironmentObject var store: DocumentStore
    @Binding var selectedRange: NSRange?
    @Binding var selectedText: String
    @Binding var showingAnnotationForm: Bool

    @State private var titleText: String = ""
    @State private var selectionY: CGFloat = 0
    @State private var hasSelection: Bool = false
    @State private var showCommentCard: Bool = false
    @State private var commentText: String = ""
    @State private var selectedCategory: AnnotationCategory? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Main editor area
            VStack(alignment: .leading, spacing: 0) {
                // Title — no divider, whitespace provides separation
                TextField("Untitled Document", text: $titleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.titleFontSize, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, Theme.titleBottomPadding)
                    .onChange(of: titleText) { _, newValue in
                        store.updateTitle(newValue)
                    }

                // Editor
                AnnotatedTextEditor(
                    text: Binding(
                        get: { store.document.content },
                        set: { store.updateContent($0) }
                    ),
                    annotations: store.document.unresolvedAnnotations,
                    selectedAnnotationId: store.selectedAnnotationId,
                    onSelectionChange: { range, text, yPosition in
                        selectedRange = range
                        selectedText = text
                        if let y = yPosition, range != nil && !text.isEmpty {
                            selectionY = y + 100
                            hasSelection = true
                        } else {
                            if !showCommentCard {
                                hasSelection = false
                            }
                        }
                    },
                    onAnnotationClick: { id in
                        store.selectAnnotation(id)
                    }
                )
                .padding(24)
            }
            .frame(maxWidth: .infinity)

            // Right margin — Google Docs style comment trigger
            ZStack(alignment: .topTrailing) {
                // Subtle margin background
                Rectangle()
                    .fill(Theme.background)
                    .frame(width: 48)

                // Comment card (expanded) or comment icon (collapsed)
                if showCommentCard {
                    CommentCard(
                        commentText: $commentText,
                        category: $selectedCategory,
                        onCancel: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showCommentCard = false
                            }
                            commentText = ""
                        },
                        onSubmit: {
                            if let range = selectedRange {
                                store.addAnnotation(
                                    range: TextRange(startOffset: range.location, endOffset: range.location + range.length),
                                    selectedText: selectedText,
                                    category: selectedCategory,
                                    comment: commentText
                                )
                            }
                            withAnimation(.easeOut(duration: 0.15)) {
                                showCommentCard = false
                            }
                            commentText = ""
                            selectedCategory = nil
                            hasSelection = false
                        }
                    )
                    .frame(width: 260)
                    .offset(x: -212, y: max(0, selectionY - 20))
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                    .animation(.easeOut(duration: 0.2), value: showCommentCard)
                } else if hasSelection {
                    MarginToolbar(
                        onComment: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showCommentCard = true
                            }
                        }
                    )
                    .offset(y: max(0, selectionY - 14))
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.12), value: hasSelection)
                }
            }
            .frame(width: 48)
        }
        .background(Theme.background)
        .onAppear {
            titleText = store.document.title == "Untitled Document" ? "" : store.document.title
        }
        .onChange(of: store.document.id) { _, _ in
            titleText = store.document.title == "Untitled Document" ? "" : store.document.title
            showCommentCard = false
            commentText = ""
        }
        .onChange(of: showingAnnotationForm) { _, newValue in
            if newValue, selectedRange != nil, !selectedText.isEmpty {
                withAnimation(.easeOut(duration: 0.15)) {
                    hasSelection = true
                    showCommentCard = true
                }
                showingAnnotationForm = false
            }
        }
    }
}

// MARK: - Margin Toolbar

struct MarginToolbar: View {
    let onComment: () -> Void

    var body: some View {
        Button(action: onComment) {
            Image(systemName: "plus.bubble")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Theme.subtext0)
                .frame(width: 32, height: 32)
                .background(Theme.surface0)
                .clipShape(Circle())
                .shadow(
                    color: Theme.Shadow.subtle.color,
                    radius: Theme.Shadow.subtle.radius,
                    x: Theme.Shadow.subtle.x,
                    y: Theme.Shadow.subtle.y
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help("Add comment (⌘⇧A)")
        .padding(.trailing, 8)
    }
}

// MARK: - Comment Card

struct CommentCard: View {
    @Binding var commentText: String
    @Binding var category: AnnotationCategory?
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category selector — inline pills
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

            // Comment text field
            TextField("Add a comment...", text: $commentText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(Theme.primaryText)
                .lineLimit(2...6)
                .focused($isFocused)
                .onSubmit {
                    if !commentText.isEmpty {
                        onSubmit()
                    }
                }

            // Action buttons — right-aligned
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.subtext0)

                Button {
                    onSubmit()
                } label: {
                    Text("Comment")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(commentText.isEmpty ? Theme.overlay0 : Theme.base)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(commentText.isEmpty ? Theme.surface1 : Theme.primary)
                        .cornerRadius(Theme.radiusMD)
                }
                .buttonStyle(.plain)
                .disabled(commentText.isEmpty)
            }
        }
        .padding(12)
        .background(Theme.mantle)
        .cornerRadius(Theme.radiusLG)
        .shadow(
            color: Theme.Shadow.card.color,
            radius: Theme.Shadow.card.radius,
            x: Theme.Shadow.card.x,
            y: Theme.Shadow.card.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLG)
                .stroke(Theme.surface1.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Annotated Text Editor

struct AnnotatedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let annotations: [Annotation]
    let selectedAnnotationId: UUID?
    let onSelectionChange: (NSRange?, String, CGFloat?) -> Void
    let onAnnotationClick: (UUID) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: Theme.editorFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: Theme.editorInsetH, height: Theme.editorInsetV)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true

        // Theme
        textView.backgroundColor = NSColor.themeBase
        textView.textColor = NSColor.themeText

        // Line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = Theme.editorLineSpacing
        textView.defaultParagraphStyle = paragraphStyle

        textView.insertionPointColor = NSColor.themePrimary

        // Scroll view
        scrollView.backgroundColor = NSColor.themeBase
        scrollView.drawsBackground = true

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        applyHighlights(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyHighlights(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.themeText, range: fullRange)

        for annotation in annotations {
            let range = NSRange(
                location: annotation.range.startOffset,
                length: annotation.range.endOffset - annotation.range.startOffset
            )

            guard range.location >= 0 && range.location + range.length <= textStorage.length else {
                continue
            }

            let isSelected = annotation.id == selectedAnnotationId
            let highlightColor = isSelected ? Theme.annotationHighlightSelected : Theme.annotationHighlight
            let alpha: CGFloat = isSelected ? 0.3 : 0.12

            textStorage.addAttribute(
                .backgroundColor,
                value: NSColor(highlightColor).withAlphaComponent(alpha),
                range: range
            )
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AnnotatedTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?

        init(_ parent: AnnotatedTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let selectedRange = textView.selectedRange()
            if selectedRange.length > 0 {
                let text = (textView.string as NSString).substring(with: selectedRange)

                let layoutManager = textView.layoutManager!
                let textContainer = textView.textContainer!
                var glyphRange = NSRange()
                layoutManager.characterRange(forGlyphRange: selectedRange, actualGlyphRange: &glyphRange)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                let textContainerOrigin = textView.textContainerOrigin
                let yPosition = rect.minY + textContainerOrigin.y

                parent.onSelectionChange(selectedRange, text, yPosition)
            } else {
                parent.onSelectionChange(nil, "", nil)
            }
        }
    }
}
