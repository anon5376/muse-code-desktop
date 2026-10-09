# Verification evidence

> **Post-ship note (2026-10-08):** this evidence supported the published
> [v0.1.0 prerelease](https://github.com/anon5376/muse-code-desktop/releases/tag/v0.1.0).
> The same checks now run per-PR and per-tag on `macos-15` via
> [.github/workflows/build.yml](../.github/workflows/build.yml). Everything
> below describes the pre-release local verification and remains accurate.

Executed on 2026-10-08 local time: macOS 26.4, Apple Silicon, Swift 6.3.1 command-line tools, Muse Code 1.4.2-R4684.1. This supports a local user-test candidate. Live-provider acceptance and user design approval remain open.

## Executed checks

`bash scripts/test.sh` returned **14/14 core tests passed** and **19 workspace checks passed**. Selected actual output:

```text
PASS Markdown renders structural blocks and preserves code fences
PASS streaming Markdown keeps completed blocks stable
PASS host failure retains bounded in-memory diagnostic details
PASS shutdown does not wait for a descendant holding output pipes
PASS presentation receipts send no implicit approval or answer
PASS real Muse echo host round trip (569 ms)
14/14 tests passed
PASS configured default resolves to its actual catalog model
PASS new session keeps its draft without creating a host session
PASS default model offers its advertised reasoning choices
PASS each session retains only its own supported reasoning choice
PASS background turn failures stay with their session and reappear on selection
PASS accepted retry consumes the draft owned by its created session
Workspace lifecycle checks: PASS
```

The remaining checks cover split Unicode/framing, frame-size limits, final revisions/replay, readable tool output, exclusive question answer variants, permission descriptions, unavailable history, distinct profile routes, draft navigation/consumption, unavailable skill admission, unloaded sessions, lost ephemeral sessions after reconnect, rejected-model admission for prompts/forks/goals, and first-send reasoning ordering.

The transport and production store run against actual isolated Muse echo sessions and standalone local Swift protocol fixtures. Fixture tests cover catalog/order/failure cases and request receipts without contacting a provider or executing tools. Regressions were demonstrated failing before their repairs. No testing dependency was installed.

The 33 checks were rerun after the recorded-test layout repair below and all passed. No transport/store source changed during that repair.

## Normal Muse metadata

Normal mode connected and exposed four actual Meta model routes, their profile, advertised reasoning variants and context/output limits. The configured default resolves to Muse Spark 1.3 Contributor. Its host-supplied product-improvement notice appears in the picker and an amber Data use badge appears beside the composer model. No price is invented.

Model selection and reasoning options, including the configured default, were inspected without sending a provider turn. An earlier isolated normal-host check confirmed an explicit model/profile route and missing-profile rejection, also without a model turn.

Earlier installed inventory reported 67 skills; an actual echo session exposed 56 invocable shortcuts. These are machine observations, not fixed product limits. The installed plugin query reported none. Stable MSP exposes no tool/list catalog; Activity presents reported calls and Terminal covers unsupported management commands.

## Actual native UI

Own-app accessibility and window captures verified actual outer sizes **1280 × 820** and **980 × 640**. The minimum no longer produces a 672-point outer window. At compact width the inspector overlays the reading area; the composer and pending request controls stay visible. The 380 × 500 pt model panel produces a native 406 × 526 pt popover contained within the compact parent window.

The requested real-logo revision uses the unchanged SVG from Muse's public website, with matching SHA-256 in the source and packaged resource. AppKit loaded the packaged SVG directly. Actual-window inspection confirmed the logo and **Unofficial desktop client** label at [1280 × 820](../.impeccable/review/muse-logo-desktop.png) and [980 × 640](../.impeccable/review/muse-logo-compact.png). [Settings](../.impeccable/review/muse-logo-settings.png) and [About](../.impeccable/review/muse-logo-about.png) visibly state that this is not the official Muse Code desktop app and is not affiliated with or endorsed by Meta. The app-icon raster was also inspected. The 14 core and 19 workspace checks were rerun and passed; no real-provider turn was sent. Earlier Signal Desk captures below precede this branding-only revision. See [asset provenance](brand-assets.md).

All fixture windows display **Offline UI fixture · synthetic data, no provider or tools**. Synthetic checks exercised a 40-line request body, explicit denial, a single-choice question/answer, native headings/lists/quotes/tables/fenced code, removable skill selection, and actual project file preview/Add to message. No synthetic command was executed. A pending approval remained visible with palette and inspector open; decisions and answer buttons stay outside scrolling bodies.

The finish reviewer identified an initial palette focus defect. After repair, raw key events targeted only Muse's PID, without explicitly focusing palette search:

- From sidebar: Command-K then typing filtered palette search; sidebar search stayed empty. Return inserted the synthetic skill attachment.
- From composer: Command-K then typing filtered palette search while preserving the unsent draft; Escape closed the palette.
- Down then Return opened Session controls. Down, Up then Return chose the first synthetic skill.

An earlier actual Muse echo UI check sent a local echo prompt through Command-Return and cleared the composer. The current core test repeats the real echo round trip; synthetic UI checks do not establish real-provider behavior.

### Current captures

| State | 1280 × 820 | 980 × 640 | Content provenance |
| --- | --- | --- | --- |
| Empty workspace | [Desktop](../.impeccable/review/signal-desktop.png) | [Compact](../.impeccable/review/signal-empty-compact.png) | Normal metadata / explicitly labeled synthetic host |
| Model picker | [Desktop](../.impeccable/review/signal-models.png) | [Compact](../.impeccable/review/signal-models-compact.png) | Actual Muse catalog; no turn |
| Command palette | [Desktop](../.impeccable/review/signal-palette.png) | [Compact](../.impeccable/review/signal-palette-compact.png) | Synthetic skill; final keyboard repair |
| Markdown | [Desktop](../.impeccable/review/signal-markdown.png) | [Compact](../.impeccable/review/signal-markdown-compact.png) | Synthetic response |
| Pending approval | [Desktop](../.impeccable/review/signal-approval.png) | [Palette](../.impeccable/review/signal-approval-palette-compact.png), [inspector](../.impeccable/review/signal-approval-inspector-compact.png) | Synthetic 40-line command; no execution |
| Question | [Desktop](../.impeccable/review/signal-question.png) | [Compact](../.impeccable/review/signal-question-compact.png) | Synthetic single choice |
| Files | [Desktop](../.impeccable/review/signal-files.png) | [Compact](../.impeccable/review/signal-files-compact.png) | Actual project source and synthetic reply |
| Inspector tabs | [Activity](../.impeccable/review/signal-activity.png), [Skills](../.impeccable/review/signal-skills.png), [Session](../.impeccable/review/signal-session.png) | Overlay behavior covered above | Synthetic host; empty Activity is intentional |

Captures are local evidence and excluded from publication. Earlier meta-* and orange captures are historical, not current layout evidence. Native traffic lights retain standard placement. No system notification delivery, long-session stress or exhaustive accessibility audit is claimed.

Actual enabled approval pixels were sampled as white #FFFFFF on #3471B7: **5.01:1** contrast. Source control tint is deeper than brand blue to accommodate native white labels. Proposed tertiary #767C84 failed small-text contrast and was not adopted. This sample is not a certification of every possible UI state.

## Packaging and lifetime

The final release build completed in **8.67 s**. Strict code-signature verification returned `valid on disk` and `satisfies its Designated Requirement`; Info.plist lint returned `OK`. The executable is arm64; the bundle occupied **4,164 KiB**. Signing is ad hoc, with no public-distribution certificate or notarization.

Shutdown is tested against a descendant retaining output pipes. An independent reviewer additionally retained 700/700 final frames in three synthetic runs and observed closure in 0.28–0.29 s despite a three-second descendant. The app termination wait is bounded to five seconds. Whole-process-group cleanup of arbitrary tool descendants remains unverified.

No native-versus-terminal inference/tool speed gain has been established. These are bounded checks, not sustained performance measurements.

## Recorded test and compact-layout repair

At the owner's request, ScreenCaptureKit recorded only this app's windows, without audio or other applications. The local video is `build/verification/muse-code-desktop-test.mp4`; it joins trimmed sections of three actual recordings: normal Muse metadata/connection checks, the isolated real Muse echo provider, and the explicitly labeled synthetic UI fixture. Recordings remain local and are excluded from the public repository. `scripts/record-app.swift` is the dependency-free macOS 15+ recording utility; the app itself still requires macOS 14+.

The normal-mode segment inspected the actual model catalog and Contributor data-use notice. Settings' local-connection test reported a streamed echo reply and clean shutdown in **216 ms**. The echo segment sent `Native desktop echo test ✓` and displayed the matching echo response. Muse's unsupported reminder child failed separately and remains visible. No real-provider turn was sent.

Recording exposed a reproducible UI freeze: a rich Markdown reply followed by a 40-line synthetic approval, resized from 1280 × 820 to 980 × 640, left the main thread in SwiftUI layout at roughly **99–100% CPU**. It reproduced without recording and without the palette. Approval-only and Markdown-only compact layouts did not reproduce it. Transcript minimum-height and nested-scroll intrinsic-height changes failed and were reverted.

Changing only the transcript's `LazyVStack` to `VStack` removed the observed loop. The original sequence passed before recording and again in the final recorded run, with **0.0% idle CPU** after compact resize. Escape dismissed the palette; explicit Deny settled the synthetic approval. Selecting macOS and Send answers settled the synthetic question. Palette search, skill selection/removal, inspector overlay and repeated full/compact resizing stayed responsive. A final accessibility inspection showed no pending synthetic request or selected skill. Long-session performance with eager row measurement remains open; this check does not establish a speed improvement.

The resize helper now selects the workspace window by title rather than the first accessibility window, because recording adds a sharing-control window. The video contains real app pixels; idle sections were trimmed and the three runs joined.

## Review and remaining acceptance

The fresh code reviewer cleared the repaired client findings, including draft retry ownership and session-local failures. The fresh native visual reviewer validated 18 required captures, initially returned fix for palette focus, then returned **ship for the scored repair/local visual candidate**. Generic reviewers substitute for unavailable named Impeccable roles; no HTML detector was applied to native Swift. See [review.md](review.md).

Still open: live-provider turns and reasoning, real approval/question decisions, successful skill expansion, shell/goal/agent/workflow/stored-output behavior, durable restoration, remaining descendants on real quit, long-session stress, Intel builds, and user design approval. The owner explicitly authorized source publication as `muse-code-desktop` on 2026-10-08. Promotion has not started and requires separate approval. See [acceptance](acceptance.md).

## Reproduce

On macOS with the Swift toolchain:

```sh
bash scripts/test.sh           # core + workspace suites
bash scripts/build-app.sh      # release bundle
bash scripts/package-dmg.sh    # build/dist DMG + sha256
bash scripts/verify-dmg.sh     # mount / install / copied-launch check
```

The recorded local video and raw frames are excluded from publication; the
command sequence above regenerates equivalent checks on any Mac.
