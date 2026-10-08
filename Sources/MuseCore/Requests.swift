import Foundation

public enum SessionHistory {
    public static func items(_ history: JSONValue) throws -> [JSONValue] {
        if history["mode"].string == "none" {
            throw ConnectionFailure.protocolError("session history is unavailable (\(history["noneReason"].string ?? "unknown reason")). Reconnect or start a new session before continuing.")
        }
        if history["items"] != .null { return history["items"].array }
        if history["snapshot"] != .null {
            guard history["snapshot"]["schemaVersion"].int == 1 else { throw ConnectionFailure.protocolError("unsupported history snapshot") }
            return history["snapshot"]["state"]["items"].array
        }
        throw ConnectionFailure.protocolError("session history is unavailable")
    }
}

public enum UserInputAnswer {
    public static func make(question: JSONValue, selections: [String], freeText: String) -> JSONValue? {
        guard let id = question["id"].string, !id.isEmpty else { return nil }
        let text = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            guard text.unicodeScalars.count <= 500 else { return nil }
            return .object(["questionId": .string(id), "freeText": .string(text)])
        }
        let allowed = Set(question["options"].array.compactMap { $0["label"].string })
        let selected = Set(selections)
        guard !selected.isEmpty, selected.isSubset(of: allowed), selected.count == selections.count else { return nil }
        if question["selection"]["mode"].string == "multiple" {
            guard selections.count >= (question["selection"]["minSelections"].int ?? 1),
                  selections.count <= (question["selection"]["maxSelections"].int ?? Int.max) else { return nil }
            return .object(["questionId": .string(id), "selectedLabels": .array(selections.map(JSONValue.string))])
        }
        guard question["selection"]["mode"].string == "single", selections.count == 1 else { return nil }
        return .object(["questionId": .string(id), "selectedLabel": .string(selections[0])])
    }
}

public enum ApprovalDescription {
    public static func summary(_ request: JSONValue) -> String {
        let subject = request["subject"]
        switch subject["kind"].string {
        case "shell": return subject["command"].string ?? subject.prettyPrinted
        case "fileAccess": return (subject["access"].string ?? "File access") + ": " + (subject["path"].string ?? subject["target"].string ?? "Unknown path")
        case "network":
            let port = subject["port"].int.map { ":\($0)" } ?? ""
            return (subject["protocol"].string ?? "network") + "://" + (subject["host"].string ?? "Unknown host") + port
        case "unixSocket", "process": return (subject["kind"].string ?? "Action") + ": " + (subject["path"].string ?? subject["target"].string ?? subject.prettyPrinted)
        case "tool": return subject["toolName"].string ?? request["toolName"].string ?? subject.prettyPrinted
        default: return subject.prettyPrinted
        }
    }
}
