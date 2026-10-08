import SwiftUI
import AppKit
import MuseCore

struct WorkspaceView: View {
    @ObservedObject var store: WorkspaceStore
    @FocusState private var composerFocused: Bool
    @State private var goalVisible = false
    @State private var clearingGoal = false

    var body: some View {
        GeometryReader { geometry in
            let inspectorBeside = geometry.size.width - (store.sidebarVisible ? 249 : 0) - 301 >= 560
            let centreWidth = geometry.size.width - (store.sidebarVisible ? 249 : 0) - (store.inspectorVisible && inspectorBeside ? 301 : 0)
            HStack(spacing: 0) {
                if store.sidebarVisible {
                    sidebar.frame(width: 248)
                    Rectangle().fill(MuseTheme.line).frame(width: 1)
                }
                VStack(spacing: 0) {
                    toolbar
                    Hairline()
                    if store.echoMode {
                        HStack(spacing: 7) {
                            Image(systemName: "network.slash")
                            Text(store.hostVersion == "synthetic-fixture" ? "Offline UI fixture · synthetic data, no provider or tools" : "Offline test · echo replies, workspace tools disabled")
                            Spacer()
                        }.font(.system(size: 11)).foregroundStyle(MuseTheme.accent)
                            .padding(.horizontal, 24).padding(.vertical, 8).background(MuseTheme.accent.opacity(0.05))
                    }
                    if store.schemaWarning {
                        Text("The CLI protocol differs from the tested version. Some details may be unavailable.")
                            .font(.system(size: 12)).foregroundStyle(MuseTheme.accent).padding(10)
                    }
                    if let error = store.errorMessage { errorBanner(error) }
                    if let session = store.otherAttentionSession {
                        Button { store.selectSession(session.id) } label: {
                            Label("Muse needs a decision in “\(session.title)”", systemImage: "hand.raised.fill").frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(MuseTheme.attention).padding(.horizontal, 24).padding(.vertical, 8)
                    }
                    if let goal = store.current?.goal, goal != .null { goalStrip(goal) }
                    ZStack(alignment: .trailing) {
                        Group {
                            if store.current?.transcript.items.isEmpty == false { TranscriptView(store: store) }
                            else { welcome }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        if store.inspectorVisible && !inspectorBeside {
                            InspectorView(store: store).frame(width: 300)
                                .overlay(alignment: .leading) { Rectangle().fill(MuseTheme.stroke).frame(width: 1) }
                        }
                    }
                    .overlay {
                        GeometryReader { area in
                            if store.libraryVisible {
                                CommandPaletteView(store: store)
                                    .frame(width: min(560, area.size.width - 24), height: min(420, max(120, area.size.height - 24)))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 12)
                            }
                        }
                    }.clipped()
                    PendingRequestDock(store: store).padding(.horizontal, 24)
                    composer(width: centreWidth - 48).padding(.horizontal, 24).padding(.bottom, 16).padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MuseTheme.canvas)
                if store.inspectorVisible && inspectorBeside {
                    Rectangle().fill(MuseTheme.line).frame(width: 1)
                    InspectorView(store: store).frame(width: 300)
                }
            }
        }
        .background(MuseTheme.canvas)
        .foregroundStyle(MuseTheme.text)
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $store.settingsVisible) { SettingsView(store: store) }
        .onExitCommand { store.libraryVisible = false; goalVisible = false }
        .onChange(of: store.draft) { old, new in if old.isEmpty && new == "/" { store.openLibrary() } }
        .onChange(of: store.pendingSkill?.id) { _, id in if id != nil { composerFocused = true } }
        .overlay {
            if store.isStopping {
                ZStack { MuseTheme.canvas.opacity(0.9); ProgressView("Stopping Muse…").foregroundStyle(MuseTheme.text) }
            }
        }
        .confirmationDialog("Clear this session’s goal?", isPresented: $clearingGoal) {
            Button("Clear goal", role: .destructive) { store.sessionAction("goal/clear", label: "Clear goal") }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            workspacePicker.padding(.leading, 82).padding(.trailing, 12).frame(height: 52)

            Button { store.newSession(); composerFocused = true } label: {
                HStack {
                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                    Text("New session").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("⌘ N").font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
                }.padding(.horizontal, 12).frame(height: 37).background(MuseTheme.raised, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain).disabled(store.engine != .ready || store.isBusy)
                .padding(.horizontal, 14).padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(MuseTheme.muted)
                TextField("Find a session", text: $store.search).textFieldStyle(.plain).font(.system(size: 12))
            }.padding(.horizontal, 11).padding(.vertical, 10).padding(.horizontal, 14).padding(.top, 12)

            HStack {
                Text("Sessions").font(.system(size: 11, weight: .medium)).foregroundStyle(MuseTheme.muted)
                Spacer()
                IconButton(symbol: "arrow.clockwise", label: "Refresh sessions") { Task { await store.refreshSessions() } }
            }.padding(.leading, 24).padding(.trailing, 14).padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(store.visibleSessions) { session in
                        Button { store.selectSession(session.id) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "bubble.left").font(.system(size: 12))
                                    .foregroundStyle(session.id == store.selectedID ? MuseTheme.accent : MuseTheme.muted).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(session.title).font(.system(size: 12, weight: session.id == store.selectedID ? .medium : .regular))
                                        .foregroundStyle(MuseTheme.text).lineLimit(2).multilineTextAlignment(.leading)
                                    if let branch = session.branch {
                                        Label(branch, systemImage: "arrow.triangle.branch").font(.system(size: 11)).foregroundStyle(MuseTheme.muted).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                                if store.attentionCount(session.id) > 0 {
                                    Label(String(store.attentionCount(session.id)), systemImage: "hand.raised.fill").font(.system(size: 11)).foregroundStyle(MuseTheme.attention).help("Muse needs your decision")
                                } else if store.sessionIsRunning(session.id) { Circle().fill(MuseTheme.accent).frame(width: 5, height: 5).padding(.top, 5) }
                            }.padding(.horizontal, 12).padding(.vertical, 11).frame(maxWidth: .infinity, alignment: .leading)
                                .background(session.id == store.selectedID ? MuseTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(store.isBusy)
                    }
                    if store.visibleSessions.isEmpty {
                        Text(store.search.isEmpty ? "Your sessions will appear here." : "No matching sessions.")
                            .font(.system(size: 12)).foregroundStyle(MuseTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.top, 12)
                    }
                }.padding(.horizontal, 12)
            }
            Spacer(minLength: 8)
            Hairline().padding(.horizontal, 20)
            HStack(spacing: 10) {
                MuseMark(size: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Muse Code").font(.system(size: 13, weight: .semibold))
                    Text("Unofficial desktop client").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 22).padding(.top, 16)
                .help("Independent client. Not the official Muse Code desktop app; not affiliated with or endorsed by Meta.")
            HStack(spacing: 8) {
                Circle().fill(store.engine == .ready ? (store.echoMode ? MuseTheme.accent : MuseTheme.success) : MuseTheme.muted).frame(width: 5, height: 5)
                Text(store.hostVersion.isEmpty || store.echoMode ? store.engineLabel : "Muse \(store.hostVersion) · connected").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).lineLimit(1)
                Spacer()
                IconButton(symbol: "gearshape", label: "Settings") { store.settingsVisible = true }
            }.padding(.leading, 23).padding(.trailing, 14).padding(.vertical, 14)
        }.background(MuseTheme.sidebar)
    }

    private var workspacePicker: some View {
        Menu {
            Button("Open Workspace…") { store.chooseWorkspace() }
            if !store.recentWorkspaces.isEmpty {
                Divider()
                ForEach(store.recentWorkspaces, id: \.self) { path in
                    Button(URL(fileURLWithPath: path).lastPathComponent) { store.setWorkspace(URL(fileURLWithPath: path, isDirectory: true)) }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder").font(.system(size: 13)).foregroundStyle(MuseTheme.secondary)
                Text(store.workspace?.lastPathComponent ?? "Open workspace").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
            }.contentShape(Rectangle())
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).disabled(store.isBusy).accessibilityLabel("Choose workspace")
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if !store.sidebarVisible { IconButton(symbol: "sidebar.left", label: "Show sessions") { store.sidebarVisible = true } }
            VStack(alignment: .leading, spacing: 3) {
                Text(store.selectedSession?.title ?? "New session").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    .onTapGesture(count: 2) { store.showInspector("Session") }
                    .contextMenu {
                        Button("Rename…") { store.showInspector("Session") }
                        Button("Fork session") { store.forkSession() }.disabled(!store.canForkSession)
                        Button("Compact context") { store.sessionAction("session/compact", label: "Compaction") }.disabled(!store.hasLoadedSession || store.isRunning)
                    }
                Text([store.modelLabel, store.reasoningEffort?.capitalized, policyLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 4)
            if store.isBusy { ProgressView().controlSize(.small).scaleEffect(0.75).frame(width: 18) }
            IconButton(symbol: "command", label: "Skills and commands (Command-K)", selected: store.libraryVisible) { store.libraryVisible.toggle(); if store.libraryVisible { store.openLibrary() } }
            IconButton(symbol: "flag", label: "Goal", selected: goalVisible) { goalVisible.toggle() }
                .popover(isPresented: $goalVisible) { GoalControlsView(store: store).padding(16).frame(width: 340).background(MuseTheme.popover).preferredColorScheme(.dark) }
            IconButton(symbol: "waveform.path", label: "Activity", selected: store.inspectorVisible && store.inspectorTab == "Activity") { store.showInspector("Activity") }
            IconButton(symbol: "sidebar.right", label: "Toggle file inspector", selected: store.inspectorVisible) { store.inspectorVisible.toggle() }
        }.padding(.horizontal, 24).frame(height: 52)
    }

    private var welcome: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            Text(store.workspace?.lastPathComponent ?? "Open a workspace").font(.system(size: 20, weight: .semibold))
            Text(store.workspace == nil ? "Choose the project Muse will work in." : "\(store.visibleSessions.count) \(store.visibleSessions.count == 1 ? "session" : "sessions") in this workspace")
                .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).padding(.top, 8).padding(.bottom, 24)
            if !store.visibleSessions.isEmpty {
                Text("Continue").font(.system(size: 11, weight: .semibold)).foregroundStyle(MuseTheme.secondary).padding(.bottom, 8)
                ForEach(Array(store.visibleSessions.prefix(3))) { session in
                    Button { store.selectSession(session.id) } label: {
                        HStack { Text(session.title).lineLimit(1); Spacer(); Image(systemName: "arrow.right") }.font(.system(size: 13)).padding(.vertical, 10).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Hairline().padding(.vertical, 16)
            }
            if store.workspace == nil {
                Button { store.chooseWorkspace() } label: {
                    Label("Open a workspace", systemImage: "folder.badge.plus").font(.system(size: 13, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 5)
                }.buttonStyle(.borderedProminent).tint(MuseTheme.controlAccent)
            } else {
                VStack(spacing: 0) {
                    starter("Survey this project", symbol: "map", prompt: "Inspect this project and identify the three most important improvements. Don't change files yet.")
                    starter("Find and explain a bug", symbol: "scope", prompt: "Find a reproducible bug in this project, explain its impact, and propose the smallest fix.")
                    starter("Start a feature…", symbol: "hammer", prompt: "I'd like to build ")
                }
            }
          }.frame(maxWidth: 560, alignment: .leading).padding(.horizontal, 32).padding(.vertical, 32).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func starter(_ title: String, symbol: String, prompt: String) -> some View {
        Button { store.draft = prompt; composerFocused = true } label: {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(MuseTheme.muted).frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13)).foregroundStyle(MuseTheme.text)
                    Text(prompt).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "text.insert").font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
            }.padding(.vertical, 13).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func composer(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let skill = store.pendingSkill {
                HStack(spacing: 7) {
                    Image(systemName: "sparkle")
                    Text("/" + skill.invocationName).lineLimit(1)
                    Button { store.pendingSkill = nil } label: { Image(systemName: "xmark").font(.system(size: 11)) }
                        .buttonStyle(.plain).accessibilityLabel("Remove selected skill")
                    Spacer()
                }.font(.system(size: 11, weight: .medium)).foregroundStyle(MuseTheme.accent).padding(.bottom, 8)
            }
            ZStack(alignment: .topLeading) {
                if store.draft.isEmpty {
                    Text(store.workspace == nil ? "Choose a workspace to start…" : "Message Muse — / for skills")
                        .font(.system(size: 14)).foregroundStyle(MuseTheme.muted).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                }
                TextEditor(text: $store.draft).font(.system(size: 14)).scrollContentBackground(.hidden)
                    .frame(height: editorHeight(width: width - 32)).focused($composerFocused).accessibilityLabel("Message Muse")
            }
            HStack(spacing: 12) {
                Menu {
                    Button("Add from workspace") { store.showInspector("Files") }
                    Button("Use a skill…") { store.openLibrary() }
                    Button("Session controls…") { store.showInspector("Session") }
                } label: { Image(systemName: "plus").font(.system(size: 14)).frame(width: 28, height: 28) }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).accessibilityLabel("Add to message")
                Spacer(minLength: 4)
                ModelPickerControl(store: store).layoutPriority(-1)
                if store.isRunning {
                    Button { store.interrupt() } label: {
                        Image(systemName: "stop.fill").font(.system(size: 12)).foregroundStyle(MuseTheme.ink)
                            .frame(width: 30, height: 30).background(MuseTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).help("Stop the current turn").accessibilityLabel("Stop Muse")
                } else {
                    Button { store.send() } label: {
                        Image(systemName: "arrow.up").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(store.canSend ? MuseTheme.ink : MuseTheme.muted)
                            .frame(width: 30, height: 30).background(store.canSend ? MuseTheme.accent : MuseTheme.line, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).keyboardShortcut(.return, modifiers: .command).disabled(!store.canSend)
                        .help("Send message (Command-Return)").accessibilityLabel("Send message")
                }
            }.padding(.top, 8)
        }.padding(12).background(MuseTheme.raised, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(composerFocused ? MuseTheme.accent : MuseTheme.stroke, lineWidth: 1))
    }

    private func editorHeight(width: CGFloat) -> CGFloat {
        let text = (store.draft.isEmpty ? " " : store.draft) as NSString
        let bounds = text.boundingRect(with: NSSize(width: max(100, width), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: NSFont.systemFont(ofSize: 14)])
        return min(200, max(44, ceil(bounds.height) + 16))
    }

    private func goalStrip(_ goal: JSONValue) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag").foregroundStyle(MuseTheme.accent)
            Text(goal["objective"].string ?? "Goal").lineLimit(1)
            Text(ActivityStatus.label(goal["status"].string ?? "")).foregroundStyle(MuseTheme.secondary)
            Spacer(minLength: 0)
            Button(goal["status"].string == "paused" ? "Resume" : "Pause") {
                store.sessionAction(goal["status"].string == "paused" ? "goal/resume" : "goal/pause", label: "Goal")
            }.disabled(!store.hasLoadedSession || (goal["status"].string == "paused" && !store.canRunGoal))
            Menu { Button("Clear goal…", role: .destructive) { clearingGoal = true } } label: { Image(systemName: "ellipsis") }.fixedSize()
        }.font(.system(size: 11)).padding(.horizontal, 24).frame(height: 34).background(MuseTheme.raised)
    }


    private var policyLabel: String {
        guard let mode = store.current?.approvalMode else { return "Uses your Muse permissions" }
        return ["promptUnmatched": "Ask for unmatched actions", "onRequest": "Approval on request", "denyUnmatched": "Deny unmatched actions", "allowAll": "Host policy: allow all"][mode] ?? "Host policy: \(mode)"
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle").padding(.top, 1)
            VStack(alignment: .leading, spacing: 8) {
                Text(message).textSelection(.enabled)
                if let details = store.errorDetails {
                    DisclosureGroup("Details") {
                        Text("Muse process diagnostics may contain configuration details. Kept in memory only.").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                        ScrollView {
                            Text(details).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(maxHeight: 160)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if store.engine == .failed { Button("Reconnect") { store.reconnect() }.buttonStyle(.borderless) }
            Button { store.errorMessage = nil } label: { Image(systemName: "xmark").font(.system(size: 11)) }
                .buttonStyle(.plain).accessibilityLabel("Dismiss error")
        }.font(.system(size: 12)).foregroundStyle(MuseTheme.error).padding(.horizontal, 20).padding(.vertical, 12).background(MuseTheme.error.opacity(0.06))
    }
}
