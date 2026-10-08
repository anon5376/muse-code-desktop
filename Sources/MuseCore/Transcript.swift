import Foundation

public struct TranscriptItem: Identifiable, Equatable, Sendable {
    public var raw: JSONValue
    public init(_ raw: JSONValue) { self.raw = raw }
    public var id: String { raw["itemId"].string ?? "" }
    public var kind: String { raw["kind"].string ?? "unknown" }
    public var status: String { raw["status"].string ?? "unknown" }
    public var revision: Int { raw["revision"].int ?? 0 }
    public var text: String { raw["text"].string ?? raw["displayText"].string ?? raw["fallbackText"].string ?? raw["message"].string ?? "" }
    public var output: String { raw["visibleOutput"].string ?? "" }
    public var tool: String { raw["tool"].string ?? raw["commandText"].string ?? kind }
    public var isActive: Bool { status == "inProgress" }
    public var statusLabel: String { ActivityStatus.label(status) }
}

public enum ActivityStatus {
    public static func label(_ raw: String) -> String {
        ["inProgress": "Running", "completed": "Done", "failed": "Failed", "interrupted": "Stopped", "cancelled": "Stopped", "canceled": "Stopped", "notLoaded": "Not loaded"][raw]
            ?? raw.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}

public struct Transcript: Equatable, Sendable {
    public private(set) var items: [TranscriptItem] = []
    private var indices: [String: Int] = [:]
    private var deltaCursors: [String: Set<String>] = [:]
    public init() {}
    @discardableResult public mutating func apply(_ notification: JSONValue) -> Bool {
        let params = notification["params"]
        switch notification["method"].string {
        case "item/started", "item/updated", "item/completed":
            return upsert(TranscriptItem(params["item"]))
        case "item/delta":
            guard let id = params["itemId"].string, let index = indices[id], items[index].isActive,
                  let delta = params["delta"].string else { return false }
            let wireField = params["field"].string ?? "text"
            let field = wireField == "output" ? "visibleOutput" : wireField
            guard ["text", "visibleOutput", "args"].contains(field) else { return false }
            if let cursor = params["viewCursor"].string {
                guard deltaCursors[id, default: []].insert(cursor).inserted else { return false }
            }
            var value = items[index].raw.object
            value[field] = .string((value[field]?.string ?? "") + delta)
            items[index].raw = .object(value)
            return true
        default:
            return false
        }
    }

    public mutating func restore(_ rawItems: [JSONValue]) {
        items = []; indices = [:]; deltaCursors = [:]
        for raw in rawItems { upsert(TranscriptItem(raw)) }
    }

    @discardableResult private mutating func upsert(_ item: TranscriptItem) -> Bool {
        guard !item.id.isEmpty else { return false }
        if let index = indices[item.id] {
            guard item.revision > items[index].revision else { return false }
            items[index] = item
        } else {
            indices[item.id] = items.count
            items.append(item)
        }
        if !item.isActive { deltaCursors[item.id] = nil }
        return true
    }
}
