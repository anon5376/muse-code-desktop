import SwiftUI
import MuseCore

/// The ⌘K palette: session-catalog skills and commands, bounded to
/// 560×420 over the reading region. Rows are keyed by entry id — an index
/// key recycled stale actions under filtering.
struct CommandPaletteView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var query = ""
    @State private var selected = 0
    @FocusState private var searchFocused: Bool

    private struct Entry: Identifiable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let action: () -> Void
    }
    private var entries: [Entry] {
        let skills = store.skills.filter { $0.isEnabled && $0.matches(query) }.map { skill in
            Entry(id: skill.id, title: "/" + skill.invocationName, detail: skill.description, symbol: "sparkle") { store.chooseSkill(skill) }
        }
        let actions: [Entry] = [
            Entry(id: "session", title: "Session controls", detail: "Rename, fork, compact, shell and usage", symbol: "slider.horizontal.3") { store.showInspector("Session") },
            Entry(id: "goal", title: "Set a goal", detail: "Give Muse an objective", symbol: "flag") { store.showInspector("Session") },
            Entry(id: "activity", title: "Activity", detail: "Tools, agents and workflows", symbol: "waveform.path") { store.showInspector("Activity") },
            Entry(id: "files", title: "Workspace files", detail: "Read source and add file context", symbol: "folder") { store.showInspector("Files") },
            Entry(id: "skills", title: "Browse skills", detail: "Descriptions and source filters", symbol: "square.stack.3d.up") { store.showInspector("Skills") },
            Entry(id: "settings", title: "Settings", detail: "Muse executable and connection", symbol: "gearshape") { store.libraryVisible = false; store.settingsVisible = true },
            Entry(id: "terminal", title: "Open Muse in Terminal", detail: "Login, plugins, MCP and voice", symbol: "terminal") { store.libraryVisible = false; store.openFullCLI() }
        ]
        return Array(skills.prefix(100)) + actions.filter { query.isEmpty || ($0.title + " " + $0.detail).localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(MuseTheme.secondary)
                TextField("Skills and commands", text: $query).textFieldStyle(.plain).font(.system(size: 14))
                    .focused($searchFocused).onSubmit { activate() }.accessibilityLabel("Search skills and commands")
                if store.skillsLoading { ProgressView().controlSize(.small) }
                IconButton(symbol: "xmark", label: "Close command palette") { store.libraryVisible = false }
            }.padding(16)
            Hairline()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if let error = store.skillsError { Text(error).font(.system(size: 11)).foregroundStyle(MuseTheme.error).padding(12) }
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            Button { entry.action() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.symbol).foregroundStyle(MuseTheme.secondary).frame(width: 20)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.title).font(.system(size: 13, weight: .medium))
                                        Text(entry.detail).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if index == selected { Image(systemName: "return").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary) }
                                }.padding(10).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                    .background(index == selected ? MuseTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).id(entry.id)
                        }
                        if entries.isEmpty { Text("No matching skills or commands.").font(.system(size: 13)).foregroundStyle(MuseTheme.secondary).padding(24) }
                    }.padding(8)
                }
                .onChange(of: selected) { _, value in
                    if entries.indices.contains(value) { proxy.scrollTo(entries[value].id) }
                }
            }
            Hairline()
            HStack {
                Text(store.skillsAreSessionCatalog ? "This session’s skills" : "Installed skills · availability checked before sending")
                Spacer()
                Text("↑ ↓ choose  ·  ↵ use  ·  Esc close")
            }.font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).padding(12)
        }
        .foregroundStyle(MuseTheme.text).background(MuseTheme.popover, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MuseTheme.stroke))
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
        .onChange(of: query) { _, _ in selected = 0 }
        .onKeyPress(.downArrow) { selected = min(max(0, entries.count - 1), selected + 1); return .handled }
        .onKeyPress(.upArrow) { selected = max(0, selected - 1); return .handled }
        .onExitCommand { store.libraryVisible = false }
    }
    private func activate() {
        guard entries.indices.contains(selected) else { return }
        entries[selected].action()
    }
}

/// Skills tab of the inspector: searchable catalog with per-skill detail
/// disclosure. Uses explicit expand state + chevron button, not a
/// custom-label DisclosureGroup (dead pointer hit-path on macOS 26).
struct SkillsInspectorView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var query = ""
    @State private var source = "All"
    @State private var expanded = Set<String>()
    private var skills: [SkillEntry] { store.skills.filter { $0.matches(query) && (source == "All" || $0.source == source) } }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Find a skill", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Search skills")
                IconButton(symbol: "arrow.clockwise", label: "Refresh skills") { Task { await store.refreshSkills() } }
            }.padding(.horizontal, 16)
            Picker("Source", selection: $source) {
                Text("All sources").tag("All")
                ForEach(Array(Set(store.skills.map(\.source))).sorted(), id: \.self) { Text($0.capitalized).tag($0) }
            }.padding(.horizontal, 16)
            Text("\(store.skills.count) \(store.skillsAreSessionCatalog ? "available in session" : "installed")").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
            if store.skillsLoading { ProgressView().controlSize(.small) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let error = store.skillsError { Text(error).foregroundStyle(MuseTheme.error) }
                    ForEach(skills) { skill in
                        // Custom-label DisclosureGroup has a dead pointer hit path on macOS
                        // (only AX toggles it), so expansion is an explicit Button row.
                        let isExpanded = expanded.contains(skill.id)
                        Button {
                            if isExpanded { expanded.remove(skill.id) } else { expanded.insert(skill.id) }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(MuseTheme.muted).rotationEffect(.degrees(isExpanded ? 90 : 0)).padding(.top, 4)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(skill.name).font(.system(size: 13, weight: .medium))
                                    Text(skill.source.capitalized + (skill.isEnabled ? "" : " · Disabled")).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                                }
                                Spacer(minLength: 0)
                            }.padding(.vertical, 4).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Show details for \(skill.name)")
                        if isExpanded {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(skill.description.isEmpty ? "No description supplied by Muse." : skill.description).font(.system(size: 12)).lineSpacing(4).textSelection(.enabled)
                                Text("/" + skill.invocationName).font(.system(size: 11, design: .monospaced)).foregroundStyle(MuseTheme.secondary)
                                if let hint = skill.raw["argumentHint"].string { Text("Arguments: " + hint).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary) }
                                Button("Use in chat") { store.chooseSkill(skill) }
                                    .buttonStyle(.borderedProminent).tint(MuseTheme.controlAccent)
                                    .disabled(!skill.isEnabled || store.engine != .ready || store.isBusy || store.isRunning || store.isChangingModel)
                                    .accessibilityLabel("Use skill \(skill.name)")
                            }.padding(.top, 8).padding(.leading, 18)
                        }
                        Hairline()
                    }
                    if skills.isEmpty && !store.skillsLoading { Text("No matching skills.").foregroundStyle(MuseTheme.secondary) }
                }.font(.system(size: 12)).padding(16)
            }
        }.task { await store.refreshSkills() }
    }
}

/// Goal tab: set/pause/resume/clear the session goal via host controls.
struct GoalControlsView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var objective = ""
    @State private var clearing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal").font(.system(size: 13, weight: .semibold))
            if let goal = store.current?.goal, goal != .null {
                Text(goal["objective"].string ?? "").font(.system(size: 13)).textSelection(.enabled)
                Text(ActivityStatus.label(goal["status"].string ?? "")).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
            }
            TextField("Give Muse an objective", text: $objective, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4).accessibilityLabel("Goal objective")
            Button("Start goal") { store.sessionAction("goal/set", label: "Goal", parameters: ["objective": .string(objective)]) }
                .buttonStyle(.borderedProminent).tint(MuseTheme.controlAccent)
                .disabled(!store.canRunGoal || objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            HStack {
                Button("Pause") { store.sessionAction("goal/pause", label: "Pause goal") }.disabled(!store.hasLoadedSession || store.current?.goal == .null)
                Button("Resume") { store.sessionAction("goal/resume", label: "Resume goal") }.disabled(!store.canRunGoal || store.current?.goal == .null)
                Button("Clear…") { clearing = true }.disabled(!store.hasLoadedSession || store.current?.goal == .null)
            }.controlSize(.small)
        }.font(.system(size: 12)).foregroundStyle(MuseTheme.text)
        .confirmationDialog("Clear this session’s goal?", isPresented: $clearing) {
            Button("Clear goal", role: .destructive) { store.sessionAction("goal/clear", label: "Clear goal") }
        }
    }
}

/// Session tab: rename, fork, compact, and arbitrary host commands.
struct SessionControlsView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var name = ""
    @State private var command = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !store.hasLoadedSession { Text("Send a message or resume a session to use its controls.").foregroundStyle(MuseTheme.secondary) }
                if let error = store.actionError { Text(error).foregroundStyle(MuseTheme.error).textSelection(.enabled) }
                if let notice = store.actionNotice { Text(notice).foregroundStyle(MuseTheme.secondary).textSelection(.enabled) }
                Text("Session").font(.system(size: 13, weight: .semibold))
                TextField("Session name", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("Session name")
                Button("Rename") { store.sessionAction("session/rename", label: "Rename", parameters: ["name": .string(name)]) }
                    .disabled(!store.hasLoadedSession || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Fork session") { store.forkSession() }.disabled(!store.canForkSession)
                Button("Compact context") { store.sessionAction("session/compact", label: "Compaction") }.disabled(!store.hasLoadedSession || store.isRunning)
                Button("Stop background tasks") { store.sessionAction("task/stopAll", label: "Stop background tasks") }.disabled(!store.hasLoadedSession)
                Hairline()
                GoalControlsView(store: store)
                Hairline()
                Text("Run a shell command").font(.system(size: 13, weight: .semibold))
                Text("Runs through Muse with your approval policy.").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                TextField("Command", text: $command, axis: .vertical).font(.system(size: 12, design: .monospaced)).textFieldStyle(.roundedBorder).lineLimit(2...5).accessibilityLabel("Shell command")
                Button("Run command") { store.sessionAction("session/userShell", label: "Shell command", parameters: ["commandText": .string(command)]) }
                    .disabled(!store.hasLoadedSession || !store.grantedCapabilities.contains("userShell") || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !store.grantedCapabilities.contains("userShell") { Text("This host has not enabled shell commands.").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary) }
                Hairline()
                Text("Usage").font(.system(size: 13, weight: .semibold))
                Button("Read observed usage") { store.readUsage() }.disabled(store.engine != .ready)
                if store.subscriptionUsage == .null { Text("No usage observation from Muse.").foregroundStyle(MuseTheme.secondary) }
                else {
                    Text("Current window: \(store.subscriptionUsage["window"]["usedPercent"].int.map(String.init) ?? "unknown")% used\nWeekly: \(store.subscriptionUsage["weekly"]["usedPercent"].int.map(String.init) ?? "unknown")% used")
                    if let timestamp = store.subscriptionUsage["observedAtMs"].int {
                        Text("Observed " + Date(timeIntervalSince1970: Double(timestamp) / 1_000).formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                    }
                }
                if let output = store.actionOutput {
                    DisclosureGroup("Retrieved output") {
                        Text(output).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Hairline()
                ExtensionsInspectorView(store: store)
            }.font(.system(size: 12)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Extensions tab: lists host-reported extensions; management stays in
/// the CLI (Open Muse in Terminal).
struct ExtensionsInspectorView: View {
    @ObservedObject var store: WorkspaceStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extensions").font(.system(size: 13, weight: .semibold))
            Text("Muse loads your configured plugins and MCP tools. Their calls appear in Activity.").font(.system(size: 12)).foregroundStyle(MuseTheme.secondary)
            DisclosureGroup("Installed plugins") {
                if store.pluginsLoading { ProgressView().controlSize(.small) }
                if let error = store.pluginsError { Text(error).foregroundStyle(MuseTheme.error) }
                ForEach(Array(store.plugins.enumerated()), id: \.offset) { _, plugin in
                    Text(plugin["name"].string ?? plugin["id"].string ?? "Installed plugin")
                }
                if store.plugins.isEmpty && !store.pluginsLoading { Text("No installed plugins reported by Muse.").foregroundStyle(MuseTheme.secondary) }
                Button("Refresh plugins") { Task { await store.refreshPlugins() } }
            }.font(.system(size: 12))
            Button { store.openFullCLI() } label: { Label("Open Muse in Terminal", systemImage: "terminal") }
            Text("Login, plugin/MCP management and voice use Muse’s terminal interface.").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
        }
    }
}

/// Activity tab: non-message transcript items (tool calls, reasoning
/// excluded from chat rows) as interactive rows.
struct ActivityInspectorView: View {
    @ObservedObject var store: WorkspaceStore
    private var items: [TranscriptItem] { (store.current?.transcript.items ?? []).filter { !["userMessage", "agentMessage", "reasoning"].contains($0.kind) } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if items.isEmpty { Text("Tools, agents and workflows appear here as Muse works.").font(.system(size: 12)).foregroundStyle(MuseTheme.secondary) }
                ForEach(items) { item in ToolActivityRow(item: item, store: store) }
                if let error = store.actionError { Text(error).font(.system(size: 12)).foregroundStyle(MuseTheme.error) }
                if let notice = store.actionNotice { Text(notice).font(.system(size: 12)).foregroundStyle(MuseTheme.secondary) }
                if let output = store.actionOutput {
                    DisclosureGroup("Retrieved output") { Text(output).font(.system(size: 11, design: .monospaced)).textSelection(.enabled) }
                }
            }.padding(16)
        }
    }
}

/// One tool-activity row with its destructive/host actions gated behind
/// an explicit confirm state.
struct ToolActivityRow: View {
    let item: TranscriptItem
    @ObservedObject var store: WorkspaceStore
    @State private var message = ""
    @State private var confirmingAction: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.kind == "subagent" ? "person.2" : "terminal").foregroundStyle(MuseTheme.accent)
                Text(item.tool).font(.system(size: 12, weight: .medium)).lineLimit(2)
                Spacer()
                Text(item.statusLabel).font(.system(size: 11)).foregroundStyle(item.status == "failed" ? MuseTheme.error : MuseTheme.secondary)
            }
            HStack {
                if item.raw["outputRef"]["id"].string != nil { Button("Read stored output") { store.readToolOutput(item) } }
                if item.kind == "toolCall", item.isActive {
                    Button("Background") { store.sessionAction("task/background", label: "Background task", parameters: ["taskId": .string(item.id)]) }
                    Button("Stop task") { store.sessionAction("task/stop", label: "Stop task", parameters: ["taskId": .string(item.id)]) }
                }
                if let child = item.raw["subagentId"].string {
                    Menu("Agent controls") {
                        ForEach(agentActions, id: \.self) { action in
                            Button(action == "readResult" ? "Read result" : action.capitalized) {
                                if action == "stop" || action == "close" { confirmingAction = action }
                                else { store.sessionAction("subagent/" + action, label: action.capitalized, parameters: ["subagentId": .string(child)]) }
                            }
                        }
                    }.fixedSize()
                }
                if let run = item.raw["workflowRunId"].string, item.isActive {
                    Button("Cancel workflow") { store.sessionAction("workflow/cancel", label: "Cancel workflow", parameters: ["workflowRunId": .string(run)]) }
                }
            }.controlSize(.small).disabled(!store.hasLoadedSession)
            if let child = item.raw["subagentId"].string, !["closed", "closing"].contains(item.raw["controlStatus"].string ?? "") {
                HStack {
                    TextField("Message this agent", text: $message).textFieldStyle(.roundedBorder)
                    Button("Send") { store.sessionAction("subagent/sendMessage", label: "Agent message", parameters: ["subagentId": .string(child), "body": .string(message)]) }
                        .disabled(!store.hasLoadedSession || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Follow up") { store.sessionAction("subagent/followupTask", label: "Agent follow-up", parameters: ["subagentId": .string(child), "body": .string(message)]) }
                        .disabled(!store.hasLoadedSession || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.font(.system(size: 11))
            }
            if let run = item.raw["workflowRunId"].string {
                ForEach(Array(item.raw["children"].array.enumerated()), id: \.offset) { _, child in
                    HStack {
                        Text(child["label"].string ?? child["childId"].string ?? "Workflow child").font(.system(size: 11)).lineLimit(1)
                        Text(ActivityStatus.label(child["status"].string ?? "")).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                        Spacer()
                        if let childID = child["childId"].string, let attempt = child["attempt"].int {
                            ForEach(["skip", "retry"], id: \.self) { action in
                                Button(action.capitalized) {
                                    store.sessionAction("workflow/childControl", label: action.capitalized + " workflow child", parameters: ["workflowRunId": .string(run), "childId": .string(childID), "attempt": .number(Double(attempt)), "action": .string(action)])
                                }.disabled(!store.hasLoadedSession)
                            }
                        }
                    }.controlSize(.small)
                }
            }
            DisclosureGroup("Details") {
                Text(String(item.raw.prettyPrinted.prefix(24_000))).font(.system(size: 11, design: .monospaced)).foregroundStyle(MuseTheme.secondary).textSelection(.enabled)
            }.font(.system(size: 11))
            Hairline().padding(.top, 8)
        }
        .confirmationDialog("\((confirmingAction ?? "stop").capitalized) this agent?", isPresented: Binding(get: { confirmingAction != nil }, set: { if !$0 { confirmingAction = nil } })) {
            if let action = confirmingAction, let child = item.raw["subagentId"].string {
                Button(action.capitalized + " agent", role: .destructive) {
                    store.sessionAction("subagent/" + action, label: action.capitalized, parameters: ["subagentId": .string(child)])
                    confirmingAction = nil
                }
            }
        }
    }
    private var agentActions: [String] {
        switch item.raw["controlStatus"].string {
        case "closed": return ["reopen"]
        case "closing": return []
        case "resultReady": return ["readResult", "close"]
        case "accepted", "starting", "running": return ["interrupt", "stop"]
        case "recoveryPending", "manualReconciliation": return ["resume", "close"]
        default:
            if item.isActive { return ["interrupt", "stop"] }
            if item.status == "interrupted" { return ["resume", "close"] }
            return item.status == "completed" || item.status == "failed" ? ["readResult", "close"] : []
        }
    }
}
