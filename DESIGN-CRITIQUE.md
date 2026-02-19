# Quill Design Critique

**Date:** 2026-02-12
**Method:** Interface Craft Design Critique (Josh Puckett methodology)

---

## Context

Quill is a macOS native document annotation app for writers working with AI agents. Users open text documents, highlight passages, attach categorized comments (Voice, Clarity, Structure, etc.), and an AI agent responds with suggestions, clarifications, or resolutions. The target user is a developer or writer using Claude Code/Cursor who wants bidirectional document review. The emotional context is **focused, iterative craft** — the user is polishing writing and expects a tool that respects the seriousness of that work.

## First Impressions

The architecture reads like a competent Google Docs clone attempting to live inside Catppuccin Mocha. The two-panel layout (editor left, sidebar right) with a right-margin comment trigger is a well-understood pattern. What stands out immediately is *how much* is crammed into the annotation sidebar — filter pills, category selectors, severity sorting, agent response badges with nested threads, accept/reject buttons, reply inputs, diff previews — all within a 280–400px column. The app has a clear concept (human annotates, agent responds), but the interface doesn't differentiate between the two most critical modes: **authoring annotations** and **reviewing agent responses**. Everything shares the same visual weight, the same narrow column, the same muted Catppuccin palette. The result is an interface that's *technically functional* but emotionally flat — there's no sense of collaboration happening, no visual conversation.

## Visual Design

**Monochromatic soup** — The Catppuccin Mocha palette gives the app 6 distinct background tones (`crust` through `surface2`), 6 text tones (`text` through `overlay0`), and 14 accent colors — but in practice, the interface reads as one continuous dark grey. The sidebar uses `Theme.mantle` (#181825), the editor uses `Theme.base` (#1e1e2e), and the annotation cards use no background or `surface0.opacity(0.5)` on hover. The luminance difference between these is ~3-5%. The boundary between editor and sidebar is nearly invisible. Two distinct functional zones are not visually separated.

**Accent color overload without hierarchy** — Six category colors (purple, blue, green, orange, pink, teal), plus four agent response colors (green, yellow, blue, red), plus the peach primary accent, plus blue for the AI indicator badge — that's 11 distinct accent colors competing within a 280px sidebar column. None of these colors is used at sufficient saturation or area to establish meaning. The 5-6px colored dots on category pills are too small to register as a color system. Users must read the label to understand the category; the color adds no information.

**Typography lacks clear hierarchy** — At least 8 distinct font sizes in the sidebar alone: 13pt (section header), 13pt (comment text), 12pt (agent suggestion toggle), 11pt (selected text preview, filter pills, reply input), 10pt (category labels, action labels, "Resolve" text), 9pt (thread count, severity icon size), 8pt (sparkle icon, thread icons). The difference between 10pt and 11pt is imperceptible — these are noise, not hierarchy. The comment text (13pt) and the section header "Comments" (13pt semibold) are the same size; only weight differentiates them.

**Shadows are wasted on the wrong elements** — The `MarginToolbar` bubble gets a shadow (the `plus.bubble` circle), but annotation cards — the primary interactive elements in the sidebar — get no elevation treatment. The comment card floating over the editor gets appropriate shadow, but it's the only element that does.

**Spacing inconsistency between card interiors** — The annotation card uses 12pt padding internally, the agent response badge nested inside it uses 10pt padding, and the inline annotation form uses 12pt padding with a 10pt-padded text field inside. Three nesting levels of similar-but-not-identical padding create subtle visual unease.

## Interface Design

**No focusing mechanism between modes** — The sidebar treats "you have 0 comments" and "you have 12 comments with 3 agent responses" identically. There's no visual distinction between a sidebar that needs your attention (agent responded) and one that doesn't. The "AI" badge in the header is the only signal, competing with the filter toggle at the same visual weight.

**We're missing an opportunity to separate human authoring from agent collaboration.** The annotation card embeds the `AgentResponseBadge` inline, making it look like a subcomponent rather than a distinct turn in a conversation. Human comment → agent response → human reply should read as a conversation, not nested widgets.

**Redundant annotation entry points create confusion** — Users can add comments via: (1) the right-margin `plus.bubble` button → `CommentCard` overlay, or (2) `Cmd+Shift+A` → `InlineAnnotationForm` in sidebar. Different field layouts, different submit labels ("Comment" vs "Save"), different category selectors (popover vs inline pills).

**We're missing an opportunity to show progress through the document.** Annotations sorted by severity then offset, but no minimap, scroll indicator, or position tracker.

**Information density is too high in AgentResponseBadge** — A single agent suggestion can contain 12 interactive/informational elements inside a 280px-wide nested card.

## Consistency & Conventions

**Two comment creation flows that don't match** — `CommentCard` uses popover for categories + "Cancel"/"Comment" buttons. `InlineAnnotationForm` uses inline pills + "xmark"/"Save". Same action, different vocabulary.

**Category pill inconsistency** — `FilterPill` uses `cornerRadius(12)`. `CategoryPill` uses `cornerRadius(10)` with different backgrounds and border treatments.

**Platform convention misses** — FindBarView "Done" text button vs standard xmark icon. Inconsistent `onHover` cursor changes.

**Resolved state treatment is timid** — `opacity(0.7)` but full-height cards. Convention is to collapse or hide.

## User Context

The user feels like they're managing a system, not having a conversation. Every metadata field competes equally. A user reviewing agent responses should feel like reading replies, not parsing dashboards.

Uncommon care: When agent responds to 5 annotations, sidebar could enter "review mode" — only showing responded annotations with accept/dismiss at the top level.

## Top Opportunities (Prioritized)

1. **Unify comment creation flows** — One component, one vocabulary ("Comment"), one category selector pattern. Right-margin trigger and Cmd+Shift+A should open the same UI.

2. **Create agent review mode** — Focused list when agent responses arrive: responded annotations with accept/dismiss at top level, not buried in nested cards.

3. **Reduce accent colors to 3-4 functional colors** — One for human annotations, one for agent responses, one for resolved/success, one for primary actions. Replace 6 category dots with text labels.

4. **Flatten AgentResponseBadge hierarchy** — Separate agent message from thread/reply. Show action + message as primary; collapse thread, diffs, replies behind single expand.

5. **Add spatial progress indicator** — "Annotation 3 of 12 · Line 47" in sidebar header for position and momentum.
