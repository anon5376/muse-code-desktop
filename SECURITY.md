# Security policy

## Supported versions

Only the latest prerelease tag is maintained (currently v0.1.0). This is a
preview build — expect breaking changes.

## Reporting a vulnerability

Do **not** open a public issue for a security problem. Use
[GitHub private vulnerability reporting](https://github.com/anon5376/muse-code-desktop/security/advisories/new)
so the owner can triage before disclosure.

## Scope notes

- The app never stores or reads credentials — auth lives in the installed Muse CLI.
- The app supervises `muse serve`; the host owns tool policy, sandboxing, and approvals. The UI never auto-decides a permission request.
- Reported issues in the wrapper (protocol handling, UI, packaging) are in scope; vulnerabilities in Muse itself belong upstream.
