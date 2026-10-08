import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String)
    case number(Double), bool(Bool), null

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try value.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .object(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }

    public subscript(_ key: String) -> JSONValue {
        guard case .object(let value) = self else { return .null }
        return value[key] ?? .null
    }
    public var string: String? { if case .string(let v) = self { return v }; return nil }
    public var int: Int? { if case .number(let v) = self, v.isFinite, v >= Double(Int.min), v < Double(Int.max) { return Int(v) }; return nil }
    public var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    public var array: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    public var object: [String: JSONValue] { if case .object(let v) = self { return v }; return [:] }

    public var prettyPrinted: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

public struct LineFramer {
    public enum Failure: Error { case frameTooLarge }
    public let maximumFrameBytes: Int
    private var buffer = Data()
    public init(maximumFrameBytes: Int = 8 * 1_024 * 1_024) { self.maximumFrameBytes = maximumFrameBytes }
    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            guard buffer.distance(from: buffer.startIndex, to: newline) <= maximumFrameBytes else { throw Failure.frameTooLarge }
            var frame = Data(buffer[..<newline])
            buffer.removeSubrange(buffer.startIndex...newline)
            if frame.last == 0x0D { frame.removeLast() }
            if !frame.isEmpty { frames.append(frame) }
        }
        guard buffer.count <= maximumFrameBytes else { throw Failure.frameTooLarge }
        return frames
    }
}

public enum CommandID {
    public static func make() -> String {
        var bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
        var milliseconds = UInt64(Date().timeIntervalSince1970 * 1_000)
        for index in stride(from: 5, through: 0, by: -1) {
            bytes[index] = UInt8(milliseconds & 0xFF)
            milliseconds >>= 8
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x70
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return bytes.enumerated().map { index, byte in
            ([4, 6, 8, 10].contains(index) ? "-" : "") + String(format: "%02x", byte)
        }.joined()
    }
}
