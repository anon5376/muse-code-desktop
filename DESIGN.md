---
name: Muse Code Desktop
description: A native macOS workspace that makes Muse's work, routes, and requests legible.
colors:
  canvas: "#111112"
  sidebar: "#0C0D0F"
  raised: "#1A1B1E"
  popover: "#232428"
  line: "#26282C"
  stroke: "#3A3D42"
  text: "#E6E8EB"
  secondary: "#A9AEB5"
  muted: "#9CA3AF"
  accent: "#2694FE"
  control-accent: "#0B5CAE"
  attention: "#F5B54A"
  ink: "#0A1317"
  success: "#7FD88F"
  error: "#FFB2B8"
typography:
  display:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "20pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "14pt"
    fontWeight: 400
  label:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "11pt"
    fontWeight: 500
  code:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "12pt"
    fontWeight: 400
rounded:
  small: "6pt"
  control: "7pt"
  row: "8pt"
  panel: "10pt"
  composer: "12pt"
spacing:
  xs: "4pt"
  sm: "8pt"
  md: "12pt"
  lg: "16pt"
  xl: "24pt"
components:
  composer:
    backgroundColor: "{colors.raised}"
    rounded: "{rounded.composer}"
    padding: "12pt"
  primary-action:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.ink}"
    rounded: "{rounded.row}"
    size: "30pt"
  native-filled-control:
    backgroundColor: "{colors.control-accent}"
    textColor: "#FFFFFF"
---

# Design System: Muse Code Desktop

## Contents

- [Overview](#overview)
- [Colors](#colors) — primary · secondary · neutral
- [Typography](#typography) — hierarchy
- [Layout](#layout) · [Elevation & Depth](#elevation--depth) · [Shapes](#shapes)
- [Components](#components) — buttons · inputs · navigation · transcript · model picker · inspector · app icon
- [Do's and Don'ts](#dos-and-donts)

## Overview

**Creative North Star: "Signal Desk"**

Signal Desk is a native macOS workspace for reading Muse's work, choosing its actual model route, and answering requests. Neutral charcoal regions keep attention on conversation and tool output; Muse blue marks selection and focus, while amber makes decisions and data-use notices easy to find. Native controls and system typography keep the application legible and at home on macOS.

The interface is flat and content-led. Tonal surfaces and hairline dividers define the workspace; custom decoration does not compete with the work. The product preserves the installed Muse CLI as its execution engine and presents host state directly. The app's responsive interface does not establish faster inference or tool execution.

**Key Characteristics:**
- Native AppKit window and lifecycle hosting SwiftUI workspace views.
- Neutral charcoal surfaces, Muse blue for selection and focus, amber for user attention.
- Transcript-first layout with optional session navigation and read-only inspection.

## Colors

Neutral charcoal carries the interface; blue identifies selection and focus, and amber identifies a decision or data-use notice.

### Primary
- **Muse Blue**: Selection, focus, selected icons, and the custom send or stop action, whose dark ink label preserves contrast.
- **Native Control Blue**: Filled native controls that use macOS light labels.

### Secondary
- **Request Amber**: Pending permission or question requests, cross-session attention, and model data-use notices.

### Neutral
- **Canvas Charcoal**: Main reading and conversation region.
- **Session Sidebar Black**: Session navigation and code-block surfaces.
- **Raised Charcoal**: Composer, selected rows, and user messages.
- **Popover Charcoal**: Model and goal popover surfaces.
- **Hairline**: One-point region dividers.
- **Control Stroke**: Input outlines and secondary borders.
- **Main Text**: Primary prose and labels.
- **Secondary Text**: Supporting details and readable metadata.
- **Muted Text**: Low-priority metadata and inactive controls; retain this contrast-safe value for small text.
- **Action Ink**: Dark label and symbol color on custom blue actions.
- **Ready Green**: Connected host readiness state.
- **Error Rose**: Error and invalid-input text.

**The Legible Muted Text Rule.** Do not replace muted text with the lower-contrast gray used in the superseded direction; small text must remain readable on the charcoal surfaces.

## Typography

**Display Font:** macOS system font (SF Pro)
**Body Font:** macOS system font (SF Pro)
**Label/Mono Font:** macOS system font and system monospaced font (SF Mono)

**Character:** Compact system typography keeps a dense desktop workspace clear and familiar. Monospaced text is reserved for code, paths, model identifiers, and structured host details.

### Hierarchy
- **Display** (semibold, 20 pt): Empty-workspace heading.
- **Headline** (semibold, 20 pt): Workspace name in the empty state.
- **Title** (semibold, 16–20 pt): Model picker title and major empty-state heading.
- **Body** (regular, 14 pt, 7 pt line spacing in transcript): Composer text and conversation prose.
- **Label** (regular or medium, 11–13 pt): Navigation, status, metadata, and controls.
- **Code** (regular, 11–12 pt): Paths, code blocks, model identifiers, and protocol details.

**The Native Type Rule.** Use macOS system text and SF Symbols for interface controls; use system monospace where exact technical characters matter.

## Layout

The app opens at 1280 × 820 pt and supports an outer minimum of 980 × 640 pt. A 248 pt hideable session sidebar sits beside the reading and composing area; the title band is 52 pt high. Conversation text is capped at 720 pt. The composer editor grows from 44 to 200 pt.

The 300 pt inspector sits beside the conversation when at least 560 pt of center area remains. At narrower widths it overlays the reading region and leaves the composer and pending-request dock unobscured. The Command-K palette is bounded by a 560 × 420 pt maximum within the available reading area. The model picker uses a 380 × 500 pt native popover; its catalog scrolls independently while reasoning controls and the data-use notice stay visible. Request content scrolls independently of its choices or answers.

## Elevation & Depth

The system uses no custom shadows. Flat charcoal surfaces, one-point dividers, and restrained state fills provide depth. Native system popovers supply their own platform chrome; the app does not add a custom shadow or motion vocabulary.

## Shapes

Rounded rectangles use a compact range from 6 to 12 pt: table outlines are 6 pt, icon controls and model selector 7 pt, rows and code blocks 8 pt, request cards 10 pt, and the composer 12 pt. One-point dividers stay square and flat. Native macOS controls retain their platform shape and behavior.

## Components

### Buttons
- **Character:** Compact controls keep labels and symbols clear; blue identifies the primary action or selected state.
- **Primary:** Custom send and stop actions use Muse blue with dark ink in a 30 × 30 pt, 8 pt-radius control. Native filled controls use the deeper control blue with light labels.
- **Hover / Focus:** Icon buttons use a raised hover or selected surface. The composer uses a one-point stroke that changes to Muse blue while focused. Keyboard focus and system behavior remain available.
- **Secondary:** Native and plain SwiftUI controls use secondary text, with blue for selected state.

### Inputs / Fields
- **Composer:** Raised surface, 12 pt radius and inset, 44–200 pt editor, and one-point stroke. Focus changes the stroke from control gray to Muse blue.
- **Search:** Compact system text fields sit on raised surfaces in the sidebar and model picker.

### Navigation
- **Session sidebar:** Fixed 248 pt dark rail with workspace selection, session search and list, engine status, and settings control. The selected session uses a raised surface and blue marker; running and attention states reflect host state.
- **Title band:** 52 pt native workspace header with direct controls for goal and activity.
- **Inspector:** Optional 300 pt pane for files, activity, skills, or session details; it adapts to the available reading width.

### Transcript and Requests
- **User message:** Raised surface, 10 pt radius, 16 pt padding, selectable 14 pt text.
- **Muse response:** Open on the canvas with a small Muse mark; selectable prose and native Markdown blocks preserve reading hierarchy. Code uses a dark sidebar surface.
- **Activity:** Disclosure rows use hairline separation; expanded arguments and output use selectable system monospace.
- **Permission and question requests:** Amber identifies attention. Request cards remain available during skill browsing and file inspection; paged pending requests retain arrival order and present host choices verbatim.

### Model Picker and Command Palette
The native model picker shows the actual model, provider/profile route, reasoning preference, and data-use notice. Command-K opens the bounded palette for skills and commands; keyboard focus and arrow, Return, and Escape behavior stay native and visible.

### Workspace Inspector
The file browser provides a read-only preview and an “Add to message” action for the selected relative path. It is an inspection surface, not an editable IDE. Activity, skills, and session controls remain tied to host-exposed data.

### App Icon and Review Evidence
The unchanged official Muse SVG from Muse's public website is bundled in `Sources/MuseDesktop/Resources/MuseLogo.svg`. `scripts/GenerateIcon.swift` renders it onto the existing charcoal app-icon tile. The sidebar identifies the app as an unofficial desktop client; Settings and About explicitly disclaim Meta affiliation or endorsement. The original asset's gradient is preserved. See [asset provenance and license boundary](docs/brand-assets.md). Actual-window rasters under `.impeccable/review/` are local visual-review evidence and are excluded from publication.

## Do's and Don'ts

### Do:
- **Do** use Muse blue for selection and focus, amber for requests and data-use notices, and the deeper control blue for native filled controls.
- **Do** keep request choices and answers visible while their request content scrolls.
- **Do** preserve native text selection, keyboard focus, menus, popovers, and system control behavior.
- **Do** keep session, model, tool, and permission states tied to actual host data.

### Don't:
- **Don't** invent session history, model metadata, usage figures, tool outcomes, or permission grants.
- **Don't** present the read-only inspector as an editable IDE.
- **Don't** imply faster inference or tool execution from the native interface.
- **Don't** add decorative shadows, gradients, hero graphics, or fake physical materials.
