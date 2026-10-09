import Foundation
import MuseCore
import Darwin

@main
enum StoreTests {
    struct Failure: Error, CustomStringConvertible { let description: String }
    @MainActor static func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            guard Date() < deadline else { throw Failure(description: "Workspace operation did not settle") }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    @MainActor static func main() async {
        guard CommandLine.arguments.contains("--echo") else { print("Offline mode is required"); exit(1) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("muse-store-check-" + UUID().uuidString)
        var failures = 0
        let store = WorkspaceStore()
        var modelStore: WorkspaceStore?
        do {
            let routes = ["personal", "work"].map { profile in
                ModelEntry(raw: .object(["providerId": .string("meta"), "modelId": .string("same-model"), "profileId": .string(profile)]))
            }
            if Set(routes.map(\.id)).count == 2 { print("PASS model picker distinguishes provider profiles") }
            else { failures += 1; print("FAIL model picker merges distinct provider profiles") }
            let contributor = ModelEntry(raw: .object(["providerId": .string("meta"), "modelId": .string("muse-spark-1.3-contributor"),
                "profileId": .string("personal"), "isDefault": .bool(true), "variants": .array([.string("high")]),
                "description": .string("Your content may be used for product improvement.")]))
            let catalogStore = WorkspaceStore(echoMode: false)
            catalogStore.models = [contributor]
            if catalogStore.chosenModel?.id == contributor.id, catalogStore.modelLabel.contains("Contributor") {
                print("PASS configured default resolves to its actual catalog model")
            } else { failures += 1; print("FAIL configured default hides its actual model") }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            // The lifecycle checks below exercise a real `muse serve --provider echo` host.
            // Without an installed CLI they are skipped, not failed.
            if MuseExecutable.locate() != nil {
                store.workspace = root
                await store.start()
                guard store.engine == .ready else { throw Failure(description: store.errorMessage ?? "Host did not connect") }
                store.draft = "Keep the unsent new-session draft"
                let sessionCount = store.sessions.count
                store.newSession()
                try await waitUntil { !store.isBusy }
                if store.selectedID == nil, store.sessions.count == sessionCount, store.draft == "Keep the unsent new-session draft" {
                    print("PASS new session keeps its draft without creating a host session")
                } else { failures += 1; print("FAIL new session created an empty host session or lost its draft") }
                store.draft = "store-lifecycle-check"
                store.send()
                try await waitUntil { !store.isBusy && !store.isRunning && store.selectedID != nil }
                guard store.current?.transcript.items.contains(where: { $0.text == "echo: store-lifecycle-check" }) == true,
                      let id = store.selectedID, let state = store.current else { throw Failure(description: "Real echo turn was not received") }
                store.newSession()
                if store.selectedID == nil, store.draft.isEmpty { print("PASS sent first prompt is consumed from the new-session draft") }
                else { failures += 1; print("FAIL an already-sent prompt reappeared in a new draft") }
                store.draft = "Keep this unsent new-session draft"
                store.selectSession(id)
                try await waitUntil { !store.isBusy }
                store.newSession()
                if store.draft == "Keep this unsent new-session draft" { print("PASS unsent new-session draft survives session navigation") }
                else { failures += 1; print("FAIL navigation discarded an unsent new-session draft") }
                store.draft = ""; store.selectSession(id)
                try await waitUntil { !store.isBusy }

                await store.refreshSkills()
                let count = state.transcript.items.count
                store.pendingSkill = SkillEntry(raw: .object(["selector": .string("not-an-installed-skill-731b"), "displayName": .string("Unavailable skill")]))
                store.draft = "keep these arguments"
                store.send()
                try await waitUntil { !store.isBusy }
                if store.errorMessage != nil, store.draft == "keep these arguments", store.pendingSkill != nil, state.transcript.items.count == count {
                    print("PASS unavailable skill preserves the draft and never submits a literal slash prompt")
                } else { failures += 1; print("FAIL unavailable skill was submitted or discarded its draft") }
                store.pendingSkill = nil; store.errorMessage = nil

                store.newSession()
                store.draft = "Create a second session for the selection check"
                store.send()
                try await waitUntil { !store.isBusy }
                // The UI can choose a reasoning override in a different session.
                // Echo has no variants: the old override must not survive selection.
                store.reasoningEffort = "high"
                store.selectSession(id)
                try await waitUntil { !store.isBusy }
                store.draft = "reasoning-reset-check"
                store.send()
                try await waitUntil { !store.isBusy && !store.isRunning }
                if store.reasoningEffort == nil, state.transcript.items.contains(where: { $0.text == "echo: reasoning-reset-check" }) {
                    print("PASS switching sessions clears unsupported reasoning and still sends")
                } else { failures += 1; print("FAIL another session's reasoning override blocked the current session") }

                // A cached selection can outlive its host load. It must not admit
                // commands, and selecting that same row must actually try resume.
                state.loaded = false
                store.draft = "must wait for resume"
                if store.canSend { failures += 1; print("FAIL unloaded selection admitted a prompt") }
                else { print("PASS unloaded selection blocks prompt admission") }
                store.selectSession(id)
                try await waitUntil { !store.isBusy }
                if state.loaded && !state.unavailable {
                    print("PASS selected unloaded session resumes through the actual host")
                } else if !state.loaded && state.unavailable && store.errorMessage != nil {
                    print("PASS selected unloaded session reports unavailable host history")
                } else { failures += 1; print("FAIL selecting the unloaded current row did not attempt recovery") }

                // A memory-only echo session cannot survive a new host. Reconnect
                // must report that fact, not leave a sendable stale transcript.
                await store.connect()
                if store.selectedID == id, store.current?.unavailable == true, !store.canSend, store.errorMessage != nil {
                    print("PASS reconnect reports the lost ephemeral session and blocks stale submission")
                } else { failures += 1; print("FAIL reconnect left an unrecovered selected session usable") }

                // A catalog profile can disappear between browsing and starting.
                // The real host must reject it; the app must not send with the
                // session/start default after that explicit selection failed.
                let missingProfile = ModelEntry(raw: .object(["modelId": .string("muse-spark-1.3"), "providerId": .string("meta"), "profileId": .string("missing-profile-731b")]))
                store.models = [missingProfile]; store.selectedModelKey = missingProfile.id
                store.newSession()
                store.draft = "must not use the wrong model"
                store.send()
                try await waitUntil { !store.isBusy }
                store.draft = "must not use the wrong model"
                if store.selectedID != id, store.errorMessage != nil, !store.canSend {
                    print("PASS rejected profile blocks submission with the session-start default")
                } else { failures += 1; print("FAIL rejected profile left the wrong default model sendable") }

                let rejectedID = store.selectedID
                store.forkSession()
                if !store.isBusy, store.selectedID == rejectedID {
                    print("PASS rejected profile blocks fork admission")
                } else { failures += 1; print("FAIL rejected profile admitted a fork with the wrong model") }
                try await waitUntil { !store.isBusy }
                if let rejectedID, store.selectedID != rejectedID {
                    store.selectSession(rejectedID)
                    try await waitUntil { !store.isBusy }
                }
                for method in ["goal/set", "goal/resume"] {
                    store.actionError = nil; store.actionNotice = nil
                    let parameters: [String: JSONValue] = method == "goal/set" ? ["objective": .string("Do not run with an unconfirmed model")] : [:]
                    store.sessionAction(method, label: "Goal", parameters: parameters)
                    try await waitUntil { store.pendingActions.isEmpty }
                    if store.actionError?.localizedCaseInsensitiveContains("model") == true, store.actionNotice == nil {
                        print("PASS rejected profile blocks \(method)")
                    } else { failures += 1; print("FAIL rejected profile admitted \(method)") }
                    // Before the fix, the isolated echo host may admit a goal.
                    // Pause that goal so this regression never leaves it running.
                    if store.current?.goal != .null {
                        store.sessionAction("goal/pause", label: "Pause goal")
                        try await waitUntil { store.pendingActions.isEmpty }
                    }
                    if store.isRunning { store.interrupt(); try await waitUntil { !store.isRunning } }
                }
            } else {
                print("SKIP real Muse echo host checks: no installed muse executable")
            }

            guard let fixtureIndex = CommandLine.arguments.firstIndex(of: "--model-host"), fixtureIndex + 1 < CommandLine.arguments.count else {
                throw Failure(description: "The model-ordering protocol fixture is missing")
            }
            let fixtureStore = WorkspaceStore(echoMode: false); modelStore = fixtureStore
            fixtureStore.workspace = root
            fixtureStore.executablePath = CommandLine.arguments[fixtureIndex + 1]
            await fixtureStore.start()
            try await waitUntil { !fixtureStore.models.isEmpty || fixtureStore.errorMessage != nil }
            guard let model = fixtureStore.models.first else {
                throw Failure(description: "The model fixture did not connect: \(fixtureStore.errorMessage ?? "no error")")
            }
            // The configured default is a real route, so its advertised effort
            // choices must be usable before a session exists.
            fixtureStore.chooseReasoning("high")
            if fixtureStore.reasoningEffort == "high" { print("PASS default model offers its advertised reasoning choices") }
            else { failures += 1; print("FAIL default model hides supported reasoning choices") }
            fixtureStore.selectedModelKey = model.id; fixtureStore.reasoningEffort = "high"
            fixtureStore.draft = "First message with an explicit model and effort"
            fixtureStore.send()
            try await waitUntil { !fixtureStore.isBusy && !fixtureStore.isRunning }
            if fixtureStore.current?.transcript.items.contains(where: { $0.text == "Requested reasoning: high" }) == true,
               fixtureStore.reasoningEffort == "high" {
                print("PASS first send preserves reasoning across model setup notifications")
            } else {
                failures += 1
                print("FAIL first send lost its requested reasoning during model setup: \(fixtureStore.errorMessage ?? "no error"); effort=\(fixtureStore.reasoningEffort ?? "default"); active=\(fixtureStore.chosenModel?.modelID ?? "none")")
            }
            if let firstID = fixtureStore.selectedID {
                fixtureStore.newSession(); fixtureStore.chooseReasoning(nil)
                fixtureStore.draft = "Second session uses automatic reasoning"
                fixtureStore.send()
                try await waitUntil { !fixtureStore.isBusy && !fixtureStore.isRunning }
                let secondID = fixtureStore.selectedID
                fixtureStore.selectSession(firstID); await fixtureStore.refreshModels()
                let restoredFirst = fixtureStore.reasoningEffort == "high"
                if let secondID { fixtureStore.selectSession(secondID); await fixtureStore.refreshModels() }
                if firstID != secondID, restoredFirst, fixtureStore.reasoningEffort == nil {
                    print("PASS each session retains only its own supported reasoning choice")
                } else { failures += 1; print("FAIL reasoning choices leaked between sessions") }
                if let secondID, let second = fixtureStore.current {
                    fixtureStore.draft = "delayed terminal failure"; fixtureStore.send()
                    try await waitUntil { !fixtureStore.isBusy }
                    fixtureStore.selectSession(firstID)
                    // Poll for the delayed failure rather than a fixed sleep: the
                    // host posts it asynchronously and a fixed 350 ms raced it in CI.
                    try await waitUntil { second.errorMessage != nil }
                    let backgroundRetained = second.errorMessage == "Synthetic delayed failure" && fixtureStore.errorMessage == nil
                    fixtureStore.selectSession(secondID)
                    if backgroundRetained, fixtureStore.errorMessage == "Synthetic delayed failure" {
                        print("PASS background turn failures stay with their session and reappear on selection")
                    } else { failures += 1; print("FAIL session navigation lost or misrouted a terminal failure") }
                }
                fixtureStore.newSession(); fixtureStore.draft = "reject once then retry"
                fixtureStore.send(); try await waitUntil { !fixtureStore.isBusy }
                guard fixtureStore.errorMessage != nil, fixtureStore.draft == "reject once then retry", fixtureStore.selectedID != nil else {
                    throw Failure(description: "Retry fixture did not preserve the rejected first submission")
                }
                fixtureStore.send(); try await waitUntil { !fixtureStore.isBusy && !fixtureStore.isRunning }
                fixtureStore.newSession()
                if fixtureStore.draft.isEmpty { print("PASS accepted retry consumes the draft owned by its created session") }
                else { failures += 1; print("FAIL accepted retry resurrected its original new-session draft") }
            }
        } catch { failures += 1; print("FAIL workspace lifecycle setup: \(error)") }
        await modelStore?.shutdownAndWait()
        await store.shutdownAndWait()
        try? FileManager.default.removeItem(at: root)
        print("Workspace lifecycle checks: \(failures == 0 ? "PASS" : "FAIL")")
        if failures > 0 { exit(1) }
    }
}
