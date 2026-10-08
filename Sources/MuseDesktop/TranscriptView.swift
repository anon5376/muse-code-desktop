import SwiftUI
import AppKit
import MuseCore

struct TranscriptView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var followOutput = true

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    // Lazy row measurement loops when a rich reply is compressed by the request dock.
                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(store.current?.transcript.items ?? []) { item in
                            TranscriptRow(item: item).equatable()
                        }
                        if store.isRunning {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.mini)
                                Text(store.current?.approvals.isEmpty == false || store.current?.questions.isEmpty == false ? "Waiting for you" : "Muse is working…")
                                    .font(.system(size: 12)).foregroundStyle(MuseTheme.secondary)
                            }.padding(.vertical, 4)
                        }
                        Color.clear.frame(height: 1).id("transcript-bottom")
                    }.frame(maxWidth: 720, alignment: .leading).padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                }
                HStack {
                    Spacer()
                    Toggle("Follow output", isOn: $followOutput).toggleStyle(.checkbox)
                        .font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
                }.padding(.horizontal, 28).padding(.bottom, 10)
            }
            .onAppear { proxy.scrollTo("transcript-bottom", anchor: .bottom) }
            .onChange(of: store.eventRevision) { _, _ in if followOutput { proxy.scrollTo("transcript-bottom", anchor: .bottom) } }
            .onChange(of: store.selectedID) { _, _ in followOutput = true; proxy.scrollTo("transcript-bottom", anchor: .bottom) }
            .onChange(of: followOutput) { _, follow in if follow { proxy.scrollTo("transcript-bottom", anchor: .bottom) } }
        }
    }
}

struct TranscriptRow: View, Equatable {
    let item: TranscriptItem
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.item == rhs.item }
    var body: some View {
        switch item.kind {
        case "userMessage":
            HStack {
                Spacer(minLength: 32)
                Text(item.text).font(.system(size: 14)).lineSpacing(7).textSelection(.enabled)
                    .padding(16).background(MuseTheme.raised, in: RoundedRectangle(cornerRadius: 10))
            }.frame(maxWidth: .infinity, alignment: .trailing)
        case "agentMessage":
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    MuseMark(size: 15)
                    Text("Muse").font(.system(size: 12, weight: .medium))
                    Spacer()
                    if !item.isActive, !item.text.isEmpty {
                        Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.text, forType: .string) } label: {
                            Image(systemName: "doc.on.doc").font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
                        }.buttonStyle(.plain).help("Copy message").accessibilityLabel("Copy Muse's message")
                    }
                }
                if item.text.isEmpty && item.isActive { Text("Thinking…").font(.system(size: 14)).foregroundStyle(MuseTheme.secondary) }
                else { MarkdownBody(text: item.text, isStreaming: item.isActive) }
                if item.raw["retracted"].bool == true { Text("Retracted").font(.system(size: 11)).foregroundStyle(MuseTheme.muted) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        case "reasoning":
            DisclosureGroup {
                Text(item.text).font(.system(size: 12)).foregroundStyle(MuseTheme.secondary).textSelection(.enabled).padding(.top, 8)
            } label: {
                HStack { Image(systemName: "ellipsis.bubble"); Text("Reasoning"); if item.isActive { Text("· in progress") } }
                    .font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
            }.tint(MuseTheme.muted)
        default:
            ActivityRow(item: item)
        }
    }
}

struct ActivityRow: View {
    let item: TranscriptItem
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { expanded.toggle() } label: {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 11)).frame(width: 10)
                    Image(systemName: statusSymbol).foregroundStyle(statusColor).font(.system(size: 11))
                    Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.statusLabel).font(.system(size: 11)).foregroundStyle(statusColor)
                    if let duration = item.raw["durationMs"].int { Text(String(format: "%.1fs", Double(duration) / 1_000)).font(.system(size: 11)).monospacedDigit() }
                }.foregroundStyle(MuseTheme.secondary).padding(.vertical, 9).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(title), \(item.status), \(expanded ? "collapse" : "expand")")
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let args = item.raw["args"].string, !args.isEmpty {
                        Text(String(args.prefix(20_000))).font(.system(size: 11, design: .monospaced)).foregroundStyle(MuseTheme.secondary).textSelection(.enabled)
                    }
                    if !details.isEmpty {
                        ScrollView([.vertical, .horizontal]) {
                            Text(String(details.prefix(20_000))).font(.system(size: 11, design: .monospaced)).lineSpacing(3)
                                .foregroundStyle(MuseTheme.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(maxHeight: 240)
                        if details.count > 20_000 { Text("Showing the first 20,000 characters.").font(.system(size: 11)).foregroundStyle(MuseTheme.muted) }
                    } else { Text("No inline output was provided by Muse.").font(.system(size: 11)).foregroundStyle(MuseTheme.muted) }
                }.padding(.leading, 29).padding(.top, 5).padding(.bottom, 12)
            }
        }.overlay(alignment: .bottom) { Hairline() }
    }
    private var title: String {
        if item.kind == "toolCall" || item.kind == "userShell" { return item.tool }
        return item.text.isEmpty ? item.kind : String(item.text.prefix(100))
    }
    private var details: String { item.raw["failureReason"].string ?? item.raw["message"].string ?? (item.output.isEmpty ? item.text : item.output) }
    private var statusColor: Color { item.status == "failed" ? MuseTheme.error : item.isActive ? MuseTheme.accent : MuseTheme.muted }
    private var statusSymbol: String { item.status == "failed" ? "exclamationmark.circle" : item.isActive ? "circle.dotted" : item.status == "completed" ? "checkmark" : "minus.circle" }
}

struct ApprovalCard: View {
    let request: JSONValue
    @ObservedObject var store: WorkspaceStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(request["subject"]["kind"].string == "shell" ? "Allow Muse to run this command?" : "Muse needs permission", systemImage: "hand.raised").font(.system(size: 13, weight: .medium)).foregroundStyle(MuseTheme.attention)
            if request["protectedWrite"].bool == true { Text("Protected write").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary) }
            if let directory = request["subject"]["workingDirectory"].string ?? request["cwd"].string {
                Text(directory).font(.system(size: 11, design: .monospaced)).foregroundStyle(MuseTheme.secondary).textSelection(.enabled)
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ApprovalDescription.summary(request))
                        .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DisclosureGroup("Complete permission details") {
                        Text(request["subject"].prettyPrinted).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.system(size: 11)).foregroundStyle(MuseTheme.secondary)
                }
            }.frame(maxHeight: 112)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { choices }
                VStack(alignment: .leading, spacing: 8) { choices }
            }.fixedSize(horizontal: false, vertical: true)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).focusSection()
            .background(MuseTheme.popover, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(MuseTheme.attention).frame(width: 3).padding(.vertical, 8) }
    }
    private var choices: some View {
        ForEach(Array(request["availableChoices"].array.enumerated()), id: \.offset) { _, choice in
            VStack(alignment: .leading, spacing: 4) {
                if choice["decision"].string == "allow", choice["scope"].string == "once" {
                    decisionButton(choice).buttonStyle(.borderedProminent).tint(MuseTheme.controlAccent)
                } else { decisionButton(choice).buttonStyle(.bordered).tint(choice["decision"].string == "deny" ? MuseTheme.error : MuseTheme.accent) }
                if let preview = choice["rulePreview"].string, !preview.isEmpty {
                    Text(preview).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }.disabled(store.deciding.contains(request["approvalId"].string ?? "") || store.engine != .ready)
        }
    }
    private func decisionButton(_ choice: JSONValue) -> some View {
        Button(role: choice["decision"].string == "deny" ? .destructive : nil) { store.decide(request, choice: choice) } label: {
            Text(choice["label"].string ?? choice["choiceId"].string ?? "Choose").font(.system(size: 12))
        }.controlSize(.small)
    }
}

struct QuestionCard: View {
    let request: JSONValue
    @ObservedObject var store: WorkspaceStore
    @State private var selections: [String: Set<String>] = [:]
    @State private var freeText: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Muse has a question", systemImage: "bubble.left.and.bubble.right").font(.system(size: 13, weight: .medium)).foregroundStyle(MuseTheme.attention)
            ScrollView {
              VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(request["questions"].array.enumerated()), id: \.offset) { _, question in
                let id = question["id"].string ?? ""
                VStack(alignment: .leading, spacing: 10) {
                    Text(question["question"].string ?? "").font(.system(size: 13, weight: .medium)).textSelection(.enabled)
                    ForEach(Array(question["options"].array.enumerated()), id: \.offset) { _, option in
                        let label = option["label"].string ?? ""
                        let selected = selections[id, default: []].contains(label)
                        Button { select(label, for: question) } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: question["selection"]["mode"].string == "multiple" ? (selected ? "checkmark.square.fill" : "square") : (selected ? "largecircle.fill.circle" : "circle")).foregroundStyle(selected ? MuseTheme.accent : MuseTheme.muted)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(label).font(.system(size: 12))
                                    if let detail = option["description"].string { Text(detail).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary) }
                                }
                                Spacer(minLength: 0)
                            }.padding(.vertical, 5).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("\(label), \(selected ? "selected" : "not selected")")
                    }
                    TextField("Write your own answer…", text: Binding(get: { freeText[id] ?? "" }, set: {
                        freeText[id] = $0
                        if !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { selections[id] = [] }
                    }))
                        .textFieldStyle(.roundedBorder).font(.system(size: 12))
                    if (freeText[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count > 500 {
                        Text("Use 500 characters or fewer.").font(.system(size: 11)).foregroundStyle(MuseTheme.error)
                    }
                }
                }
              }
            }.frame(maxHeight: 160)
            Button("Send answers") { store.answer(request, answers: answers) }
                .buttonStyle(.borderedProminent).tint(MuseTheme.controlAccent).controlSize(.small)
                .disabled(!valid || store.engine != .ready || store.deciding.contains(request["userInputId"].string ?? ""))
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(MuseTheme.raised, in: RoundedRectangle(cornerRadius: 12))
    }

    private func select(_ label: String, for question: JSONValue) {
        let id = question["id"].string ?? ""
        freeText[id] = ""
        if question["selection"]["mode"].string == "multiple" {
            if selections[id, default: []].contains(label) { selections[id]?.remove(label) }
            else if selections[id, default: []].count < (question["selection"]["maxSelections"].int ?? Int.max) { selections[id, default: []].insert(label) }
        } else { selections[id] = selections[id, default: []].contains(label) ? [] : [label] }
    }
    private var valid: Bool {
        !request["questions"].array.isEmpty && answers.count == request["questions"].array.count
    }
    private var answers: [JSONValue] {
        request["questions"].array.compactMap { question in
            let id = question["id"].string ?? ""
            return UserInputAnswer.make(question: question, selections: selections[id, default: []].sorted(), freeText: freeText[id] ?? "")
        }
    }
}
