import SwiftUI
import UniformTypeIdentifiers

@main
struct QuillApp: App {
    @StateObject private var store = DocumentStore()
    @StateObject private var agentWatcher = AgentResponseWatcher()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showingSidebar: Bool = true

    var body: some Scene {
        WindowGroup {
            ContentView(showingSidebar: $showingSidebar)
                .environmentObject(store)
                .environmentObject(agentWatcher)
                .frame(minWidth: 800, minHeight: 600)
                .background(Theme.background)
                .preferredColorScheme(.dark)
                .onAppear {
                    agentWatcher.startWatching()
                }
                .onDisappear {
                    agentWatcher.stopWatching()
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleFileDrop(providers)
                }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    store.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open...") {
                    openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            // MARK: - Edit Menu (standard items are automatic, add Find)
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Find...") {
                    NotificationCenter.default.post(name: .showFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // MARK: - View Menu
            CommandGroup(replacing: .sidebar) {
                Button(showingSidebar ? "Hide Sidebar" : "Show Sidebar") {
                    withAnimation {
                        showingSidebar.toggle()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            // MARK: - Annotations Menu
            CommandMenu("Annotations") {
                Button("Add Annotation") {
                    NotificationCenter.default.post(name: .addAnnotation, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Divider()

                Button("Next Annotation") {
                    store.navigateToNext()
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Previous Annotation") {
                    store.navigateToPrevious()
                }
                .keyboardShortcut("[", modifiers: .command)

                Divider()

                Button("Resolve Selected") {
                    if let id = store.selectedAnnotationId {
                        store.resolveAnnotation(id)
                    }
                }
                .disabled(store.selectedAnnotationId == nil)

                Button("Delete Selected") {
                    if let id = store.selectedAnnotationId {
                        store.deleteAnnotation(id)
                    }
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(store.selectedAnnotationId == nil)

                Divider()

                Button("Clear All Resolved") {
                    store.clearResolvedAnnotations()
                }
            }

            // MARK: - Export Menu
            CommandMenu("Export") {
                Button("Copy Prompt") {
                    copyPrompt()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Export for CLI") {
                    exportForCLI()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            // MARK: - Agent Menu
            CommandMenu("Agent") {
                if agentWatcher.hasUnreadResponses {
                    Button("View Agent Responses (\(agentWatcher.responses?.annotationResponses.count ?? 0))") {
                        agentWatcher.markAllRead()
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                } else {
                    Text("No agent responses")
                        .foregroundColor(.secondary)
                }

                Divider()

                if let updates = agentWatcher.responses?.documentUpdates, !updates.isEmpty {
                    ForEach(updates.prefix(3)) { update in
                        Button("Accept: \(update.summary.prefix(40))...") {
                            agentWatcher.acceptDocumentUpdate(update, store: store)
                        }
                    }

                    Divider()
                }

                Button("Clear Agent Responses") {
                    agentWatcher.clearResponses()
                }

                Divider()

                Button("Copy MCP Config") {
                    let config = """
                    {
                      "mcpServers": {
                        "quill": {
                          "command": "node",
                          "args": ["\(FileManager.default.homeDirectoryForCurrentUser.path)/quill-mcp/dist/index.js"]
                        }
                      }
                    }
                    """
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(config, forType: .string)
                }
                .help("Copy MCP server config for Claude Code or Cursor")
            }

            // MARK: - Help Menu additions
            CommandGroup(replacing: .help) {
                Button("Quill Help") {
                    // Open help
                }

                Divider()

                Button("Keyboard Shortcuts") {
                    showKeyboardShortcuts()
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }

        // Settings window (Cmd+,)
        Settings {
            SettingsView()
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

    private func saveDocument() {
        try? store.exportForCLI()
    }

    private func copyPrompt() {
        let prompt = store.generatePrompt()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }

    private func exportForCLI() {
        try? store.exportForCLI()
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            DispatchQueue.main.async {
                try? store.openFile(at: url)
            }
        }
        return true
    }

    private func showKeyboardShortcuts() {
        // Now handled by ShortcutsSettingsView in settings
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("exportPath") private var exportPath: String = "~/.quill"
    @AppStorage("autoSave") private var autoSave: Bool = true
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = false

    var body: some View {
        TabView {
            GeneralSettingsView(autoSave: $autoSave, exportPath: $exportPath)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            EditorSettingsView(showLineNumbers: $showLineNumbers)
                .tabItem {
                    Label("Editor", systemImage: "text.alignleft")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 280)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

struct GeneralSettingsView: View {
    @Binding var autoSave: Bool
    @Binding var exportPath: String

    var body: some View {
        Form {
            Toggle("Auto-save changes", isOn: $autoSave)

            LabeledContent("Export path:") {
                TextField("Path", text: $exportPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }
        }
        .padding()
        .background(Theme.background)
    }
}

struct EditorSettingsView: View {
    @Binding var showLineNumbers: Bool

    var body: some View {
        Form {
            Toggle("Show line numbers", isOn: $showLineNumbers)
        }
        .padding()
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Cmd+Shift+A").font(.system(.body, design: .monospaced))
                    Text("Add Annotation")
                }
                GridRow {
                    Text("Cmd+]").font(.system(.body, design: .monospaced))
                    Text("Next Annotation")
                }
                GridRow {
                    Text("Cmd+[").font(.system(.body, design: .monospaced))
                    Text("Previous Annotation")
                }
                GridRow {
                    Text("Delete").font(.system(.body, design: .monospaced))
                    Text("Delete Selected")
                }
                GridRow {
                    Text("Cmd+Shift+C").font(.system(.body, design: .monospaced))
                    Text("Copy Prompt")
                }
                GridRow {
                    Text("Cmd+Ctrl+S").font(.system(.body, design: .monospaced))
                    Text("Toggle Sidebar")
                }
            }
            .foregroundColor(Theme.primaryText)
        }
        .padding()
        .background(Theme.background)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for existing instance
        let runningApps = NSWorkspace.shared.runningApplications
        let quillApps = runningApps.filter { $0.bundleIdentifier == "com.samuelz.quill" || $0.localizedName == "Quill" }

        if quillApps.count > 1 {
            if let existingApp = quillApps.first(where: { $0 != NSRunningApplication.current }) {
                existingApp.activate()
            }
            NSApp.terminate(nil)
        }

        // Set window frame autosave name for persistence (HIG 2.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.windows.first?.setFrameAutosaveName("QuillMainWindow")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let addAnnotation = Notification.Name("addAnnotation")
    static let showFind = Notification.Name("showFind")
}
