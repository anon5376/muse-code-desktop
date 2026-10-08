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
        result = ["session": ["sessionId": sessionID, "workspaceRoot": params["workspaceRoot"] ?? "", "modelId": "fixture-model", "providerId": "fixture"]]
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
        event("item/completed", ["sessionId": params["sessionId"] ?? sessionID, "item": ["itemId": "confirmed-effort-" + turnID, "kind": "agentMessage", "status": "completed", "revision": 1, "text": "Requested reasoning: \(params["reasoningEffort"] as? String ?? "default")"]])
        event("turn/completed", ["sessionId": params["sessionId"] ?? sessionID, "turnId": turnID, "terminal": "completed"])
    default: break
    }
    writeFrame(["jsonrpc": "2.0", "id": id, "result": result])
}
