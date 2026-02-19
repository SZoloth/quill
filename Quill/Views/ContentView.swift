import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DocumentStore
    @Binding var showingSidebar: Bool
    @State private var showingAnnotationForm = false
    @State private var selectedRange: NSRange?
    @State private var selectedText: String = ""
    @State private var showingFindBar = false

    @EnvironmentObject var agentWatcher: AgentResponseWatcher

    /// The latest unaccepted document update from the agent
    private var pendingUpdate: AgentDocumentUpdate? {
        agentWatcher.responses?.documentUpdates.last
    }

    @State private var dismissedUpdateTimestamp: String?

    var body: some View {
        HSplitView {
            // Editor (now on LEFT)
            VStack(spacing: 0) {
                // Agent document update banner
                if let update = pendingUpdate,
                   update.timestamp != dismissedUpdateTimestamp {
                    AgentUpdateBanner(
                        update: update,
                        onAccept: {
                            agentWatcher.acceptDocumentUpdate(update, store: store)
                            dismissedUpdateTimestamp = update.timestamp
                        },
                        onDismiss: {
                            dismissedUpdateTimestamp = update.timestamp
                        }
                    )
                }

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

            // Document title — primary orienting element
            ToolbarItem(placement: .principal) {
                Text(store.document.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 300)
            }

            // Trailing: Export actions
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                    .frame(width: 4)

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

// MARK: - Agent Update Banner

struct AgentUpdateBanner: View {
    let update: AgentDocumentUpdate
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 12))
                .foregroundColor(Theme.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Agent revised your document")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(update.summary)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.subtext0)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onAccept()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Accept")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Theme.base)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Theme.green)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.subtext0)
                    .frame(width: 24, height: 24)
                    .background(Theme.surface1.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.blue.opacity(0.08))
        .overlay(
            Divider().background(Theme.blue.opacity(0.2)),
            alignment: .bottom
        )
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
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.subtext0)
            }
            .buttonStyle(.plain)
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
