import Foundation

public struct DiagnosticReport: Sendable {
    public let version: String
    public let fingerprint: String
    public let reply: String
    public let elapsedMilliseconds: Int
}

public enum EchoDiagnostic {
    public static func configuration(executable: URL, workspace: URL, temporaryRoot: URL) throws -> MuseLaunchConfiguration {
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return MuseLaunchConfiguration(executable: executable, workspace: workspace,
            arguments: ["serve", "--provider", "echo", "--no-session-log", "--disable-write", "--disable-shell"],
            environment: ["XDG_CONFIG_HOME": temporaryRoot.appendingPathComponent("config").path,
                          "XDG_DATA_HOME": temporaryRoot.appendingPathComponent("data").path,
                          "XDG_CACHE_HOME": temporaryRoot.appendingPathComponent("cache").path])
    }

    public static func run(executable: URL) async throws -> DiagnosticReport {
        let started = Date()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("muse-native-check-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = try configuration(executable: executable, workspace: root, temporaryRoot: root)
        let (events, receiver) = AsyncStream<[JSONValue]>.makeStream()
        let connection = MuseConnection(onEvents: { receiver.yield($0) }, onExit: { _ in receiver.finish() })
        do {
            let hello = try await connection.start(configuration)
            let session = try await connection.request("session/start", ["commandId": .string(CommandID.make()), "workspaceRoot": .string(root.path)])
            guard let sessionID = session["session"]["sessionId"].string else { throw ConnectionFailure.protocolError("session ID is missing") }
            _ = try await connection.request("turn/start", ["commandId": .string(CommandID.make()), "sessionId": .string(sessionID),
                "input": .array([.object(["type": .string("text"), "text": .string("muse-native-round-trip ✓")])])])
            let reply = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    var transcript = Transcript()
                    for await batch in events {
                        for event in batch where event["params"]["sessionId"].string == sessionID {
                            transcript.apply(event)
                            if event["method"].string == "turn/completed" {
                                guard event["params"]["terminal"].string == "completed" else { throw ConnectionFailure.protocolError("diagnostic turn did not complete") }
                                return transcript.items.last(where: { $0.kind == "agentMessage" })?.text ?? ""
                            }
                        }
                    }
                    throw ConnectionFailure.notRunning
                }
                group.addTask { try await Task.sleep(for: .seconds(10)); throw ConnectionFailure.timeout("diagnostic turn") }
                let answer = try await group.next()!
                group.cancelAll()
                return answer
            }
            guard reply == "echo: muse-native-round-trip ✓" else { throw ConnectionFailure.protocolError("echo reply was not preserved") }
            await connection.shutdown()
            return DiagnosticReport(version: hello["serverInfo"]["version"].string ?? "unknown",
                fingerprint: hello["schema"]["fingerprint"].string ?? "unknown", reply: reply,
                elapsedMilliseconds: Int(Date().timeIntervalSince(started) * 1_000))
        } catch {
            await connection.shutdown()
            throw error
        }
    }
}
