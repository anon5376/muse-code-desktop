import SwiftUI
import AppKit
import MuseCore

struct SessionSummary: Identifiable, Equatable {
    let id: String
    var title: String
    var workspace: String?
    var model: String?
    var branch: String?
    var updated: String
    init(_ value: JSONValue) {
        id = value["sessionId"].string ?? ""
        title = value["title"].string ?? value["name"].string ?? value["firstUserPrompt"].string ?? "New session"
        if title.isEmpty { title = "New session" }
        workspace = value["workspaceRoot"].string
        model = value["modelId"].string
        branch = value["branch"].string
        updated = value["updatedAt"].string ?? ""
    }
}

struct ModelEntry: Identifiable {
    let raw: JSONValue
    var modelID: String { raw["modelId"].string ?? "" }
    var providerID: String { raw["providerId"].string ?? "" }
    var profileID: String? { raw["profileId"].string }
    var id: String { [providerID, profileID ?? "", modelID].map { "\($0.utf8.count):\($0)" }.joined() }
    var label: String { raw["displayLabel"].string ?? raw["modelId"].string ?? "Unknown model" }
    var displayName: String {
        guard label == modelID, modelID.hasPrefix("muse-spark-") else { return label }
        return "Muse Spark " + modelID.dropFirst("muse-spark-".count).replacingOccurrences(of: "-contributor", with: " · Contributor")
    }
    var providerName: String { providerID == "meta" ? "Meta" : providerID }
    var efforts: [String] { raw["variants"].array.compactMap(\.string) }
    var dataUseNotice: String? {
        guard let description = raw["description"].string, !description.isEmpty,
              modelID.contains("contributor") || description.localizedCaseInsensitiveContains("product improvement") || description.localizedCaseInsensitiveContains("training") else { return nil }
        return description
    }
    var selection: JSONValue {
        .object(["modelId": .string(modelID), "providerId": .string(providerID), "profileId": profileID.map(JSONValue.string) ?? .null])
    }
    func matches(_ query: String) -> Bool {
        query.isEmpty || [label, modelID, providerID, profileID ?? ""].contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

@MainActor
final class SessionState {
    var transcript = Transcript()
    var activeTurn: String?
    var completedTurns = Set<String>()
    var approvals: [String: JSONValue] = [:]
    var questions: [String: JSONValue] = [:]
    var pendingRequestOrder: [String] = []
    var reasoningEffort: String?
    var errorMessage: String?
    var loaded = false
    var unavailable = false
    var model: String?
    var provider: String?
    var catalogModel: ModelEntry?
    var modelSelectionRequired = false
    var goal: JSONValue = .null
    var approvalMode: String?
    var totalTokens: Int?
    var lastDuration: Int?
    var contextUsed: Int?
    var contextWindow: Int?
}

@MainActor
final class WorkspaceStore: ObservableObject {
    enum EngineState { case disconnected, connecting, ready, failed }
    @Published var engine: EngineState = .disconnected
    @Published var workspace: URL?
    @Published var sessions: [SessionSummary] = []
    @Published var selectedID: String?
    @Published var draft = ""
    @Published var search = ""
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    @Published var schemaWarning = false
    @Published var hostVersion = ""
    @Published var isBusy = false
    @Published var deciding = Set<String>()
    @Published var models: [ModelEntry] = []
    @Published var selectedModelKey = ""
    @Published var modelsLoading = false
    @Published var modelError: String?
    @Published var catalogSource: String?
    @Published var catalogProvider: String?
    @Published var isChangingModel = false
    @Published var reasoningEffort: String? {
        didSet {
            if let current { current.reasoningEffort = reasoningEffort }
            else { newDraftReasoning = reasoningEffort }
        }
    }
    @Published var libraryVisible = false
    @Published var libraryTab = "Skills"
    @Published var skills: [SkillEntry] = []
    @Published var skillsAreSessionCatalog = false
    @Published var skillsLoading = false
    @Published var skillsError: String?
    @Published var pendingSkill: SkillEntry?
    @Published var plugins: [JSONValue] = []
    @Published var pluginsLoading = false
    @Published var pluginsError: String?
    @Published var grantedCapabilities = Set<String>()
    @Published var pendingActions = Set<String>()
    @Published var actionNotice: String?
    @Published var actionError: String?
    @Published var actionOutput: String?
    @Published var subscriptionUsage: JSONValue = .null
    @Published var inspectorVisible = false
    @Published var sidebarVisible = true
    @Published var inspectorTab = "Files"
    @Published var settingsVisible = false
    @Published var executablePath: String
    @Published var recentWorkspaces: [String]
    @Published var fileNodes: [FileNode] = []
    @Published var filePreview: FilePreview?
    @Published var fileError: String?
    @Published var filesLoading = false
    @Published var eventRevision = 0
    @Published var isStopping = false
    let echoMode: Bool

    private var connection: MuseConnection?
    private var eventsTask: Task<Void, Never>?
    private var generation = UUID()
    private var selectionGeneration = UUID()
    private var states: [String: SessionState] = [:]
    private var drafts: [String: String] = [:]
    private var newDraftReasoning: String?
    private var loading = Set<String>()
    private var buffered: [String: [JSONValue]] = [:]
    private var offlineRoot: URL?
    private var fileGeneration = UUID()
    private var catalogGeneration = UUID()
    private var skillGeneration = UUID()
    private var pluginGeneration = UUID()

    init(echoMode: Bool? = nil) {
        self.echoMode = echoMode ?? CommandLine.arguments.contains("--echo")
        executablePath = UserDefaults.standard.string(forKey: "museExecutable") ?? ""
        recentWorkspaces = UserDefaults.standard.stringArray(forKey: "recentWorkspaces") ?? []
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--muse-executable"), index + 1 < args.count {
            executablePath = args[index + 1]
        }
        if let index = args.firstIndex(of: "--workspace"), index + 1 < args.count {
            workspace = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        } else if let path = UserDefaults.standard.string(forKey: "lastWorkspace"), FileManager.default.fileExists(atPath: path) {
            workspace = URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    var current: SessionState? { selectedID.flatMap { states[$0] } }
    var selectedSession: SessionSummary? { sessions.first { $0.id == selectedID } }
    var isRunning: Bool { current?.activeTurn != nil }
    var anyRunning: Bool { states.values.contains { $0.activeTurn != nil } }
    var modelExecutionReady: Bool { engine == .ready && workspace != nil && !isBusy && !isChangingModel && (selectedID == nil || current?.loaded == true) && current?.unavailable != true && current?.modelSelectionRequired != true }
    var canSend: Bool { modelExecutionReady && !isRunning && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingSkill != nil) }
    var hasLoadedSession: Bool { engine == .ready && current?.loaded == true && current?.unavailable == false }
    var canRunGoal: Bool { hasLoadedSession && modelExecutionReady }
    var canForkSession: Bool { canRunGoal && !isRunning }
    var visibleSessions: [SessionSummary] { sessions.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }
    var chosenModel: ModelEntry? {
        selectedID == nil ? (selectedModelKey.isEmpty ? models.first { $0.raw["isDefault"].bool == true } : models.first { $0.id == selectedModelKey }) : current?.catalogModel
    }
    var canChooseModel: Bool {
        engine == .ready && !echoMode && !isBusy && !isRunning && !isChangingModel && (selectedID == nil || (current?.loaded == true && current?.unavailable == false))
    }
    var modelLabel: String {
        if echoMode { return hostVersion == "synthetic-fixture" ? "Fixture · offline" : "Echo · offline" }
        if isChangingModel { return "Switching model…" }
        if let model = chosenModel {
            let route = model.displayName + (model.profileID.map { " · " + $0 } ?? "")
            return selectedID == nil && selectedModelKey.isEmpty ? "Muse default · " + route : route
        }
        if let model = current?.model {
            let matches = models.filter { $0.modelID == model && (current?.provider == nil || $0.providerID == current?.provider) }
            return matches.count == 1 ? matches[0].displayName : model
        }
        return selectedID == nil && !selectedModelKey.isEmpty ? "Model unavailable" : "Muse default"
    }
    var engineLabel: String {
        switch engine {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .ready: return echoMode ? (hostVersion == "synthetic-fixture" ? "Offline fixture" : "Offline test") : "Muse connected"
        case .failed: return "Connection lost"
        }
    }

    func start() async {
        guard engine == .disconnected else { return }
        await connect()
        refreshFiles()
        await refreshSkills()
    }

    func connect() async {
        guard engine != .connecting else { return }
        engine = .connecting; errorMessage = nil; errorDetails = nil
        generation = UUID()
        let token = generation
        isBusy = true
        defer { if generation == token { isBusy = false } }
        loading.removeAll(); buffered.removeAll(); deciding.removeAll()
        models = []; modelError = nil; catalogSource = nil; catalogProvider = nil
        reasoningEffort = nil
        catalogGeneration = UUID(); modelsLoading = false; isChangingModel = false
        pendingActions.removeAll(); grantedCapabilities.removeAll()
        eventsTask?.cancel()
        if let old = connection { await old.shutdown() }
        connection = nil
        if let root = offlineRoot { try? FileManager.default.removeItem(at: root); offlineRoot = nil }
        guard let executable = MuseExecutable.locate(preferredPath: executablePath.isEmpty ? nil : executablePath) else {
            engine = .failed; errorMessage = "Muse CLI was not found. Choose its executable in settings."; return
        }
        for state in states.values { state.loaded = false; state.unavailable = true; state.activeTurn = nil; state.approvals = [:]; state.questions = [:]; state.catalogModel = nil }
        let (events, receiver) = AsyncStream<[JSONValue]>.makeStream()
        let host = MuseConnection(onEvents: { receiver.yield($0) }, onExit: { message in
            receiver.yield([.object(["method": .string("connection/closed"), "params": .object(["message": message.map(JSONValue.string) ?? .null])])])
            receiver.finish()
        })
        connection = host
        eventsTask = Task { [weak self] in
            for await batch in events {
                guard !Task.isCancelled, let self, self.generation == token else { break }
                self.receive(batch)
            }
        }
        do {
            let root = workspace ?? FileManager.default.homeDirectoryForCurrentUser
            let configuration: MuseLaunchConfiguration
            if echoMode {
                let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("muse-native-ui-" + UUID().uuidString)
                offlineRoot = temporary
                configuration = try EchoDiagnostic.configuration(executable: executable, workspace: root, temporaryRoot: temporary)
            } else { configuration = MuseLaunchConfiguration(executable: executable, workspace: root, requestedCapabilities: ["userShell"]) }
            let hello = try await host.start(configuration)
            guard generation == token else { return }
            hostVersion = hello["serverInfo"]["version"].string ?? ""
            grantedCapabilities = Set(hello["grantedCapabilities"].array.compactMap(\.string))
            schemaWarning = hello["schema"]["fingerprint"].string != MuseConnection.expectedFingerprint
            engine = .ready
            await refreshSessions()
            if let id = selectedID { await resumeSession(id) }
            await refreshModels()
        } catch {
            let details = await host.diagnosticDetails()
            guard generation == token else { return }
            engine = .failed; errorMessage = error.localizedDescription; errorDetails = details
        }
    }

    func refreshModels() async {
        guard let connection, engine == .ready else { return }
        let hostToken = generation, requestToken = UUID(), selection = selectedID
        catalogGeneration = requestToken; modelsLoading = true; modelError = nil
        defer { if generation == hostToken, catalogGeneration == requestToken { modelsLoading = false } }
        var params: [String: JSONValue] = [:]
        if let selection, current?.loaded == true, current?.unavailable == false { params["sessionId"] = .string(selection) }
        do {
            let result = try await connection.request("model/list", params)
            guard generation == hostToken, catalogGeneration == requestToken, selectedID == selection else { return }
            models = result["models"].array.map(ModelEntry.init)
            catalogSource = result["source"].string; catalogProvider = result["providerId"].string
            if let selection, let state = states[selection] {
                state.catalogModel = models.first { $0.raw["isActive"].bool == true }
                if let effort = reasoningEffort, state.catalogModel?.efforts.contains(effort) != true { reasoningEffort = nil }
            }
        } catch {
            guard generation == hostToken, catalogGeneration == requestToken, selectedID == selection else { return }
            modelError = error.localizedDescription
        }
    }

    func reconnect() {
        if anyRunning {
            let alert = NSAlert()
            alert.messageText = "Restart Muse?"
            alert.informativeText = "Active turns in this app will stop. Their sessions can be resumed afterwards."
            alert.addButton(withTitle: "Restart"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        Task { await connect() }
    }

    func chooseWorkspace() {
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true; picker.canChooseFiles = false
        picker.allowsMultipleSelection = false; picker.prompt = "Open workspace"
        picker.directoryURL = workspace
        picker.message = "Choose the project folder Muse will work in."
        picker.begin { [weak self] response in
            guard response == .OK, let url = picker.url else { return }
            Task { @MainActor in self?.setWorkspace(url) }
        }
    }

    func setWorkspace(_ url: URL) {
        stashDraft()
        workspace = url.standardizedFileURL
        selectedID = nil; selectionGeneration = UUID(); search = ""; pendingSkill = nil
        reasoningEffort = nil
        skills = []; skillsAreSessionCatalog = false; actionNotice = nil; actionError = nil; actionOutput = nil
        draft = drafts[draftKey] ?? ""; sessions = []; errorMessage = nil
        UserDefaults.standard.set(workspace?.path, forKey: "lastWorkspace")
        recentWorkspaces.removeAll { $0 == url.path }; recentWorkspaces.insert(url.path, at: 0)
        recentWorkspaces = Array(recentWorkspaces.prefix(8))
        UserDefaults.standard.set(recentWorkspaces, forKey: "recentWorkspaces")
        refreshFiles()
        Task {
            if engine == .ready { await refreshSessions() }
            else { await connect() }
            await refreshSkills()
        }
    }

    func refreshSessions() async {
        guard let connection, let root = workspace, engine == .ready else { return }
        let token = generation
        do {
            let result = try await connection.request("session/list", ["workspaceRoot": .string(root.path), "limit": .number(100)])
            guard token == generation, workspace == root else { return }
            let stored = result["sessions"].array.map(SessionSummary.init).filter { !$0.id.isEmpty }
            let local = sessions.filter { row in states[row.id]?.loaded == true && !stored.contains { $0.id == row.id } }
            sessions = (local + stored).sorted { $0.updated > $1.updated }
        } catch {
            // Ephemeral echo hosts do not expose the durable session catalog.
            if !echoMode, token == generation, workspace == root { errorMessage = error.localizedDescription }
        }
    }

    func newSession() {
        guard workspace != nil else { chooseWorkspace(); return }
        guard !isBusy, !isChangingModel, engine == .ready else { return }
        guard selectedID != nil else { libraryVisible = false; return }
        stashDraft(); selectedID = nil; selectionGeneration = UUID()
        draft = drafts[draftKey] ?? ""; reasoningEffort = newDraftReasoning
        pendingSkill = nil; libraryVisible = false; errorMessage = nil
        skillsAreSessionCatalog = false; actionError = nil; actionNotice = nil; actionOutput = nil
        Task { await refreshModels(); await refreshSkills() }
    }

    private func createSession(preserveDraft: Bool) async throws -> String {
        guard let connection, let root = workspace else { throw ConnectionFailure.notRunning }
        let token = generation
        let model = models.first { $0.id == selectedModelKey }
        guard selectedModelKey.isEmpty || model != nil else { throw ConnectionFailure.protocolError("The chosen model is no longer in the catalog. Refresh models and choose again.") }
        let params: [String: JSONValue] = ["commandId": .string(CommandID.make()), "workspaceRoot": .string(root.path)]
        let result = try await connection.request("session/start", params, timeout: 60)
        guard generation == token, workspace == root else { throw CancellationError() }
        let summary = SessionSummary(result["session"])
        guard !summary.id.isEmpty else { throw ConnectionFailure.protocolError("session ID is missing") }
        upsert(summary)
        let state = states[summary.id] ?? SessionState()
        state.reasoningEffort = reasoningEffort
        state.loaded = true; state.model = summary.model; state.provider = result["session"]["providerId"].string
        state.approvalMode = result["session"]["approvalMode"]["mode"].string
        states[summary.id] = state
        let carried = draft
        // Session creation transfers the draft's ownership even if later
        // model selection or turn admission fails. Retrying must never leave
        // a second copy under the unsaved-new-session key.
        drafts[draftKey] = nil
        selectedID = summary.id; selectionGeneration = UUID()
        draft = preserveDraft ? carried : ""
        drafts[summary.id] = draft
        // session/start cannot carry a profile. Apply the full route before any
        // turn is submitted, including when the model id matches the default.
        if let model {
            state.modelSelectionRequired = true
            try await applyModel(model, to: summary.id)
            guard generation == token else { throw CancellationError() }
            state.modelSelectionRequired = false
        }
        guard generation == token, workspace == root else { throw CancellationError() }
        await refreshModels()
        return summary.id
    }

    func selectSession(_ id: String) {
        guard !isBusy, !isChangingModel, engine == .ready,
              id != selectedID || states[id]?.loaded != true || states[id]?.unavailable == true else { return }
        stashDraft(); selectedID = id; draft = drafts[draftKey] ?? ""
        reasoningEffort = states[id]?.reasoningEffort
        errorMessage = states[id]?.errorMessage
        pendingSkill = nil; libraryVisible = false; skillsAreSessionCatalog = false
        selectionGeneration = UUID()
        guard states[id]?.loaded != true || states[id]?.unavailable == true else {
            objectWillChange.send(); Task { await refreshModels(); await refreshSkills() }; return
        }
        isBusy = true; errorMessage = nil
        let token = generation
        Task {
            defer { if generation == token { isBusy = false } }
            await resumeSession(id)
            await refreshModels()
            await refreshSkills()
        }
    }

    private func resumeSession(_ id: String) async {
        guard let connection else { return }
        let token = selectionGeneration
        let hostToken = generation
        loading.insert(id)
        let state = states[id] ?? SessionState(); states[id] = state
        state.loaded = false; state.unavailable = true
        defer { if generation == hostToken { loading.remove(id) } }
        do {
            let result = try await connection.request("session/resume", ["commandId": .string(CommandID.make()), "sessionId": .string(id), "history": .string("snapshot")], timeout: 60)
            guard token == selectionGeneration, hostToken == generation else { return }
            try restore(result["history"], into: state)
            state.loaded = true; state.model = result["session"]["modelId"].string
            state.provider = result["session"]["providerId"].string; state.catalogModel = nil
            state.activeTurn = result["session"]["activeTurnId"].string
            state.approvalMode = result["session"]["approvalMode"]["mode"].string
            loading.remove(id)
            receive(buffered.removeValue(forKey: id) ?? [])
            objectWillChange.send()
        } catch {
            guard token == selectionGeneration, hostToken == generation else { return }
            state.loaded = false; state.unavailable = true; buffered[id] = nil
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ history: JSONValue, into state: SessionState) throws {
        state.transcript.restore(try SessionHistory.items(history))
        if history["snapshot"] != .null {
            let snapshot = history["snapshot"]["state"]
            state.activeTurn = snapshot["activeTurn"]["turnId"].string
            state.totalTokens = snapshot["tokenUsage"]["totalTokens"].int
            state.goal = snapshot["goal"]
        }
        state.unavailable = false
    }

    func send() {
        guard canSend, let connection, let root = workspace else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let skill = pendingSkill
        let requestedReasoning = reasoningEffort
        guard text.utf8.count <= 1_024 * 1_024 else { errorMessage = "This message exceeds 1 MiB. Attach a file mention instead."; return }
        isBusy = true; errorMessage = nil; current?.errorMessage = nil
        let token = generation
        Task {
            defer { if generation == token { isBusy = false } }
            do {
                let id: String
                if let selectedID { id = selectedID } else { id = try await createSession(preserveDraft: true) }
                guard generation == token, workspace == root else { return }
                let commandID = CommandID.make()
                var input: [JSONValue]
                if let skill {
                    let catalog = try await connection.request("skill/list", ["sessionId": .string(id)])
                    let candidates = catalog["skills"].array.map(SkillEntry.init)
                    let match = candidates.first { $0.selector == skill.selector && skill.selector != nil }
                        ?? candidates.first { $0.selector == skill.invocationName }
                    guard let selector = match?.selector else { throw ConnectionFailure.protocolError("This skill is not available in the session. Refresh the skill library and choose again.") }
                    input = [.object(["type": .string("skill"), "selector": .string(selector), "arguments": .string(text)])]
                } else { input = [.object(["type": .string("text"), "text": .string(text)])] }
                guard generation == token, selectedID == id, workspace == root else { return }
                var params: [String: JSONValue] = ["commandId": .string(commandID), "sessionId": .string(id),
                    "input": .array(input)]
                if let effort = requestedReasoning {
                    var model = chosenModel
                    if model == nil {
                        // A modelChanged notification can supersede the UI's
                        // catalog refresh while first-session setup is awaiting it.
                        let catalog = try await connection.request("model/list", ["sessionId": .string(id)])
                        guard generation == token, selectedID == id, workspace == root else { return }
                        model = catalog["models"].array.map(ModelEntry.init).first { $0.raw["isActive"].bool == true }
                    }
                    guard model?.efforts.contains(effort) == true else {
                        throw ConnectionFailure.protocolError("Choose a supported reasoning level for this model, or use Muse default.")
                    }
                    params["reasoningEffort"] = .string(effort)
                }
                let result = try await connection.request("turn/start", params, timeout: 60)
                guard generation == token else { return }
                if draft.trimmingCharacters(in: .whitespacesAndNewlines) == text { draft = "" }
                drafts[id] = draft
                if pendingSkill?.id == skill?.id { pendingSkill = nil }
                if let state = states[id], let turnID = result["turnId"].string, !state.completedTurns.contains(turnID) { state.activeTurn = turnID }
                if let index = sessions.firstIndex(where: { $0.id == id }), sessions[index].title == "New session" { sessions[index].title = String((skill.map { "/" + $0.invocationName + " " } ?? "").appending(text).prefix(80)) }
                objectWillChange.send()
            } catch { if generation == token { errorMessage = error.localizedDescription } }
        }
    }

    func interrupt() {
        guard let connection, let id = selectedID, let turn = current?.activeTurn else { return }
        let token = generation
        Task {
            do { _ = try await connection.request("turn/interrupt", ["commandId": .string(CommandID.make()), "sessionId": .string(id), "turnId": .string(turn)]) }
            catch { report(error, for: id, generation: token) }
        }
    }

    func setModel(_ model: ModelEntry) {
        guard canChooseModel else { return }
        guard let id = selectedID else {
            selectedModelKey = model.id; reasoningEffort = nil; modelError = nil; return
        }
        let token = generation
        isChangingModel = true; modelError = nil
        Task {
            defer { if generation == token { isChangingModel = false } }
            do {
                try await applyModel(model, to: id)
                guard generation == token, selectedID == id else { return }
                states[id]?.modelSelectionRequired = false
                reasoningEffort = nil
                await refreshModels()
            } catch { if generation == token, selectedID == id { modelError = error.localizedDescription } }
        }
    }

    private func applyModel(_ model: ModelEntry, to id: String) async throws {
        guard let connection else { throw ConnectionFailure.notRunning }
        let result = try await connection.request("session/setModel", ["commandId": .string(CommandID.make()), "sessionId": .string(id), "model": model.selection])
        guard result["status"].string == "accepted" else { throw ConnectionFailure.protocolError("Muse did not accept the model change. Refresh models before trying again.") }
    }

    func useDefaultModel() {
        guard canChooseModel, selectedID == nil else { return }
        selectedModelKey = ""; reasoningEffort = nil; modelError = nil
    }

    func chooseReasoning(_ effort: String?) {
        guard canChooseModel, effort == nil || chosenModel?.efforts.contains(effort!) == true else { return }
        reasoningEffort = effort
    }

    func openLibrary(_ tab: String = "Skills") {
        libraryTab = tab; libraryVisible = true
        Task {
            if tab == "Skills" { await refreshSkills() }
            else if tab == "Extensions" { await refreshPlugins() }
        }
    }

    func refreshSkills() async {
        guard let root = workspace else { return }
        let token = UUID(), hostToken = generation, selection = selectedID
        skillGeneration = token; skillsLoading = true; skillsError = nil
        defer { if skillGeneration == token { skillsLoading = false } }
        do {
            let result: JSONValue
            let sessionCatalog = hasLoadedSession && selection != nil
            if sessionCatalog, let connection, let selection {
                result = try await connection.request("skill/list", ["sessionId": .string(selection)])
            } else {
                guard let executable = MuseExecutable.locate(preferredPath: executablePath.isEmpty ? nil : executablePath) else { throw ConnectionFailure.notRunning }
                result = try await CLICatalog.read(.skills, executable: executable, workspace: root)
            }
            guard skillGeneration == token, generation == hostToken, workspace == root, selectedID == selection else { return }
            skills = result["skills"].array.map(SkillEntry.init)
            skillsAreSessionCatalog = sessionCatalog
        } catch {
            guard skillGeneration == token, generation == hostToken, workspace == root, selectedID == selection else { return }
            skillsError = error.localizedDescription
        }
    }

    func chooseSkill(_ skill: SkillEntry) {
        guard skill.isEnabled, engine == .ready, !isBusy, !isChangingModel, !isRunning else { return }
        pendingSkill = skill; libraryVisible = false
        if draft == "/" { draft = "" }
    }

    func showInspector(_ tab: String) { inspectorTab = tab; inspectorVisible = true; libraryVisible = false }

    func refreshPlugins() async {
        guard let root = workspace, let executable = MuseExecutable.locate(preferredPath: executablePath.isEmpty ? nil : executablePath) else { return }
        let token = UUID(); pluginGeneration = token; pluginsLoading = true; pluginsError = nil
        defer { if pluginGeneration == token { pluginsLoading = false } }
        do {
            let result = try await CLICatalog.read(.plugins, executable: executable, workspace: root)
            guard pluginGeneration == token, workspace == root else { return }
            plugins = result["plugins"].array
        } catch { if pluginGeneration == token, workspace == root { pluginsError = error.localizedDescription } }
    }

    func sessionAction(_ method: String, label: String, parameters: [String: JSONValue] = [:]) {
        guard hasLoadedSession, let connection, let id = selectedID else { return }
        if ["goal/set", "goal/edit", "goal/resume"].contains(method), !canRunGoal {
            actionNotice = nil
            actionError = "Wait for model selection to finish, or choose an available model before running a goal."
            return
        }
        let key = method + ":" + id + ":" + (parameters["taskId"]?.string ?? parameters["subagentId"]?.string ?? parameters["itemId"]?.string ?? "")
        guard !pendingActions.contains(key) else { return }
        let token = generation
        pendingActions.insert(key); actionError = nil; actionNotice = nil
        Task {
            defer { if generation == token { pendingActions.remove(key) } }
            do {
                var params = parameters
                params["sessionId"] = .string(id); params["commandId"] = .string(CommandID.make())
                let result = try await connection.request(method, params, timeout: 60)
                guard generation == token, selectedID == id else { return }
                if let session = result["session"]["sessionId"].string, !session.isEmpty { upsert(SessionSummary(result["session"])) }
                if let turn = result["turnId"].string, let state = states[id], !state.completedTurns.contains(turn) { state.activeTurn = turn }
                if method == "subagent/readResult" { actionOutput = result.prettyPrinted }
                actionNotice = result["status"].string == "noop" ? "\(label): \(result["reason"].string ?? "no change needed")." : "\(label) accepted by Muse. Results appear in session activity."
                objectWillChange.send()
            } catch { if generation == token, selectedID == id { actionError = error.localizedDescription } }
        }
    }

    func forkSession() {
        guard canForkSession, let connection, let id = selectedID else { return }
        let token = generation; isBusy = true; actionError = nil
        Task {
            defer { if generation == token { isBusy = false } }
            do {
                let result = try await connection.request("session/fork", ["commandId": .string(CommandID.make()), "sessionId": .string(id)], timeout: 60)
                guard generation == token, selectedID == id else { return }
                let summary = SessionSummary(result["session"])
                guard !summary.id.isEmpty else { throw ConnectionFailure.protocolError("Fork session ID is missing") }
                upsert(summary)
                let state = SessionState(); states[summary.id] = state
                try restore(result["history"], into: state)
                state.loaded = true; state.model = summary.model; state.provider = result["session"]["providerId"].string
                state.approvalMode = result["session"]["approvalMode"]["mode"].string
                stashDraft(); selectedID = summary.id; selectionGeneration = UUID(); draft = ""; pendingSkill = nil; libraryVisible = false
                reasoningEffort = nil
                await refreshModels(); await refreshSkills()
            } catch { if generation == token { actionError = error.localizedDescription } }
        }
    }

    func readToolOutput(_ item: TranscriptItem) {
        guard hasLoadedSession, let connection, let id = selectedID, let ref = item.raw["outputRef"]["id"].string else { return }
        let token = generation; actionError = nil
        Task {
            do {
                let result = try await connection.request("item/readOutput", ["sessionId": .string(id), "itemId": .string(item.id), "outputRef": .string(ref), "lengthBytes": .number(262_144)])
                guard generation == token, selectedID == id else { return }
                if result["encoding"].string == "base64" {
                    actionOutput = result["content"].string.flatMap { Data(base64Encoded: $0) }.flatMap { String(data: $0, encoding: .utf8) } ?? "Binary output. Media type: \(result["mediaType"].string ?? "unknown")."
                } else { actionOutput = result["content"].string ?? "No text was returned." }
                if result["eof"].bool == false { actionOutput = (actionOutput ?? "") + "\n\nShowing the first 256 KiB of stored output." }
            } catch { if generation == token, selectedID == id { actionError = error.localizedDescription } }
        }
    }

    func readUsage() {
        guard let connection, engine == .ready else { return }
        let token = generation
        Task {
            do {
                let result = try await connection.request("usage/read")
                if generation == token { subscriptionUsage = result["usage"] }
            } catch { if generation == token { actionError = error.localizedDescription } }
        }
    }

    func openFullCLI() {
        guard let root = workspace, let executable = MuseExecutable.locate(preferredPath: executablePath.isEmpty ? nil : executablePath) else { return }
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let launcher = FileManager.default.temporaryDirectory.appendingPathComponent("Muse-Code-CLI-" + UUID().uuidString + ".command")
        do {
            let script = "#!/bin/zsh\ncd -- \(quote(root.path)) || exit 1\nMUSE_NO_AUTO_UPDATE=1 \(quote(executable.path))\n"
            try script.write(to: launcher, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launcher.path)
            if !NSWorkspace.shared.open(launcher) { actionError = "macOS could not open the Muse CLI launcher." }
        } catch { actionError = error.localizedDescription }
    }

    func decide(_ request: JSONValue, choice: JSONValue) {
        guard let connection, let id = request["approvalId"].string, !deciding.contains(id) else { return }
        let token = generation, session = request["sessionId"].string ?? ""
        deciding.insert(id)
        Task {
            defer { if generation == token { deciding.remove(id) } }
            do { _ = try await connection.request("approval/decide", ["commandId": .string(CommandID.make()), "sessionId": request["sessionId"],
                "approvalId": .string(id), "choiceId": choice["choiceId"], "requirementId": request["currentRequirementId"]]) }
            catch { report(error, for: session, generation: token) }
        }
    }

    func answer(_ request: JSONValue, answers: [JSONValue]) {
        guard let connection, let id = request["userInputId"].string, !deciding.contains(id) else { return }
        let token = generation, session = request["sessionId"].string ?? ""
        deciding.insert(id)
        Task {
            defer { if generation == token { deciding.remove(id) } }
            do { _ = try await connection.request("userInput/answer", ["commandId": .string(CommandID.make()), "sessionId": request["sessionId"], "userInputId": .string(id), "answers": .array(answers)]) }
            catch { report(error, for: session, generation: token) }
        }
    }

    func attentionCount(_ id: String) -> Int { (states[id]?.approvals.count ?? 0) + (states[id]?.questions.count ?? 0) }
    func sessionIsRunning(_ id: String) -> Bool { states[id]?.activeTurn != nil }

    var pendingRequests: [(id: String, request: JSONValue, question: Bool)] {
        guard let current else { return [] }
        return current.pendingRequestOrder.compactMap { key in
            if key.hasPrefix("approval:"), let request = current.approvals[String(key.dropFirst(9))] { return (key, request, false) }
            if key.hasPrefix("question:"), let request = current.questions[String(key.dropFirst(9))] { return (key, request, true) }
            return nil
        }
    }
    var otherAttentionSession: SessionSummary? { sessions.first { $0.id != selectedID && attentionCount($0.id) > 0 } }

    private func report(_ error: Error, for id: String, generation token: UUID) {
        guard generation == token else { return }
        states[id]?.errorMessage = error.localizedDescription
        if selectedID == id { errorMessage = error.localizedDescription }
    }

    private func receive(_ events: [JSONValue]) {
        for event in events {
            let method = event["method"].string ?? ""
            let p = event["params"]
            if method == "connection/closed" {
                engine = .failed
                if let message = p["message"].string { errorMessage = message }
                if let host = connection {
                    let token = generation
                    Task {
                        let details = await host.diagnosticDetails()
                        if generation == token { errorDetails = details }
                    }
                }
                for state in states.values { state.activeTurn = nil; state.loaded = false; state.unavailable = true }
                continue
            }
            if method == "session/started" { upsert(SessionSummary(p["session"])) }
            guard let id = p["sessionId"].string ?? p["session"]["sessionId"].string else { continue }
            if loading.contains(id) { buffered[id, default: []].append(event); continue }
            let state = states[id] ?? SessionState(); states[id] = state
            state.transcript.apply(event)
            switch method {
            case "turn/started": state.activeTurn = p["turnId"].string
            case "turn/completed":
                if let turn = p["turnId"].string { state.completedTurns.insert(turn); if state.activeTurn == turn { state.activeTurn = nil } }
                state.lastDuration = p["durationMs"].int
                if p["terminal"].string == "failed" {
                    state.errorMessage = p["error"]["message"].string ?? p["reason"].string ?? "Muse could not complete the turn."
                    if id == selectedID { errorMessage = state.errorMessage }
                }
            case "session/closed": invalidateLoadedSession(state, id: id)
            case "session/statusChanged":
                if p["status"].string == "idle" { state.activeTurn = nil }
                else if p["status"].string == "notLoaded" { invalidateLoadedSession(state, id: id) }
            case "session/modelChanged":
                state.model = p["modelId"].string; state.provider = p["providerId"].string; state.catalogModel = nil
                if id == selectedID { Task { await refreshModels() } }
            case "skill/changed": if id == selectedID { Task { await refreshSkills() } }
            case "session/goalChanged": state.goal = p["goal"]
            case "session/approvalModeChanged": state.approvalMode = p["mode"].string ?? p["approvalMode"]["mode"].string
            case "session/tokenUsage": state.totalTokens = p["cumulative"]["totalTokens"].int
            case "session/contextUsage": state.contextUsed = p["usedTokens"].int; state.contextWindow = p["windowTokens"].int
            case "session/nameChanged": if let index = sessions.firstIndex(where: { $0.id == id }), let name = p["name"].string { sessions[index].title = name }
            case "approval/request", "approval/requested":
                if let key = p["approvalId"].string {
                    if state.approvals[key] == nil { state.pendingRequestOrder.append("approval:" + key) }
                    state.approvals[key] = p
                }
            case "approval/updated":
                if let key = p["approvalId"].string {
                    var raw = state.approvals[key]?.object ?? [:]
                    raw.merge(p.object) { _, updated in updated }; state.approvals[key] = .object(raw)
                }
            case "approval/resolved": if let key = p["approvalId"].string { state.approvals[key] = nil; state.pendingRequestOrder.removeAll { $0 == "approval:" + key }; deciding.remove(key) }
            case "userInput/request", "userInput/requested":
                if let key = p["userInputId"].string {
                    if state.questions[key] == nil { state.pendingRequestOrder.append("question:" + key) }
                    state.questions[key] = p
                }
            case "userInput/settled": if let key = p["userInputId"].string { state.questions[key] = nil; state.pendingRequestOrder.removeAll { $0 == "question:" + key }; deciding.remove(key) }
            case "view/gap", "session/viewHealthChanged":
                state.unavailable = true
                if id == selectedID { errorMessage = "The live transcript is unavailable. Reconnect before continuing this session." }
            default: break
            }
        }
        objectWillChange.send()
        eventRevision += 1
        let pending = states.values.reduce(0) { $0 + $1.approvals.count + $1.questions.count }
        NSApp?.dockTile.badgeLabel = pending == 0 ? nil : String(pending)
        if pending > 0, NSApp?.isActive == false { NSApp?.requestUserAttention(.informationalRequest) }
    }

    private func invalidateLoadedSession(_ state: SessionState, id: String) {
        state.loaded = false; state.unavailable = true; state.activeTurn = nil
        state.approvals = [:]; state.questions = [:]; state.pendingRequestOrder = []
        if id == selectedID { errorMessage = "This session was unloaded. Select it again to resume before continuing." }
    }

    private func upsert(_ row: SessionSummary) {
        guard !row.id.isEmpty, row.workspace == workspace?.path else { return }
        if let index = sessions.firstIndex(where: { $0.id == row.id }) {
            var merged = row
            if row.title == "New session", sessions[index].title != "New session" { merged.title = sessions[index].title }
            if row.updated.isEmpty { merged.updated = sessions[index].updated }
            sessions[index] = merged
        } else {
            var inserted = row
            if inserted.updated.isEmpty { inserted.updated = ISO8601DateFormatter().string(from: Date()) }
            sessions.insert(inserted, at: 0)
        }
    }
    private var draftKey: String { selectedID ?? "new:" + (workspace?.path ?? "") }
    private func stashDraft() { drafts[draftKey] = draft }

    func refreshFiles() {
        filePreview = nil; fileError = nil; fileNodes = []
        fileGeneration = UUID(); let token = fileGeneration
        guard let root = workspace else { return }
        filesLoading = true
        Task {
            do {
                let nodes = try await Task.detached(priority: .utility) { try FileBrowser.scan(root) }.value
                guard fileGeneration == token else { return }
                fileNodes = nodes; filesLoading = false
            } catch { if fileGeneration == token { fileError = "This folder could not be read."; filesLoading = false } }
        }
    }

    func previewFile(_ url: URL) {
        guard let root = workspace else { return }
        fileGeneration = UUID(); let token = fileGeneration
        Task {
            do {
                let preview = try await Task.detached(priority: .utility) { try FileBrowser.preview(url, in: root) }.value
                guard fileGeneration == token else { return }
                filePreview = preview; fileError = nil
            } catch { if fileGeneration == token { filePreview = nil; fileError = "Preview unavailable. The file may be binary, inaccessible, or outside this workspace." } }
        }
    }

    func mentionFile() {
        guard let preview = filePreview else { return }
        draft += (draft.isEmpty || draft.hasSuffix(" ") ? "" : " ") + "@" + preview.relativePath + " "
    }

    func saveExecutable() {
        UserDefaults.standard.set(executablePath, forKey: "museExecutable")
        settingsVisible = false; reconnect()
    }

    func shutdown() { connection?.stop() }
    func shutdownAndWait() async { isStopping = true; await connection?.shutdown(); isStopping = false }
}
