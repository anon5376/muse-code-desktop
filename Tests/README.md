# Tests

Standalone Swift executables (no XCTest): `MuseCoreTests` covers the wire
layer and `MuseDesktopTests` drives `WorkspaceStore` against the ModelHost
fixture. Run everything with `bash scripts/test.sh` on macOS.

Conventions, fixtures, and CI mapping: [docs/testing.md](../docs/testing.md).
