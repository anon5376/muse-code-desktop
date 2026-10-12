# Glossary

Terms used across the docs and source, defined once.

| Term | Meaning |
| --- | --- |
| `muse serve` | The CLI's JSON-RPC server mode the app spawns and supervises on stdio |
| MSP | Muse Session Protocol — the wire contract between app and host |
| Signal Desk | The design direction's name: flat charcoal workspace, Muse blue, amber requests |
| ReviewHost | Synthetic fixture host for presentation/UI checks (`Tests/MuseDesktopTests`) |
| ModelHost | Synthetic fixture host for workspace-store ordering checks |
| Echo provider | The CLI's offline diagnostic transport — real plumbing, no model |
| wire envelope v1 | The mandatory `initialize` handshake schema version |
| RequestReceipt | The app's ack that a host request was *shown* — not a grant |
| durable session | A session the host can resume after disconnect |
| ephemeral session | A session that cannot survive host restart — resume is reported unavailable |
| view gap | `view/gap` notification telling the app to refetch transcript state |
| pending request | An approval/question waiting on the user, docked above the composer |
| CommandID | UUIDv7-style request id for correlating late responses |
| stderrTail | Bounded 8 KiB ring of host stderr kept for diagnostics |
| `item/delta` | Streaming append to one field of an in-progress item |
| viewCursor | Replay guard token on a delta — seen cursors are dropped |
| catalog route | A `model/list` entry: model × provider × profile |
| fixture beat | A scripted host reaction a test asserts against |
| turn | One prompt → completion cycle, correlated by `commandId` |
