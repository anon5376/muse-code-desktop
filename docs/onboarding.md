# First-run walkthrough

## 1. Install the CLI

The app supervises `muse serve` — install Muse Code first and confirm
`muse --version` works. The app never bundles or replaces the CLI.

## 2. Install the app

Mount `muse-code-desktop-<ver>-arm64.dmg`, drag **Muse Code** to
Applications, and open it once via right-click → Open (the build is ad-hoc
signed, not notarized — see [compatibility.md](compatibility.md)).

## 3. Try it offline first

```sh
open "Muse Code.app" --args --echo --workspace "$PWD"
```

The echo provider gives you a real session — transcript streaming, palette,
model picker, inspector — with zero model calls. The "offline fixture" banner
marks the mode honestly.

## 4. Your first real session

Pick a project folder, press ⌘N (new session), choose a model route in the
composer's picker, and send. Approvals and questions pin above the composer —
the app never answers them for you.

## 5. Learn the surface

⌘K opens the palette (sessions, skills, commands). The inspector beside the
transcript holds Files · Activity · Skills · Session. The library (sidebar)
lists durable sessions for resume.
