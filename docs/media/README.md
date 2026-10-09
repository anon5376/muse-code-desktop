# Captured media

Every file here is a genuine capture of the running app — no mockups and no
mock renders. CI captures ran the app against the synthetic `ReviewHost`
fixture (see docs/testing.md), so the "offline fixture" banner is visible by
design; the fixture never contacts a model provider.

| File | Beat |
| --- | --- |
| `workspace.png` | Home workspace with suggestion cards |
| `markdown.png` | Streamed markdown: headings, lists, tables, code fences |
| `palette.png` | ⌘K command palette mid-filter |
| `skill.png` | Skill chip attached in the composer |
| `model-picker.png` | Model picker popover |
| `inspector.png` | Skills inspector panel |
| `compact.png` | Window at minimum size |
| `approval.png` | Permission request card awaiting a decision |
| `question.png` | Question card with selection options |
| `demo.gif` | Short scripted session loop (CI capture, stitched) |
| `demo.mp4` | Same loop as MP4 |

Regenerate with `bash scripts/capture-demo.sh` on macOS.
