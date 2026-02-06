import SwiftUI
import AppKit

struct EditorView: View {
    @EnvironmentObject var store: DocumentStore
    @Binding var selectedRange: NSRange?
    @Binding var selectedText: String
    @Binding var showingAnnotationForm: Bool

    @State private var titleText: String = ""

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
                    .padding(.bottom, 24)
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
                    },
                    onAnnotationClick: { id in
                        store.selectAnnotation(id)
                    }
                )
                .padding(24)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .onAppear {
            titleText = store.document.title == "Untitled Document" ? "" : store.document.title
        }
        .onChange(of: store.document.id) { _, _ in
            titleText = store.document.title == "Untitled Document" ? "" : store.document.title
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
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true

        // Apply theme colors
        textView.backgroundColor = NSColor.themeBase
        textView.textColor = NSColor.themeText
        
        // Line spacing for reading comfort
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        textView.defaultParagraphStyle = paragraphStyle
        
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
