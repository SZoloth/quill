import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DocumentStore
    @Binding var showingSidebar: Bool
    @State private var showingAnnotationForm = false
    @State private var selectedRange: NSRange?
    @State private var selectedText: String = ""
    @State private var showingFindBar = false

    var body: some View {
        HSplitView {
            // Editor (now on LEFT)
            VStack(spacing: 0) {
                // Find bar (appears when Cmd+F pressed)
                if showingFindBar {
                    FindBarView(isShowing: $showingFindBar)
                }

                EditorView(
                    selectedRange: $selectedRange,
                    selectedText: $selectedText,
                    showingAnnotationForm: $showingAnnotationForm
                )
            }
            .frame(minWidth: 500)

            // Sidebar (now on RIGHT) - toggleable via View menu
            if showingSidebar {
                AnnotationSidebar(
                    showingAnnotationForm: $showingAnnotationForm,
                    selectedText: selectedText,
                    selectedRange: selectedRange
                )
                .frame(minWidth: 280, maxWidth: 400)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Theme.background)
        .toolbar {
            // Leading: Open button with label
            ToolbarItem(placement: .navigation) {
                Button {
                    openDocument()
                } label: {
                    Label("Open", systemImage: "folder")
                        .labelStyle(.iconOnly)
                }
                .help("Open file (Cmd+O)")
            }

            // Flexible spacer before title
            ToolbarItem(placement: .principal) {
                HStack {
                    Spacer(minLength: 40)

                    Text(store.document.title)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.subtext0)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: 400)
            }

            // Trailing: Export actions with labels
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copyPrompt()
                } label: {
                    Label("Copy Prompt", systemImage: "doc.on.clipboard")
                        .labelStyle(.iconOnly)
                }
                .help("Copy prompt (Cmd+Shift+C)")

                Button {
                    exportForCLI()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .help("Export for CLI (Cmd+Shift+E)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addAnnotation)) { _ in
            if selectedRange != nil && !selectedText.isEmpty {
                showingAnnotationForm = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFind)) { _ in
            showingFindBar = true
        }
    }

    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            try? store.openFile(at: url)
        }
    }

    private func copyPrompt() {
        let prompt = store.generatePrompt()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }

    private func exportForCLI() {
        try? store.exportForCLI()
    }
}

// MARK: - Find Bar View

struct FindBarView: View {
    @Binding var isShowing: Bool
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.mutedText)

            TextField("Find in document...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(Theme.primaryText)
                .focused($isFocused)
                .onSubmit {
                    // TODO: Implement search
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.mutedText)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 16)

            Button {
                isShowing = false
            } label: {
                Text("Done")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface0)
        .overlay(
            Divider().background(Theme.surface1.opacity(0.5)),
            alignment: .bottom
        )
        .onAppear {
            isFocused = true
        }
        .onExitCommand {
            isShowing = false
        }
    }
}
