# User acceptance and publication

This is a local test candidate. User testing and design approval are pending. Automated and synthetic checks do not certify every CLI feature or live provider path.

## Hands-on test

1. Open `build/Muse Code.app`, choose a disposable project and confirm Muse connects. Check the actual model/profile and any amber **Data use** notice before sending content. The installed default currently resolves to a Contributor route.
2. Search the model picker, select the intended route and reasoning level, then send a small prompt. Confirm the first response uses that route. Switch sessions with different models and check their reasoning preferences.
3. Open Command-K, search and choose an available skill, add arguments and send. Confirm the host expands it. Check `/` in an empty composer and the Skills inspector. Browsing should leave the conversation in place.
4. Read a file in Files and use **Add to message**. Inspect tool output in the transcript and Activity. Trigger a harmless permission request; confirm it stays pending until you choose. Check the card with palette and inspector open. Test denial and an explicit intended grant yourself.
5. Exercise a real question, goal pause/resume, one subagent and a workflow when available. Check Session controls, a harmless shell command and stored output. Record unavailable host capabilities rather than treating a disabled control as a successful test.
6. Rename and fork a session, compact context, switch sessions, restart and resume durable history. Check first-message titles and draft preservation, including a failed first send followed by retry. Echo and synthetic sessions are deliberately not durable.
7. Test reconnect and quit during a harmless long-running tool. Check elapsed time and remaining descendants. The automated inherited-pipe regression establishes bounded closure, not whole-process-group cleanup.
8. Resize to actual outer sizes **980 × 640** and **1280 × 820**. Check the empty view, Markdown, model picker, palette, long request body and all four inspector tabs. Confirm the design and navigation meet your expectations.

Record each failure with the action, expected behavior, actual result and useful capture. A failed or unrun step remains open. See [verification.md](verification.md) for executed evidence, [testing.md](testing.md) for the automated suites and [fixtures.md](fixtures.md) for the synthetic hosts behind them, and [claude-review-response.md](claude-review-response.md) for the supplied review's disposition.

## Source publication

On 2026-10-08 the owner explicitly requested publication under the name `muse-code-desktop`, authorizing source publication before the remaining hands-on acceptance checks. The destination is [anon5376/muse-code-desktop](https://github.com/anon5376/muse-code-desktop), with the wrapper source under MIT.

The separately installed Muse CLI, generated app bundle, local recordings/captures, credentials and machine settings are excluded. The bundled logo and trademarks are excluded from MIT; see [asset provenance](brand-assets.md). Source publication does not certify unrun acceptance checks.

## Promotion gate

Promotion begins only after the user approves the tested app. No promotion has started. Outreach or messages to another person require the user's specific authorization.
