import Foundation
import MuseCore
import Darwin

/// A skill from the session catalog. `selector` is what the host expects
/// at send time; `name` is the display label — they can differ.
struct SkillEntry: Identifiable {
    let raw: JSONValue
    var selector: String? { raw["selector"].string }
    var id: String { selector ?? raw["id"].string ?? name }
    var name: String { raw["displayName"].string ?? raw["display_name"].string ?? raw["name"].string ?? "Unnamed skill" }
    var description: String { raw["description"].string ?? "" }
    var source: String { raw["scope"].string ?? raw["source"].string ?? "unknown" }
    var isEnabled: Bool { raw["activation"].string != "off" && raw["activation"].string != "disabled" }
    var invocationName: String { selector ?? raw["name"].string ?? name }
    func matches(_ query: String) -> Bool {
        query.isEmpty || [name, invocationName, description, source].contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

/// Decodes `skill/list` results and resolves a chip to the selector the
/// host actually accepts (selector → display name → slug fallback).
enum CLICatalog {
    enum Kind { case skills, plugins }

    static func read(_ kind: Kind, executable: URL, workspace: URL) async throws -> JSONValue {
        try await Task.detached(priority: .utility) {
            let process = Process(), output = Pipe()
            process.executableURL = executable; process.currentDirectoryURL = workspace
            process.arguments = kind == .skills ? ["skills", "list", "--workspace", workspace.path, "--json"] : ["plugins", "list", "--json"]
            var environment = ProcessInfo.processInfo.environment
            environment["MUSE_NO_AUTO_UPDATE"] = "1"; process.environment = environment
            process.standardInput = FileHandle.nullDevice; process.standardOutput = output; process.standardError = FileHandle.nullDevice
            try process.run()
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            let forceStop = DispatchWorkItem { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
            DispatchQueue.global().asyncAfter(deadline: .now() + 13, execute: forceStop)
            defer { timeout.cancel(); forceStop.cancel(); try? output.fileHandleForReading.close() }
            var bytes = Data()
            while let chunk = try output.fileHandleForReading.read(upToCount: 65_536), !chunk.isEmpty {
                guard bytes.count + chunk.count <= 4 * 1_024 * 1_024 else {
                    process.terminate(); process.waitUntilExit()
                    throw ConnectionFailure.protocolError("The CLI catalog exceeded 4 MiB.")
                }
                bytes.append(chunk)
            }
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw ConnectionFailure.protocolError("Muse could not read this catalog. Check the CLI configuration and refresh.") }
            return try JSONDecoder().decode(JSONValue.self, from: bytes)
        }.value
    }
}
