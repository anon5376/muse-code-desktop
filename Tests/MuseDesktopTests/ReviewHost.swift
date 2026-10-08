// Synthetic MSP host for permission presentation and native UI inspection.
// Never invokes Muse, a tool, a shell command or a model provider.
import Foundation

func frame(_ object: [String: Any]) {
    var bytes = try! JSONSerialization.data(withJSONObject: object); bytes.append(10)
    try! FileHandle.standardOutput.write(contentsOf: bytes)
}
func event(_ method: String, _ params: [String: Any]) { frame(["jsonrpc": "2.0", "method": method, "params": params]) }
if CommandLine.arguments.dropFirst().first == "skills" {
    frame(["skills": [["name": "Synthetic review", "invocationName": "synthetic-review", "source": "bundled", "description": "Offline verification fixture; no provider or tool runs.", "enabled": true]]]); exit(0)
}
if CommandLine.arguments.dropFirst().first == "plugins" { frame(["plugins": []]); exit(0) }
let sessionID = "review-fixture-session"
var receipts = 0, decisions = 0
var activeTurn = "fixture-turn"
let approval: [String: Any] = ["sessionId": sessionID, "approvalId": "fixture-approval", "itemId": "fixture-shell", "turnId": "fixture-turn",
    "toolName": "Shell", "taskId": "fixture-task", "toolCallId": "fixture-shell", "rawArgs": "{}", "judgeEscalated": false, "protectedWrite": false,
    "currentRequirementId": ["approvalId": "fixture-approval", "sourceIndex": 0], "viewCursor": "fixture:1", "sourceRange": ["first": 0, "last": 0],
    "subject": ["kind": "shell", "command": (1...40).map { "echo synthetic-line-\($0)" }.joined(separator: "\n"), "workingDirectory": "/synthetic-workspace"],
    "availableChoices": [["choiceId": "allow-once", "decision": "allow", "scope": "once", "label": "Allow once"],
        ["choiceId": "allow-session", "decision": "allow", "scope": "session", "label": "Allow in session", "rulePreview": "Shell commands in this synthetic session"],
        ["choiceId": "deny", "decision": "deny", "scope": "once", "label": "Deny"]]]
let question: [String: Any] = ["sessionId": sessionID, "userInputId": "fixture-question", "itemId": "fixture-question-item", "turnId": "fixture-turn", "viewCursor": "fixture:2",
    "questions": [["id": "target", "question": "Which synthetic target should the fixture use?", "selection": ["mode": "single"],
        "options": [["label": "macOS", "description": "Native desktop"], ["label": "Cancel", "description": "No work is performed"]]]]]
func present(_ method: String, _ params: [String: Any], id: String) { frame(["jsonrpc": "2.0", "method": method, "id": id, "params": params]) }
func complete() { event("turn/completed", ["sessionId": sessionID, "turnId": activeTurn, "terminal": "completed"]) }
while let line = readLine(), let bytes = line.data(using: .utf8), let request = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
    guard let id = request["id"] else { continue }
    guard let method = request["method"] as? String else {
        if (id as? String)?.hasPrefix("presentation-") == true, let result = request["result"] as? [String: Any], result.isEmpty { receipts += 1 }
        continue
    }
    let params = request["params"] as? [String: Any] ?? [:]
    var result: [String: Any] = [:]
    switch method {
    case "initialize": result = ["schema": ["version": 1, "fingerprint": "sha256:61afea3112e0906e9dc3a536144278a74cb4b36fc6e20901a91d4432ba3568e2"], "serverInfo": ["version": "synthetic-fixture"]]
    case "session/list": result = ["sessions": []]
    case "model/list": result = ["models": [["modelId": "synthetic-model", "providerId": "fixture", "isDefault": true, "isActive": params["sessionId"] != nil, "variants": ["high"]]], "source": "fakeCatalog"]
    case "skill/list": result = ["skills": [["selector": "synthetic-review", "displayName": "Synthetic review", "description": "An offline fixture skill; no provider or tool runs.", "enabled": true]]]
    case "session/start": result = ["session": ["sessionId": sessionID, "workspaceRoot": params["workspaceRoot"] ?? "", "modelId": "synthetic-model", "providerId": "fixture", "approvalMode": ["mode": "promptUnmatched"]]]
    case "fixture/present":
        present("approval/request", approval, id: "presentation-approval")
        present("userInput/request", question, id: "presentation-question")
    case "fixture/status": result = ["receipts": receipts, "decisions": decisions]
    case "turn/start":
        activeTurn = params["commandId"] as? String ?? "fixture-turn"
        result = ["status": "accepted", "turnId": activeTurn]
        event("turn/started", ["sessionId": sessionID, "turnId": activeTurn])
        let input = params["input"] as? [[String: Any]] ?? []
        let text = input.first?["text"] as? String ?? ""
        if text.contains("approval") { present("approval/request", approval, id: "presentation-approval") }
        else if text.contains("question") { present("userInput/request", question, id: "presentation-question") }
        else {
            event("item/completed", ["sessionId": sessionID, "item": ["itemId": "fixture-markdown", "kind": "agentMessage", "status": "completed", "revision": 1,
                "text": "## Native Markdown\n\nThis is **synthetic verification content**.\n\n- Headings and lists render natively.\n- Code remains selectable.\n\n> No model provider or tool was called.\n\n| Check | Result |\n| --- | --- |\n| Layout | Fixture |\n\n```swift\nlet platform = \"macOS\"\n```"]])
            complete()
        }
    case "approval/decide": decisions += 1; event("approval/resolved", ["sessionId": sessionID, "approvalId": "fixture-approval"]); complete(); result = ["status": "accepted"]
    case "userInput/answer": decisions += 1; event("userInput/settled", ["sessionId": sessionID, "userInputId": "fixture-question"]); complete(); result = ["status": "accepted"]
    case "goal/set":
        result = ["status": "accepted"]
        event("session/goalChanged", ["sessionId": sessionID, "goal": ["objective": params["objective"] ?? "Synthetic goal", "status": "paused"]])
    default: result = ["status": "accepted"]
    }
    frame(["jsonrpc": "2.0", "id": id, "result": result])
}
