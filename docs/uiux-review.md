# Muse Code Desktop — UI/UX Review

**Date:** 2026-10-07 · **Branch:** `devin/v010-release` (HEAD d04d4ea) · **Build:** debug via `scripts/swift-local.sh` + `scripts/build-app.sh`
**Mode:** `--echo` + `MuseReviewHost` fixture, workspace `/Users/devin/muse-fixture-ws`. No real provider was contacted; all transcript content below is synthetic fixture output.
**Method:** manual GUI driving (mouse clicks, typing, keyboard shortcuts, window resize) + accessibility tree + source tracing. Screenshots in `docs/media/` (cropped to window bounds).

> **Status:** all findings below were fixed and shipped in
> [v0.1.0](https://github.com/anon5376/muse-code-desktop/releases/tag/v0.1.0)
> (squash `ac3099c`). The report is preserved as written.

## Findings

### 1. MAJOR — Command palette rows keep stale content and stale actions when filtering
- **Surface:** ⌘K palette (`LibraryView.swift`)
- **Observed:** Typing a query that should filter to action rows (e.g. `goal`, `session`, `controls`, `files`) left a stale "/Synthetic review" skill row visible while matching actions disappeared. Activating that stale row ran the *wrong* action — it attached the skill chip instead of opening e.g. Session controls.
- **Expected:** Rows always render the entry at their index; activating row N runs entry N's action.
- **Cause:** rows were tagged `.id(index)` inside `ForEach(..., id: \.element.id)`. Positional `.id` overrides the element key, so SwiftUI reused each row's content *and* its captured `action` closure across filter changes. Verified by instrumenting `entries` — the data layer computed correctly; only the view recycled stale cells.
- **Status:** **fixed in the working tree as proof** (uncommitted — task forbids commits): `.id(index)` → `.id(entry.id)` and a bounds-checked `proxy.scrollTo(entries[value].id)`. Filtering now renders correct rows and correct actions.
- **Suggested fix:** ship that change plus a UI/unit regression that types a filter and activates the first row.

### 2. MAJOR — Skill chip attached on workspace home is rejected at send time
- **Surface:** palette "+ /synthetic-review" → composer chip → send
- **Observed:** On workspace home (no session), the palette offers the installed skill; attaching renders a chip, but send fails with "This skill is not available in the session."
- **Expected:** either the chip can't be attached before a session exists, or it resolves at send time.
- **Cause:** `WorkspaceStore.send()` matches the pending skill against the *session* `skill/list` by `selector` (or `selector == invocationName`). CLI-catalog skills (from `CLICatalog.read`) have `selector == nil` and `invocationName` = display name ("Synthetic review"), while the session selector is `synthetic-review` — no match → throw. `StoreTests` cover a different fabricated selector-less path, not this catalog-shape mismatch.
- **Suggested fix:** hide/disable the skill entry (and chip affordance) when `!hasLoadedSession`, or normalize `invocationName` to the invocation slug (kebab-case) so the session-catalog match succeeds.

### 3. MAJOR — Expand/collapse controls in the Workspace inspector are inert
- **Surface:** Inspector (⌘⌥I) → Skills tab DisclosureGroup rows, Files tab OutlineGroup folder chevrons
- **Observed:** Skill rows won't expand via chevron, label, or double-click (three separate attempts) — the "Use in chat" button and skill details are unreachable. File-tree folders `docs/` and `src/` also won't expand (top-level files selectable + preview works). AX tree exposes `disclosuretriangle "Synthetic review, Bundled"` with a `press` action, but AXPress fails with `AXError(-25200)`.
- **Expected:** disclosure expands to show description, `/name`, and "Use in chat"; folders expand.
- **Noteworthy:** the transcript's `DisclosureGroup` ("Complete permission details") *does* expand — failure is scoped to the inspector panel.
- **Suggested fix:** debug hit-testing/state in the inspector container (likely view recreation or a swallowed gesture); add a regression that expands a skill row.

### 4. MAJOR — Settings "Test local connection" fails in the app's own fixture mode
- **Surface:** ⌘, settings sheet → "Test local connection"
- **Observed:** "Failed: Muse protocol error: echo reply was not preserved" — while sessions send and resolve fine in the same fixture session.
- **Expected:** self-test passes in offline fixture mode, or states "expected to fail offline."
- **Impact:** a diagnostic that contradicts the working app reads as "broken install."
- **Suggested fix:** make the probe honor `--echo`/fixture mode, or special-case the result message.

### 5. MINOR — "Complete permission details" buried at the bottom of the command scroll
- **Surface:** approval card (40-line synthetic command)
- **Observed:** the details disclosure sits *after* the full command inside a 112pt-max-height scroll region — users scroll past all 40 lines to find it, and the scroll area mixes command text with the disclosure.
- **Suggested fix:** move the disclosure outside the command `ScrollView` (pin it above/below), or show command tail with a "show all" affordance.

### 6. MINOR — Suggestion cards silently overwrite a non-empty composer draft
- **Surface:** workspace home suggestion cards
- **Observed:** clicking "Survey this project" replaced an existing `@package.json` draft — prior text lost, no undo.
- **Suggested fix:** only fill when the composer is empty, or append/confirm.

### 7. MINOR — Text clips mid-glyph instead of ellipsizing
- **Surface:** "Continue" session row on home; suggestion-card descriptions when the inspector overlays
- **Observed:** "Inspect this project and identify the three most important improvem|" is cut at the row edge; card copy is cut at the inspector seam.
- **Suggested fix:** `.lineLimit(1).truncationMode(.tail)` on these labels.

### 8. MINOR — Inspector overlays the canvas instead of resizing it
- **Surface:** inspector panel
- **Observed:** at ~980×640 min size the inspector covers ~40% of the canvas and home content flows beneath it (see finding 7 for the visible clip). Palette/palette bounds still fine; composer and sidebar stay usable.
- **Suggested fix:** acceptable as overlay, but consider compressing the canvas region or a narrower/close-on-outside-click inspector at min widths.

### 9. POLISH — Skill "Source" label inconsistent across catalogs
- **Surface:** Skills inspector
- **Observed:** same skill shows "Bundled" before a session (CLI catalog) and "Unknown" in-session (session catalog lacks `source`).
- **Suggested fix:** map missing session source to a stable label (or carry the CLI source through).

### 10. POLISH — Model picker affordances look clickable but aren't in fixture mode
- **Surface:** model picker popover
- **Observed:** the single `synthetic-model` row is disabled (correct: no session/no provider) with no in-row cue; "Muse default" renders in accent color implying a menu, but the model reports no efforts so no menu exists.
- **Suggested fix:** add the existing honest pattern — a caption like "Offline fixture: model selection disabled" — and render the reasoning value in secondary when no menu exists.

### 11. POLISH — Settings sheet transient text overlap during open animation at min size
- **Surface:** ⌘, sheet
- **Observed:** one screenshot caught underlying home text composited over sheet copy mid-animation; it self-resolves into a clean opaque sheet.
- **Suggested fix:** low priority; verify sheet transition on min-size windows.

## Verified working (no action needed)
- **Offline honesty, layered:** banner "Offline UI fixture · synthetic data, no provider or tools", pill "Fixture · offline", sidebar "Offline fixture", settings "Muse synthetic-fixture · Offline fixture", model picker "Test catalog". Fixture labeling is discoverable everywhere it matters.
- **Markdown transcript:** H2, bold, bullets, blockquote, table, `swift` code fence with lang badge + Copy — all correct.
- **Approval flow:** 40-line command scrolls, choices pinned below, allow-once resolves cleanly.
- **userInput question card:** options render and resolve.
- **Send:** both ⌘Return and the ↑ button create the session; sidebar row appears instantly; ⌘N returns home showing an honest "Continue" row.
- **Palette:** ⌘K, type-ahead, ↑↓/Return activation, Esc and × dismissal, footer hints, skill + action mixing (post-fix).
- **Empty states:** "Tools, agents and workflows appear here as Muse works.", "Your sessions will appear here."
- **Settings copy:** "not the official Muse Code desktop app and is not affiliated with or endorsed by Meta" — exemplary disclaimer; "Run a shell command" honestly shows "This host has not enabled shell commands."
- **Min size ~980×640:** composer, sidebar, palette, model pill all remain usable.
- **Composer "+" menu:** Add from workspace / Use a skill… / Session controls… opens correctly.
- **File mention:** "Add to message" inserts `@filename` into the composer.

## Could NOT verify (fixture limits / scope)
- Real provider paths: model selection, effort picker, data-use notices, real streaming, real tool grants.
- Durable session history across relaunch; session rename/fork/compact execution.
- "userMessage" transcript rows — `TranscriptView` renders them, but `ReviewHost` never emits one (fixture gap, not an app bug).
- "Add from workspace", "Open in default editor", "Copy login command", "Open Terminal", Terminal/voice paths, ⌘O workspace switching, sidebar ⌘⌃S toggle.
- Whether finding 3 affects real sessions (it reproduced on two separate controls in the inspector).

## Repo state note
The working tree contains one **uncommitted demonstration fix** for finding 1 (`Sources/MuseDesktop/LibraryView.swift`, `.id(entry.id)` + bounds-checked `scrollTo`). No commits, pushes, or PRs were made.

## Screenshots
`docs/review-shots/`: 01 workspace home · 02 palette · 03 transcript markdown · 04 approval card · 05 question card · 06 model picker · 07 skills tab · 08 file preview · 09 home continue row · 10 min-size layout · 11 settings self-test failure · 12 composer + menu · 13 palette in-session · 14 session transcript.
