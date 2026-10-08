# Response to the supplied Claude review

Current local candidate, 2026-10-08. The review identified useful defects, but inspected an earlier source/capture snapshot and performed no runtime checks.

## Protocol and lifecycle

- **P0-1, implicit approval: disproved by the installed schema.** MSP §5.3.3 defines `RequestReceipt` as an empty presentation acknowledgment, distinct from decision/submission acceptance. `approval/decide` and `userInput/answer` carry the user response separately. The code cites this contract. A synthetic host verifies two empty receipts and zero decisions before any explicit action. No real permission was granted during verification.
- **P1-1, inherited output pipe hang: repaired.** Host exit starts a bounded 250 ms output drain. Shutdown no longer waits indefinitely for descendants retaining stdout/stderr. App termination also has a five-second deadline and stopping feedback. The regression and independent final-frame check passed. Signaling an entire owned process group and proving no real tool descendants survive remain open; that guarantee is not claimed.
- **P2-4, stderr discarded: repaired.** The latest 8 KiB is retained in memory and exposed through collapsed Details. A synthetic startup failure checks the bound and retained final diagnostic. No stderr file is written.

Installed schema fingerprint: `sha256:61afea3112e0906e9dc3a536144278a74cb4b36fc6e20901a91d4432ba3568e2`. The local export identifies `RequestReceipt` at line 1058 and file-mention text semantics at line 2011.

## Implemented repairs

| Concern | Current behavior |
| --- | --- |
| Hidden approvals/questions | Persistent dock above the composer. Palette and compact inspector overlay only the reading region. Long bodies scroll; decision/answer buttons remain outside that scroll. |
| Default hides data use | Default resolves to a catalog entry. Composer names model/profile; amber Data use badge and full host notice appear when applicable. Only one row is selected. |
| Raw Markdown | Native headings, lists, blockquotes, fenced code, tables and rules, plus inline Foundation Markdown. Code has language and Copy. This bounded parser does not implement all CommonMark syntax. |
| Reasoning carryover/default | Per-session preferences plus a separate new-draft preference. Unsupported values clear. Default uses advertised variants. First-send ordering is regression-tested. |
| Command-N/draft loss | Unsaved draft; session creation waits for send. A created session owns rejected text for retry; an accepted retry consumes it. |
| Errors cross sessions | Action errors and terminal failures are retained with their session and connection generation; selection restores that session's error. |
| Title overwritten | Summary merging preserves a meaningful title and timestamp. |
| Workspace menu | Plain native label includes folder, name and chevron. |
| Approval styling/order | Amber heading/rule, distinct once/scoped/deny treatment, visible scope preview, arrival-order paging, Dock badge and app attention. Choice labels remain exact. |
| Agent controls | Actions follow reported control status; Stop and Close ask for confirmation. Live-agent behavior still needs testing. |
| Compact layout | Scrollable empty view, 44–200 pt editor, inspector overlay below 560 pt remaining centre width; bounded 380 × 500 pt model popover. Actual 980 × 640 capture checked. |
| Navigation | Command-K palette, direct Goal/Activity controls, Files/Activity/Skills/Session inspector. Skill insertion is removable. |
| Small labels/status words | Explicit UI text is at least 11 pt. Activity status labels are humanized. Single-choice questions use radio circles. |
| Design guidance | Current direction and design records describe Signal Desk. Historical captures and implementation steps remain historical evidence. |

The proposed `#767C84` tertiary failed 4.5:1 small-text contrast, so the implementation keeps `#9CA3AF`. Brand blue stays `#2694FE`; native filled controls use a deeper tint because macOS supplies white labels. Actual enabled approval pixels measured **5.01:1**.

## Still open

- Real-provider approval, question, skill expansion, goal, agent, workflow, shell, stored-output and durable-resume paths require the owner's supervised test. Wiring a native control does not establish live success.
- No `tool/list` exists in the stable host. Activity shows actual calls; login, plugin/MCP management, voice and terminal-only commands open Muse separately in Terminal.
- System notifications, global allow/deny shortcuts, date-grouped sessions, transcript search, richer file chips, resizable inspector, lazy file discovery and long-session optimization were not all implemented. The send shortcut does not grant permission.
- The file scanner remains bounded to 2,000 entries and six levels. File previews are read-only. Relative `@path` text is the schema-supported mention form.
- Native traffic lights retain macOS placement; custom relocation is not claimed.
- No speed improvement, complete CLI parity, exhaustive accessibility certification, public release or user design approval is claimed.

Executed evidence: [verification.md](verification.md). Owner testing and publication gate: [acceptance.md](acceptance.md).
