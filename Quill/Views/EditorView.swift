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
                // Title
                TextField("Untitled Document", text: $titleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    .onChange(of: titleText) { _, newValue in
                        store.updateTitle(newValue)
                    }

                Divider()
                    .background(Theme.border)
                    .padding(.horizontal, 24)

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
                            selectionY = y + 100 // Offset for title area
                            hasSelection = true
                        } else {
                            hasSelection = false
                            if !showCommentCard {
                                // Only hide if comment card isn't open
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

            // Right margin for comments (Google Docs style)
            ZStack(alignment: .topTrailing) {
                // Margin background
                Rectangle()
                    .fill(Theme.background)
                    .frame(width: 60)

                // Comment icon or card
                if showCommentCard {
                    // Comment card (expanded form)
                    CommentCard(
                        commentText: $commentText,
                        category: $selectedCategory,
                        onCancel: {
                            showCommentCard = false
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
                            showCommentCard = false
                            commentText = ""
                            selectedCategory = nil
                            hasSelection = false
                        }
                    )
                    .frame(width: 280)
                    .offset(x: -220, y: max(0, selectionY - 20))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .animation(.easeOut(duration: 0.2), value: showCommentCard)
                } else if hasSelection {
                    // Comment icon toolbar
                    MarginToolbar(
                        onComment: {
                            showCommentCard = true
                        }
                    )
                    .offset(y: max(0, selectionY - 10))
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.15), value: hasSelection)
                }
            }
            .frame(width: 60)
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
    }
}

// MARK: - Margin Toolbar (Google Docs style icons)

struct MarginToolbar: View {
    let onComment: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onComment) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(Theme.surface0)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .help("Add comment")
        }
        .padding(.trailing, 12)
    }
}

// MARK: - Comment Card (Google Docs style)

struct CommentCard: View {
    @Binding var commentText: String
    @Binding var category: AnnotationCategory?
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool
    @State private var showCategories: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category selector (optional, small)
            HStack {
                Button {
                    showCategories.toggle()
                } label: {
                    HStack(spacing: 4) {
                        if let cat = category {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 8, height: 8)
                            Text(cat.label)
                                .font(.caption)
                        } else {
                            Text("General")
                                .font(.caption)
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCategories) {
                    VStack(alignment: .leading, spacing: 4) {
                        Button("General") {
                            category = nil
                            showCategories = false
                        }
                        .buttonStyle(.plain)

                        Divider()

                        ForEach(AnnotationCategory.allCases, id: \.self) { cat in
                            Button {
                                category = cat
                                showCategories = false
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(cat.color)
                                        .frame(width: 8, height: 8)
                                    Text(cat.label)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }

                Spacer()
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

            // Action buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.secondaryText)

                Button("Comment") {
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                .controlSize(.small)
                .disabled(commentText.isEmpty)
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
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
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true

        // Apply theme colors
        textView.backgroundColor = NSColor.themeBase
        textView.textColor = NSColor.themeText
        textView.insertionPointColor = NSColor.themePrimary

        // Scroll view styling
        scrollView.backgroundColor = NSColor.themeBase
        scrollView.drawsBackground = true

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView

        // Update text if changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Apply annotation highlights
        applyHighlights(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyHighlights(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        // Remove existing highlights and reset text color
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.themeText, range: fullRange)

        // Apply annotation highlights
        for annotation in annotations {
            let range = NSRange(
                location: annotation.range.startOffset,
                length: annotation.range.endOffset - annotation.range.startOffset
            )

            guard range.location >= 0 && range.location + range.length <= textStorage.length else {
                continue
            }

            let isSelected = annotation.id == selectedAnnotationId
            let baseColor = annotation.severity.color
            let alpha: CGFloat = isSelected ? 0.4 : 0.2

            textStorage.addAttribute(
                .backgroundColor,
                value: NSColor(baseColor).withAlphaComponent(alpha),
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

                // Get the Y position for the selection
                let layoutManager = textView.layoutManager!
                let textContainer = textView.textContainer!
                var glyphRange = NSRange()
                layoutManager.characterRange(forGlyphRange: selectedRange, actualGlyphRange: &glyphRange)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                // Get Y position relative to scroll view
                let textContainerOrigin = textView.textContainerOrigin
                let yPosition = rect.minY + textContainerOrigin.y

                parent.onSelectionChange(selectedRange, text, yPosition)
            } else {
                parent.onSelectionChange(nil, "", nil)
            }
        }
    }
}
