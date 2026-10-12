// A protocol fixture for the model-change/first-turn ordering regression.
// Runs only from test-workspace.sh; never loads Muse or contacts a provider.
import Foundation

let outputLock = NSLock()
func writeFrame(_ value: [String: Any]) {
    outputLock.lock(); defer { outputLock.unlock() }
    var bytes = try! JSONSerialization.data(withJSONObject: value)
    bytes.append(10)
    try! FileHandle.standardOutput.write(contentsOf: bytes)
}
func event(_ method: String, _ params: [String: Any]) {
    writeFrame(["jsonrpc": "2.0", "method": method, "params": params])
}
var active = false
var sessionNumber = 0
var sessionID = "model-ordering-session-0"
var lastWorkspace = ""
var rejectedFirstSubmission = false
while let line = readLine(), let bytes = line.data(using: .utf8),
      let request = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
    guard let id = request["id"] else { continue }
    let method = request["method"] as? String ?? ""
    let params = request["params"] as? [String: Any] ?? [:]
    var result: [String: Any] = [:]
    switch method {
    case "initialize": result = ["schema": ["version": 1], "serverInfo": ["version": "test-fixture"]]
    case "session/list": result = ["sessions": []]
    case "skill/list": result = ["skills": []]
    case "model/list":
        if active { Thread.sleep(forTimeInterval: 0.08) }
        result = ["models": [["modelId": "fixture-model", "providerId": "fixture", "profileId": "personal", "variants": ["high"], "isDefault": true, "isActive": params["sessionId"] != nil]], "source": "fakeCatalog"]
    case "session/start":
        sessionNumber += 1; sessionID = "model-ordering-session-\(sessionNumber)"; active = true
        lastWorkspace = params["workspaceRoot"] as? String ?? ""
        result = ["session": ["sessionId": sessionID, "workspaceRoot": params["workspaceRoot"] ?? "", "modelId": "fixture-model", "providerId": "fixture"]]
    case "userInput/answer":
        result = ["status": "accepted"]
        event("userInput/settled", ["sessionId": params["sessionId"] ?? sessionID, "userInputId": params["userInputId"] ?? ""])
    case "approval/decide":
        result = ["status": "accepted"]
        event("approval/resolved", ["sessionId": params["sessionId"] ?? sessionID, "approvalId": params["approvalId"] ?? ""])
    case "session/resume":
        let target = params["sessionId"] as? String ?? ""
        if target == "buf-s" {
            // The event lands before the result so the store must buffer it.
            event("item/updated", ["sessionId": target, "item": ["itemId": "buf-1", "kind": "agentMessage", "status": "completed", "revision": 1, "text": "buffered item"]])
            let rid = id
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(150)) {
                writeFrame(["jsonrpc": "2.0", "id": rid, "result": ["session": ["sessionId": target], "history": ["items": []]]])
            }
            continue
        }
        result = [:]
    case "session/setModel":
        active = true
        event("session/modelChanged", ["sessionId": params["sessionId"] ?? sessionID, "modelId": "fixture-model", "providerId": "fixture"])
        result = ["status": "accepted"]
    case "turn/start":
        let input = params["input"] as? [[String: Any]] ?? []
        if (input.first?["text"] as? String) == "reject once then retry", !rejectedFirstSubmission {
            rejectedFirstSubmission = true
            writeFrame(["jsonrpc": "2.0", "id": id, "error": ["code": -32602, "message": "Synthetic first admission failure"]])
            continue
        }
        if (input.first?["text"] as? String)?.contains("explicit model") == true, params["reasoningEffort"] as? String != "high" {
            writeFrame(["jsonrpc": "2.0", "id": id, "error": ["code": -32602, "message": "First turn lost the requested reasoning effort"]])
            continue
        }
        let turnID = params["commandId"] as! String
        result = ["status": "accepted", "turnId": turnID]
        let target = params["sessionId"] as? String ?? sessionID
        if (input.first?["text"] as? String) == "delayed terminal failure" {
            event("turn/started", ["sessionId": target, "turnId": turnID])
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
                event("turn/completed", ["sessionId": target, "turnId": turnID, "terminal": "failed", "error": ["message": "Synthetic delayed failure"]])
            }
            writeFrame(["jsonrpc": "2.0", "id": id, "result": result])
            continue
        }
        if (input.first?["text"] as? String) == "pending question check" {
            event("userInput/requested", ["sessionId": target, "userInputId": "q-1",
                "question": ["id": "q", "selection": ["mode": "single"], "options": [["label": "A"], ["label": "B"]]]])
        }
        if (input.first?["text"] as? String) == "session list hygiene" {
            event("session/started", ["session": ["sessionId": "other-ws", "title": "Foreign", "workspaceRoot": "/nonexistent"]])
            event("session/started", ["session": ["sessionId": "extra-s", "title": "New session", "workspaceRoot": lastWorkspace]])
        }
        if (input.first?["text"] as? String) == "rename demo" {
            event("session/started", ["session": ["sessionId": "extra-r", "title": "Old", "workspaceRoot": lastWorkspace]])
            event("session/nameChanged", ["sessionId": "extra-r", "name": "Renamed"])
        }
        if (input.first?["text"] as? String) == "notification tail" {
            event("approval/requested", ["sessionId": target, "approvalId": "appr-t",
                "subject": ["kind": "shell", "command": "make x"]])
            event("approval/updated", ["sessionId": target, "approvalId": "appr-t", "note": "v2"])
            event("session/started", ["session": ["sessionId": "extra-s", "title": "Extra", "workspaceRoot": lastWorkspace]])
        }
        if (input.first?["text"] as? String) == "notload demo" {
            event("session/statusChanged", ["sessionId": target, "status": "notLoaded"])
        }
        if (input.first?["text"] as? String) == "lifecycle demo" {
            event("session/modelChanged", ["sessionId": target, "modelId": "fixture-model", "providerId": "fixture-provider"])
            event("session/goalChanged", ["sessionId": target, "goal": ["text": "fixture goal"]])
            event("session/approvalModeChanged", ["sessionId": target, "mode": "auto"])
        }
        if (input.first?["text"] as? String) == "gap demo" {
            event("view/gap", ["sessionId": target])
        }
        if (input.first?["text"] as? String) == "stream demo" {
            event("turn/started", ["sessionId": target, "turnId": turnID])
            event("item/started", ["sessionId": target, "item": ["itemId": "m-stream", "kind": "agentMessage", "status": "inProgress", "revision": 1]])
            event("item/delta", ["sessionId": target, "itemId": "m-stream", "delta": "Hello ", "viewCursor": "v1"])
            event("item/delta", ["sessionId": target, "itemId": "m-stream", "delta": "world", "viewCursor": "v2"])
            event("item/completed", ["sessionId": target, "item": ["itemId": "m-stream", "kind": "agentMessage", "status": "completed", "revision": 2, "text": "Hello world"]])
            event("session/tokenUsage", ["sessionId": target, "cumulative": ["totalTokens": 1234]])
            event("session/contextUsage", ["sessionId": target, "usedTokens": 55, "windowTokens": 200000])
        }
        if (input.first?["text"] as? String) == "pending both checks" {
            event("approval/requested", ["sessionId": target, "approvalId": "appr-m",
                "subject": ["kind": "shell", "command": "make check"]])
            event("userInput/requested", ["sessionId": target, "userInputId": "q-m",
                "question": ["id": "qm", "selection": ["mode": "single"], "options": [["label": "Y"], ["label": "N"]]]])
        }
        if (input.first?["text"] as? String) == "pending approval check" {
            event("approval/requested", ["sessionId": target, "approvalId": "appr-1", "currentRequirementId": "req-1",
                "subject": ["kind": "shell", "command": "ls -la"]])
        }
        event("item/completed", ["sessionId": params["sessionId"] ?? sessionID, "item": ["itemId": "confirmed-effort-" + turnID, "kind": "agentMessage", "status": "completed", "revision": 1, "text": "Requested reasoning: \(params["reasoningEffort"] as? String ?? "default")"]])
        event("turn/completed", ["sessionId": params["sessionId"] ?? sessionID, "turnId": turnID, "terminal": "completed", "durationMs": 321])
    default: break
    }
    writeFrame(["jsonrpc": "2.0", "id": id, "result": result])
}
