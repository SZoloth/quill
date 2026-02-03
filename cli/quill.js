#!/usr/bin/env node

/**
 * Quill CLI - Bridge between Quill.app and Claude Code
 *
 * Commands:
 *   quill           Show current prompt from ~/.quill/document.json
 *   quill edit      Open Claude Code with the prompt
 *   quill humanize  Run compound-writing skill on the document
 *   quill watch     Watch for changes and notify
 *   quill status    Show document info
 */

const fs = require("fs");
const path = require("path");
const { spawn, execFileSync } = require("child_process");
const os = require("os");

const QUILL_DIR = path.join(os.homedir(), ".quill");
const DOC_PATH = path.join(QUILL_DIR, "document.json");

function loadDocument() {
  if (!fs.existsSync(DOC_PATH)) {
    console.error("No document found at ~/.quill/document.json");
    console.error("Open a file in Quill first.");
    process.exit(1);
  }

  try {
    const data = fs.readFileSync(DOC_PATH, "utf8");
    return JSON.parse(data);
  } catch (e) {
    console.error("Failed to parse document.json:", e.message);
    process.exit(1);
  }
}

function showPrompt() {
  const doc = loadDocument();
  console.log(doc.prompt);
}

function showStatus() {
  const doc = loadDocument();
  const unresolvedCount = doc.annotations?.length || 0;

  console.log(`📄 ${doc.title || doc.filename || "Untitled"}`);
  console.log(`   ${doc.wordCount} words`);
  console.log(`   ${unresolvedCount} annotation${unresolvedCount !== 1 ? "s" : ""}`);

  if (doc.filepath) {
    console.log(`   ${doc.filepath}`);
  }

  if (unresolvedCount > 0) {
    console.log("\n📝 Annotations:");
    doc.annotations.forEach((ann, i) => {
      const preview = ann.text.slice(0, 40) + (ann.text.length > 40 ? "..." : "");
      const category = ann.category ? `[${ann.category}]` : "";
      console.log(`   ${i + 1}. ${category} "${preview}" - ${ann.comment}`);
    });
  }
}

function openInClaude() {
  const doc = loadDocument();

  if (!doc.annotations?.length) {
    console.log("No annotations to process. Add some feedback in Quill first.");
    process.exit(0);
  }

  // Build the prompt for Claude Code
  const prompt = `${doc.prompt}

## Full Document Content

\`\`\`
${doc.content}
\`\`\``;

  // Launch Claude Code with the prompt using spawn (no shell)
  console.log(`Opening Claude Code with ${doc.annotations.length} annotation(s)...`);

  const claude = spawn("claude", ["-p", prompt], {
    stdio: "inherit",
  });

  claude.on("error", (err) => {
    console.error("Failed to launch Claude Code:", err.message);
    console.error("Make sure 'claude' is in your PATH");
    process.exit(1);
  });
}

function humanize() {
  const doc = loadDocument();

  // Build a compound-writing specific prompt
  const prompt = `/compound-writing

## Document to Humanize

**File:** ${doc.filepath || doc.filename || doc.title}
**Word Count:** ${doc.wordCount}

### Author Annotations

The author has marked these specific issues for revision:

${doc.annotations?.map((ann, i) => {
  const category = ann.category ? `[${ann.category}]` : "[General]";
  return `${i + 1}. ${category} "${ann.text.slice(0, 60)}${ann.text.length > 60 ? "..." : ""}"
   → ${ann.comment}`;
}).join("\n\n") || "No specific annotations"}

### Full Content

\`\`\`
${doc.content}
\`\`\`

Please run the two-pass humanization system:
1. Diagnose the text for AI tells and address the author's annotations
2. Reconstruct with the feedback addressed while maintaining natural voice`;

  console.log(`Running compound-writing on "${doc.title || doc.filename}"...`);
  console.log(`${doc.annotations?.length || 0} annotation(s) to address\n`);

  const claude = spawn("claude", ["-p", prompt], {
    stdio: "inherit",
  });

  claude.on("error", (err) => {
    console.error("Failed to launch Claude Code:", err.message);
    process.exit(1);
  });
}

function watch() {
  console.log("Watching ~/.quill/document.json for changes...");
  console.log("Press Ctrl+C to stop\n");

  let lastMtime = null;

  const check = () => {
    try {
      const stat = fs.statSync(DOC_PATH);
      const mtime = stat.mtime.getTime();

      if (lastMtime && mtime !== lastMtime) {
        const doc = loadDocument();
        const count = doc.annotations?.length || 0;

        // macOS notification using execFileSync (no shell)
        try {
          execFileSync("osascript", [
            "-e",
            `display notification "${count} annotation(s) ready" with title "Quill Updated"`,
          ]);
        } catch {}

        console.log(
          `[${new Date().toLocaleTimeString()}] Document updated: ${count} annotation(s)`
        );
      }

      lastMtime = mtime;
    } catch {}
  };

  // Check every 2 seconds
  setInterval(check, 2000);
  check();
}

function copyPrompt() {
  const doc = loadDocument();

  try {
    // Use spawn with pipe instead of shell
    const pbcopy = spawn("pbcopy", [], { stdio: ["pipe", "inherit", "inherit"] });
    pbcopy.stdin.write(doc.prompt);
    pbcopy.stdin.end();
    pbcopy.on("close", () => {
      console.log("Prompt copied to clipboard");
    });
  } catch (e) {
    console.error("Failed to copy:", e.message);
    // Fallback: just print it
    console.log("\n" + doc.prompt);
  }
}

// Main
const args = process.argv.slice(2);
const command = args[0] || "prompt";

switch (command) {
  case "prompt":
  case "show":
    showPrompt();
    break;

  case "status":
  case "info":
    showStatus();
    break;

  case "edit":
  case "claude":
    openInClaude();
    break;

  case "humanize":
  case "compound":
    humanize();
    break;

  case "watch":
    watch();
    break;

  case "copy":
    copyPrompt();
    break;

  case "help":
  case "--help":
  case "-h":
    console.log(`Quill CLI - Bridge between Quill.app and Claude Code

Usage: quill [command]

Commands:
  (none)     Show current prompt from Quill
  status     Show document info and annotations
  edit       Open Claude Code with the prompt
  humanize   Run compound-writing humanization
  watch      Watch for changes and notify
  copy       Copy prompt to clipboard
  help       Show this help

Quill exports to ~/.quill/document.json on every save.
Use Cmd+Shift+E in Quill to force an export.`);
    break;

  default:
    console.error(`Unknown command: ${command}`);
    console.error("Run 'quill help' for usage");
    process.exit(1);
}
