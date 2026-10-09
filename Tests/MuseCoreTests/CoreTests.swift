// MuseCoreTests: protocol-layer checks — framing, transcript folding,
// request contracts, markdown splitting, history decoding — plus an
// integration tail driven against the synthetic ReviewHost fixture.
// Pure checks are registered in the `tests:` array (an unregistered test
// never runs); each prints PASS/FAIL and the run fails on any FAIL.
import Foundation
import MuseCore
import Darwin

@main
enum CoreTests {
    struct Failure: Error, CustomStringConvertible { let description: String }
    static func equal<T: Equatable>(_ actual: T, _ expected: T, file: String = #fileID, line: Int = #line) throws {
        guard actual == expected else { throw Failure(description: "\(file):\(line): expected \(expected), got \(actual)") }
    }
    static func throwsError(_ work: () throws -> Void) throws {
        do { try work() } catch { return }
        throw Failure(description: "Expected an oversized-frame error")
    }
    static func main() async {
        let tests: [(String, () throws -> Void)] = [
            ("framing preserves split Unicode and separates messages", testFramingPreservesSplitUnicodeAndSeparatesMessages),
            ("frame limit applies to terminated and unterminated frames", testFrameLimitAppliesPerFrameIncludingUnterminatedInput),
            ("framing normalizes CRLF splits and drops empty frames", testFramingEdgeCases),
            ("final revisions replace deltas and resist replay", testStreamingFoldReplacesFinalRevisionAndIgnoresReplayedInput),
            ("tool output and unknown terminal items remain readable", testToolOutputAndUnknownTerminalItemsRemainReadable),
            ("question answers obey the host's exclusive variants and bounds", testQuestionAnswerContract),
            ("question answers enforce counts, ids, and text limits", testQuestionAnswerEdges),
            ("permission summaries expose network targets and file access", testApprovalSubjectDisclosure),
            ("unavailable resume history cannot become a healthy empty transcript", testUnavailableHistory),
            ("transcript ignores deltas for unknown or inactive items", testTranscriptDeltaEdges),
            ("history decoding rejects wrong versions and missing payloads", testHistoryDecodeEdges),
            ("Markdown renders structural blocks and preserves code fences", testMarkdownBlocks),
            ("streaming Markdown keeps completed blocks stable", testStreamingMarkdown),
            ("JSONValue accessors stay total and bounds-checked", testJSONValueAccessors),
            ("status labels map known wires and humanize unknown camelCase", testActivityStatusLabels),
            ("Markdown edges: tilde fences, indents, quotes, rules", testMarkdownEdges)
        ]
        var failures = 0
        for (name, test) in tests {
            do { try test(); print("PASS \(name)") }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        var integrationCount = 1
        do {
            try await testHostExitFailsPendingHandshake()
            print("PASS host exit fails a pending handshake promptly")
        } catch { failures += 1; print("FAIL host exit with pending handshake: \(error)") }
        integrationCount += 1
        do {
            try await testStderrDetails()
            print("PASS host failure retains bounded in-memory diagnostic details")
        } catch { failures += 1; print("FAIL host diagnostic details: \(error)") }
        integrationCount += 1
        do {
            try await testShutdownDoesNotWaitForInheritedOutput()
            print("PASS shutdown does not wait for a descendant holding output pipes")
        } catch { failures += 1; print("FAIL shutdown with inherited output pipes: \(error)") }
        if let index = CommandLine.arguments.firstIndex(of: "--review-host"), index + 1 < CommandLine.arguments.count {
            integrationCount += 1
            do {
                try await testPresentationReceipt(executable: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                print("PASS presentation receipts send no implicit approval or answer")
            } catch { failures += 1; print("FAIL presentation receipt contract: \(error)") }
        }
        if let executable = MuseExecutable.locate() {
            integrationCount += 1
            do {
                let report = try await EchoDiagnostic.run(executable: executable)
                try equal(report.reply, "echo: muse-native-round-trip ✓")
                print("PASS real Muse echo host round trip (\(report.elapsedMilliseconds) ms)")
            } catch { failures += 1; print("FAIL real Muse echo host round trip: \(error.localizedDescription)") }
        } else { print("SKIP real Muse host: no installed muse executable") }
        print("\(tests.count + integrationCount - failures)/\(tests.count + integrationCount) tests passed")
        if failures > 0 { exit(1) }
    }

    // A real child that exits without replying must fail the waiting request,
    // rather than leaving the app stuck until the initialize timeout expires.
    static func testHostExitFailsPendingHandshake() async throws {
        let connection = MuseConnection(onEvents: { _ in })
        let started = Date()
        do {
            _ = try await connection.start(MuseLaunchConfiguration(
                executable: URL(fileURLWithPath: "/bin/sleep"),
                workspace: FileManager.default.temporaryDirectory,
                arguments: ["0.1"]
            ))
            throw Failure(description: "An exited child unexpectedly completed initialize")
        } catch ConnectionFailure.hostExit(0) {
            guard Date().timeIntervalSince(started) < 3 else {
                throw Failure(description: "Host exit did not fail initialize promptly")
            }
        }
        await connection.shutdown()
    }

    static func testStderrDetails() async throws {
        let connection = MuseConnection(onEvents: { _ in })
        defer { connection.stop() }
        do {
            _ = try await connection.start(MuseLaunchConfiguration(executable: URL(fileURLWithPath: "/bin/sh"), workspace: FileManager.default.temporaryDirectory,
                arguments: ["-c", "/usr/bin/awk 'BEGIN {for (i=0;i<12000;i++)printf \"x\"; print \"synthetic sign-in expired\"}' >&2; exit 7"]))
        } catch ConnectionFailure.hostExit(7) { }
        let details = await connection.diagnosticDetails()
        try equal(details?.contains("synthetic sign-in expired"), true)
        try equal((details?.utf8.count ?? 0) <= 8_192, true)
        await connection.shutdown()
    }

    static func testPresentationReceipt(executable: URL) async throws {
        let connection = MuseConnection(onEvents: { _ in })
        defer { connection.stop() }
        _ = try await connection.start(MuseLaunchConfiguration(executable: executable, workspace: FileManager.default.temporaryDirectory, arguments: []))
        _ = try await connection.request("fixture/present")
        let status = try await connection.request("fixture/status")
        try equal(status["receipts"].int, 2)
        try equal(status["decisions"].int, 0)
        _ = try await connection.request("approval/decide", ["commandId": .string(CommandID.make()), "sessionId": .string("review-fixture-session"),
            "approvalId": .string("fixture-approval"), "choiceId": .string("deny"), "requirementId": .object(["approvalId": .string("fixture-approval"), "sourceIndex": .number(0)])])
        try equal(try await connection.request("fixture/status")["decisions"].int, 1)
        await connection.shutdown()
    }

    // The host completes initialize and exits, while its own short-lived
    // descendant retains stdout/stderr. App shutdown must follow host lifetime.
    static func testShutdownDoesNotWaitForInheritedOutput() async throws {
        let connection = MuseConnection(onEvents: { _ in })
        let script = #"""
        IFS= read -r request
        request_id=$(printf '%s' "$request" | /usr/bin/sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
        printf '{"jsonrpc":"2.0","id":"%s","result":{"schema":{"version":1}}}\n' "$request_id"
        /bin/sleep 4 &
        exit 0
        """#
        _ = try await connection.start(MuseLaunchConfiguration(
            executable: URL(fileURLWithPath: "/bin/sh"),
            workspace: FileManager.default.temporaryDirectory,
            arguments: ["-c", script]
        ))
        try await Task.sleep(for: .milliseconds(300))
        let started = Date()
        await connection.shutdown()
        guard Date().timeIntervalSince(started) < 1.5 else {
            throw Failure(description: "Shutdown followed the descendant's pipe lifetime instead of host exit")
        }
    }
    // A pipe read may split a Unicode scalar, or contain several JSON frames.
    // Decoding each read as text would corrupt this actual transport input.
    static func testFramingPreservesSplitUnicodeAndSeparatesMessages() throws {
        var framer = LineFramer()
        let wire = Data("{\"text\":\"привет 👋\"}\n{\"id\":2}\r\n".utf8)
        let split = wire.firstIndex(of: 0xF0)! + 2
        try equal(try framer.append(wire.prefix(split)).isEmpty, true)
        let frames = try framer.append(wire.suffix(from: split))
        try equal(frames.count, 2)
        try equal(try frames.map { try JSONDecoder().decode(JSONValue.self, from: $0) }, [
            .object(["text": .string("привет 👋")]), .object(["id": .number(2)])
        ])
    }

    // A \r at the end of one chunk followed by \n at the start of the next
    // is still one line ending; empty frames carry no messages.
    static func testFramingEdgeCases() throws {
        var framer = LineFramer()
        try equal(try framer.append(Data("alpha\r".utf8)), [])
        try equal(try framer.append(Data("\n\n\nbeta\n".utf8)), [Data("alpha".utf8), Data("beta".utf8)])
        // A frame of exactly maximumFrameBytes is accepted.
        var bounded = LineFramer(maximumFrameBytes: 3)
        try equal(try bounded.append(Data("abc\n".utf8)), [Data("abc".utf8)])
        try throwsError { _ = try bounded.append(Data("abcd\n".utf8)) }
    }

    // An unterminated or oversized frame must not grow memory without a bound.
    // Several small frames in one chunk are valid even if the chunk is larger.
    static func testFrameLimitAppliesPerFrameIncludingUnterminatedInput() throws {
        var framer = LineFramer(maximumFrameBytes: 5)
        try equal(try framer.append(Data("12345\n12345\n".utf8)).count, 2)
        try throwsError { _ = try framer.append(Data("123456".utf8)) }
        var terminated = LineFramer(maximumFrameBytes: 5)
        try throwsError { _ = try terminated.append(Data("123456\n".utf8)) }
    }

    // Final revisions are authoritative. Replaying an old item or duplicate
    // delta must never duplicate text or replace the final answer with a prefix.
    static func testStreamingFoldReplacesFinalRevisionAndIgnoresReplayedInput() throws {
        var transcript = Transcript()
        transcript.apply(try frame("item/started", #"{"item":{"itemId":"a","kind":"agentMessage","revision":1,"status":"inProgress","text":""}}"#))
        let delta = try frame("item/delta", #"{"itemId":"a","viewCursor":"opaque:1","delta":"Hel","field":"text"}"#)
        transcript.apply(delta)
        transcript.apply(delta)
        try equal(transcript.items.first?.text, "Hel")
        transcript.apply(try frame("item/completed", #"{"item":{"itemId":"a","kind":"agentMessage","revision":2,"status":"completed","text":"Hello"}}"#))
        transcript.apply(try frame("item/updated", #"{"item":{"itemId":"a","kind":"agentMessage","revision":1,"status":"inProgress","text":"old"}}"#))
        transcript.apply(try frame("item/delta", #"{"itemId":"a","viewCursor":"opaque:2","delta":"late"}"#))
        try equal(transcript.items.count, 1)
        try equal(transcript.items.first?.text, "Hello")
        try equal(transcript.items.first?.status, "completed")
    }

    // Tool-output deltas have a different destination from message text;
    // future kinds and terminal statuses must retain a readable fallback.
    static func testToolOutputAndUnknownTerminalItemsRemainReadable() throws {
        var transcript = Transcript()
        transcript.apply(try frame("item/started", #"{"item":{"itemId":"t","kind":"toolCall","revision":1,"status":"inProgress","text":"run tests","visibleOutput":""}}"#))
        transcript.apply(try frame("item/delta", #"{"itemId":"t","delta":"4 tests passed","field":"output"}"#))
        transcript.apply(try frame("item/delta", #"{"itemId":"t","delta":"ignored","field":"futureField"}"#))
        try equal(transcript.items.first?.text, "run tests")
        try equal(transcript.items.first?.output, "4 tests passed")
        transcript.apply(try frame("item/completed", #"{"item":{"itemId":"x","kind":"futureKind","revision":1,"status":"futureTerminal","fallbackText":"New host activity"}}"#))
        try equal(transcript.items.last?.text, "New host activity")
        try equal(transcript.items.last?.isActive, false)
    }

    // Deltas target live items only: an unstarted itemId, a completed item,
    // and unknown fields/methods are ignored — never resurrected or appended.
    static func testTranscriptDeltaEdges() throws {
        var transcript = Transcript()
        try equal(transcript.apply(try frame("item/delta", #"{"itemId":"ghost","delta":"x","field":"text"}"#)), false)
        try equal(transcript.items.isEmpty, true)
        try equal(transcript.apply(try frame("session/updated", #"{"sessionId":"s"}"#)), false)
        try equal(transcript.apply(try frame("item/started", #"{"item":{"itemId":"a","kind":"agentMessage","revision":1,"status":"inProgress","text":""}}"#)), true)
        // A delta to an unknown field is dropped; a missing field defaults to text.
        try equal(transcript.apply(try frame("item/delta", #"{"itemId":"a","delta":"bad","field":"futureField"}"#)), false)
        try equal(transcript.apply(try frame("item/delta", #"{"itemId":"a","delta":"Hel"}"#)), true)
        try equal(transcript.items.first?.text, "Hel")
        // Completing the item clears its delta cursors, so a later turn may
        // legitimately reuse viewCursors — but deltas still need an active item.
        try equal(transcript.apply(try frame("item/completed", #"{"item":{"itemId":"a","kind":"agentMessage","revision":2,"status":"completed","text":"Hello"}}"#)), true)
        try equal(transcript.apply(try frame("item/delta", #"{"itemId":"a","delta":"late","field":"text"}"#)), false)
        try equal(transcript.items.first?.text, "Hello")
        // Equal-revision updates are ignored; only strictly newer revisions upsert.
        try equal(transcript.apply(try frame("item/updated", #"{"item":{"itemId":"a","kind":"agentMessage","revision":2,"status":"failed","text":"stale"}}"#)), false)
        try equal(transcript.items.first?.status, "completed")
    }

    private static func frame(_ method: String, _ params: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data("{\"method\":\"\(method)\",\"params\":\(params)}".utf8))
    }

    static func testQuestionAnswerContract() throws {
        let single: JSONValue = .object(["id": .string("q"), "selection": .object(["mode": .string("single")]),
            "options": .array([.object(["label": .string("A")]), .object(["label": .string("B")])])])
        var multiple = single.object
        multiple["selection"] = .object(["mode": .string("multiple"), "minSelections": .number(1), "maxSelections": .number(2)])
        try equal(UserInputAnswer.make(question: single, selections: ["A"], freeText: " my answer "),
            .object(["questionId": .string("q"), "freeText": .string("my answer")]))
        try equal(UserInputAnswer.make(question: .object(multiple), selections: [], freeText: "Other"),
            .object(["questionId": .string("q"), "freeText": .string("Other")]))
        try equal(UserInputAnswer.make(question: single, selections: ["A"], freeText: ""),
            .object(["questionId": .string("q"), "selectedLabel": .string("A")]))
        try equal(UserInputAnswer.make(question: .object(multiple), selections: ["A", "B"], freeText: ""),
            .object(["questionId": .string("q"), "selectedLabels": .array([.string("A"), .string("B")])]))
        try equal(UserInputAnswer.make(question: single, selections: [], freeText: String(repeating: "x", count: 501)), nil)
        try equal(UserInputAnswer.make(question: single, selections: ["unknown"], freeText: ""), nil)
        try equal(UserInputAnswer.make(question: .object(multiple), selections: [], freeText: ""), nil)
    }

    static func testQuestionAnswerEdges() throws {
        let single: JSONValue = .object(["id": .string("q"), "selection": .object(["mode": .string("single")]),
            "options": .array([.object(["label": .string("A")]), .object(["label": .string("B")])])])
        // Exactly 500 scalars of free text is the accepted bound.
        try equal(UserInputAnswer.make(question: single, selections: [], freeText: String(repeating: "x", count: 500)) != nil, true)
        // Single-choice mode rejects two selections.
        try equal(UserInputAnswer.make(question: single, selections: ["A", "B"], freeText: ""), nil)
        // Multiple mode enforces minSelections.
        let minimum: JSONValue = .object(["id": .string("q"), "selection": .object(["mode": .string("multiple"), "minSelections": .number(2)]),
            "options": .array([.object(["label": .string("A")]), .object(["label": .string("B")]), .object(["label": .string("C")])])])
        try equal(UserInputAnswer.make(question: minimum, selections: ["A"], freeText: ""), nil)
        try equal(UserInputAnswer.make(question: minimum, selections: ["A", "C"], freeText: "") != nil, true)
        // A valid label mixed with an invented one is rejected wholesale.
        try equal(UserInputAnswer.make(question: single, selections: ["A", "invented"], freeText: ""), nil)
        // Missing or empty question id cannot be answered.
        try equal(UserInputAnswer.make(question: .object(["selection": single["selection"], "options": single["options"]]), selections: ["A"], freeText: ""), nil)
    }

    static func testApprovalSubjectDisclosure() throws {
        let network: JSONValue = .object(["toolName": .string("fetch"), "subject": .object([
            "kind": .string("network"), "host": .string("example.test"), "port": .number(8443), "protocol": .string("https")])])
        try equal(ApprovalDescription.summary(network), "https://example.test:8443")
        let file: JSONValue = .object(["subject": .object(["kind": .string("fileAccess"), "path": .string("/project/config"), "access": .string("write")])])
        try equal(ApprovalDescription.summary(file), "write: /project/config")
        let command = (1...12).map { "echo line \($0)" }.joined(separator: "\n")
        try equal(ApprovalDescription.summary(.object(["subject": .object(["kind": .string("shell"), "command": .string(command)])])), command)
        let future: JSONValue = .object(["subject": .object(["kind": .string("future"), "destination": .string("somewhere")])])
        guard ApprovalDescription.summary(future).contains("somewhere") else { throw Failure(description: "Unknown permission subject was hidden") }
    }

    static func testUnavailableHistory() throws {
        for reason in ["projectionUnavailable", "projectionReadLimit", "historyBudget", "futureReason"] {
            do {
                _ = try SessionHistory.items(.object(["mode": .string("none"), "noneReason": .string(reason), "items": .null, "snapshot": .null]))
            } catch { continue }
            throw Failure(description: "Unavailable history \(reason) was accepted as an empty transcript")
        }
        let item: JSONValue = .object(["itemId": .string("retained"), "text": .string("Previous answer")])
        try equal(try SessionHistory.items(.object(["mode": .string("inline"), "items": .array([item])])), [item])
        try equal(try SessionHistory.items(.object(["mode": .string("snapshot"), "snapshot": .object([
            "schemaVersion": .number(1), "state": .object(["items": .array([item])])])])), [item])
    }

    static func testHistoryDecodeEdges() throws {
        // mode=none wins even when items are present — the host's explicit
        // unavailability must not degrade to a partial transcript.
        do {
            _ = try SessionHistory.items(.object(["mode": .string("none"), "noneReason": .string("budget"),
                "items": .array([.object(["itemId": .string("x")])])]))
            throw Failure(description: "mode=none history with items was accepted")
        } catch let error as ConnectionFailure { _ = error }
        // Snapshot requires schemaVersion 1.
        do {
            _ = try SessionHistory.items(.object(["snapshot": .object(["schemaVersion": .number(2),
                "state": .object(["items": .array([])])])]))
            throw Failure(description: "snapshot schemaVersion 2 was accepted")
        } catch let error as ConnectionFailure { _ = error }
        // Neither items nor snapshot → explicit protocol error, not [].
        do {
            _ = try SessionHistory.items(.object(["mode": .string("inline")]))
            throw Failure(description: "history with no payload was accepted")
        } catch let error as ConnectionFailure { _ = error }
    }

    static func testMarkdownBlocks() throws {
        let text = "# Plan\n\n- First **task**\n2. Second task\n\n> A quoted note\n\n| File | Status |\n| --- | --- |\n| `a.swift` | Ready |\n\n```swift\nprint(\"hello\")\n```\n\n---"
        try equal(MarkdownBlocks.parse(text), [
            .heading(level: 1, text: "Plan"), .listItem(marker: "•", text: "First **task**", indent: 0),
            .listItem(marker: "2.", text: "Second task", indent: 0), .quote("A quoted note"),
            .table(headers: ["File", "Status"], rows: [["`a.swift`", "Ready"]]),
            .code(language: "swift", text: "print(\"hello\")"), .rule
        ])
        try equal(MarkdownBlocks.parse("````text\n``` is content\n````"), [.code(language: "text", text: "``` is content")])
    }

    static func testMarkdownEdges() throws {
        // Headings require a space after # and levels 1...6 only.
        try equal(MarkdownBlocks.parse("#tag"), [.paragraph("#tag")])
        try equal(MarkdownBlocks.parse("####### too deep"), [.paragraph("####### too deep")])
        try equal(MarkdownBlocks.parse("###### six"), [.heading(level: 6, text: "six")])
        // Tilde fences are fences too.
        try equal(MarkdownBlocks.parse("~~~txt\nbody\n~~~"), [.code(language: "txt", text: "body")])
        // A fence never closed still yields its code (truncation must not drop it).
        try equal(MarkdownBlocks.parse("```\nunfinished"), [.code(language: "", text: "unfinished")])
        // List markers: unordered normalize to •, ordered keep their ordinal, indent by 2-space units.
        try equal(MarkdownBlocks.parse("  - nested\n* star\n3) paren"), [
            .listItem(marker: "•", text: "nested", indent: 1),
            .listItem(marker: "•", text: "star", indent: 0),
            .listItem(marker: "3)", text: "paren", indent: 0)])
        // Consecutive > lines join into one quote; spaceless and spaced rules both rule.
        try equal(MarkdownBlocks.parse("> a\n> b"), [.quote("a\nb")])
        try equal(MarkdownBlocks.parse("- - -\n***\n___"), [.rule, .rule, .rule])
        // A divider-less pipe line is a paragraph, not a table.
        try equal(MarkdownBlocks.parse("a | b\nno divider"), [.paragraph("a | b\nno divider")])
        // Consecutive plain lines join into one paragraph.
        try equal(MarkdownBlocks.parse("line one\nline two\n\nnext"), [.paragraph("line one\nline two"), .paragraph("next")])
        try equal(MarkdownBlocks.parse(""), [])
    }

    static func testActivityStatusLabels() throws {
        // Every wire status in the map has a stable human label.
        try equal(ActivityStatus.label("inProgress"), "Running")
        try equal(ActivityStatus.label("completed"), "Done")
        try equal(ActivityStatus.label("failed"), "Failed")
        // The three stop spellings the host has emitted all fold to "Stopped".
        try equal(ActivityStatus.label("interrupted"), "Stopped")
        try equal(ActivityStatus.label("cancelled"), "Stopped")
        try equal(ActivityStatus.label("canceled"), "Stopped")
        try equal(ActivityStatus.label("notLoaded"), "Not loaded")
        // Unknown camelCase still renders readably instead of raw wire text.
        try equal(ActivityStatus.label("inReviewMode"), "In Review Mode")
        try equal(ActivityStatus.label("paused"), "Paused")
    }

    static func testJSONValueAccessors() throws {
        // Subscripting a non-object and missing keys both stay `.null` —
        // chained lookups on hostile payloads must never crash.
        try equal(JSONValue.string("x")["key"], .null)
        try equal(JSONValue.object(["a": .string("b")])["a"], .string("b"))
        try equal(JSONValue.object(["a": .string("b")])["missing"], .null)
        // Mismatched-type accessors yield nil or the empty collection.
        try equal(JSONValue.number(1).string, nil)
        try equal(JSONValue.string("x").bool, nil)
        try equal(JSONValue.string("x").array, [])
        try equal(JSONValue.array([]).object, [:])
        // `int` accepts finite in-range numbers and truncates fractions,
        // rejects NaN/inf and values outside Int's range.
        try equal(JSONValue.number(2.9).int, 2)
        try equal(JSONValue.number(-7).int, -7)
        try equal(JSONValue.number(.nan).int, nil)
        try equal(JSONValue.number(.infinity).int, nil)
        try equal(JSONValue.number(1e30).int, nil)
        try equal(JSONValue.number(-1e30).int, nil)
        try equal(JSONValue.bool(true).bool, true)
        try equal(JSONValue.null.bool, nil)
    }

    static func testStreamingMarkdown() throws {
        let prefix = "## Finished heading\n\nParagraph finished.\n\n"
        let stable = MarkdownBlocks.parse(prefix)
        let streaming = MarkdownBlocks.parse(prefix + "Partial **mar", isStreaming: true)
        try equal(Array(streaming.dropLast()), stable)
        try equal(streaming.last, .partial("Partial **mar"))
        try equal(MarkdownBlocks.parse("## Finished heading\n\n```swift\nlet x", isStreaming: true).first, .heading(level: 2, text: "Finished heading"))
    }
}
