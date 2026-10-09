# Launch flags

`Muse Code.app` accepts three flags (read once at launch in
`WorkspaceStore`); all are optional.

| Flag | Effect |
| --- | --- |
| `--echo` | Force the offline echo provider — real session plumbing, zero model calls |
| `--workspace <path>` | Open directly into the given folder |
| `--muse-executable <path>` | Use this `muse` binary instead of PATH search / the saved setting |

Example — a throwaway offline session in the current folder:

```sh
open "build/Muse Code.app" --args --echo --workspace "$PWD"
```

`--muse-executable` is also how CI and the diagnostics tools point at a
fixture binary; it only affects this launch and is not persisted to
Settings.
