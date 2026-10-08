import Foundation
import Darwin

public enum ConnectionFailure: Error, LocalizedError {
    case notRunning
    case timeout(String)
    case protocolError(String)
    case hostExit(Int32)
    case rpc(Int, String, String?)
    public var errorDescription: String? {
        switch self {
        case .notRunning: return "Muse is not connected. Reconnect and try again."
        case .timeout(let method): return "Muse did not acknowledge \(method) in time. Check the session before sending again."
        case .protocolError(let detail): return "Muse protocol error: \(detail)"
        case .hostExit(let code): return "Muse exited with code \(code). Reconnect to resume the session."
        case .rpc(_, let message, _): return String(message.prefix(2_000))
        }
    }
}

public struct MuseLaunchConfiguration: Sendable {
    public var executable: URL
    public var workspace: URL
    public var arguments: [String]
    public var environment: [String: String]
    public var requestedCapabilities: [String]
    public init(executable: URL, workspace: URL, arguments: [String] = ["serve"], environment: [String: String] = [:], requestedCapabilities: [String] = []) {
        self.executable = executable; self.workspace = workspace
        self.arguments = arguments; self.environment = environment; self.requestedCapabilities = requestedCapabilities
    }
}

public enum MuseExecutable {
    public static func locate(preferredPath: String? = nil) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var candidates = [preferredPath, home.appendingPathComponent(".local/bin/muse").path, "/opt/homebrew/bin/muse", "/usr/local/bin/muse"].compactMap { $0 }
        candidates += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/muse" }
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
}

public final class MuseConnection: @unchecked Sendable {
    public static let expectedFingerprint = "sha256:61afea3112e0906e9dc3a536144278a74cb4b36fc6e20901a91d4432ba3568e2"
    private let queue = DispatchQueue(label: "muse.native.protocol", qos: .userInitiated)
    private let writer = DispatchQueue(label: "muse.native.stdin", qos: .userInitiated)
    private let onEvents: @Sendable ([JSONValue]) -> Void
    private let onExit: @Sendable (String?) -> Void
    private var process: Process?
    private var input: FileHandle?
    private var framer = LineFramer()
    private var pending: [String: (CheckedContinuation<JSONValue, Error>, DispatchWorkItem)] = [:]
    private var eventBatch: [JSONValue] = []
    private var flushScheduled = false
    private var stopping = false
    private var finished = false
    private var stdoutClosed = false
    private var outputReader: DispatchSourceRead?
    private var errorReader: DispatchSourceRead?
    private var stderrTail = Data()
    private var exitDrainScheduled = false
    private var exitStatus: Int32?
    private var forcedFailure: Error?
    private var shutdownWaiters: [CheckedContinuation<Void, Never>] = []

    public init(onEvents: @escaping @Sendable ([JSONValue]) -> Void, onExit: @escaping @Sendable (String?) -> Void = { _ in }) {
        self.onEvents = onEvents; self.onExit = onExit
    }

    public func start(_ configuration: MuseLaunchConfiguration) async throws -> JSONValue {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard self.process == nil, !self.finished else {
                    continuation.resume(throwing: ConnectionFailure.protocolError("this connection was already started")); return
                }
                let child = Process()
                let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
                child.executableURL = configuration.executable
                child.arguments = configuration.arguments
                child.currentDirectoryURL = configuration.workspace
                var environment = ProcessInfo.processInfo.environment
                environment.merge(configuration.environment) { _, supplied in supplied }
                environment["MUSE_NO_AUTO_UPDATE"] = "1"
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                environment["PATH"] = [home + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", environment["PATH"] ?? "/usr/bin:/bin"].joined(separator: ":")
                child.environment = environment
                child.standardInput = stdin; child.standardOutput = stdout; child.standardError = stderr
                child.terminationHandler = { [weak self] terminated in
                    self?.queue.async { [weak self] in self?.exitStatus = terminated.terminationStatus; self?.finishIfExited() }
                }
                do {
                    try child.run()
                    self.process = child
                    self.input = stdin.fileHandleForWriting
                    self.readOutput(stdout.fileHandleForReading)
                    self.drainStderr(stderr.fileHandleForReading)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                    self.finish(error)
                }
            }
        }
        do {
            let hello = try await request("initialize", [
                "clientInfo": .object(["name": .string("muse_native"), "title": .string("Muse Code Desktop"), "version": .string("0.1.0")]),
                "capabilities": .object(["userInputDialogs": .bool(true), "requestedCapabilities": .array(configuration.requestedCapabilities.map(JSONValue.string))])
            ], timeout: 15)
            guard hello["schema"]["version"].int == 1 else { throw ConnectionFailure.protocolError("unsupported wire envelope version") }
            notify("initialized")
            return hello
        } catch {
            stop()
            throw error
        }
    }

    public func request(_ method: String, _ params: [String: JSONValue] = [:], timeout: TimeInterval = 30) async throws -> JSONValue {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.process?.isRunning == true, !self.stopping else { continuation.resume(throwing: ConnectionFailure.notRunning); return }
                let id = UUID().uuidString
                let expiry = DispatchWorkItem { [weak self] in
                    guard let entry = self?.pending.removeValue(forKey: id) else { return }
                    entry.0.resume(throwing: ConnectionFailure.timeout(method))
                }
                self.pending[id] = (continuation, expiry)
                self.queue.asyncAfter(deadline: .now() + timeout, execute: expiry)
                self.send(.object(["jsonrpc": .string("2.0"), "id": .string(id), "method": .string(method), "params": .object(params)]))
            }
        }
    }

    public func notify(_ method: String, _ params: [String: JSONValue] = [:]) {
        queue.async {
            guard !self.stopping else { return }
            self.send(.object(["jsonrpc": .string("2.0"), "method": .string(method), "params": .object(params)]))
        }
    }

    public func stop() { queue.async { self.beginStop() } }

    public func shutdown() async {
        await withCheckedContinuation { continuation in
            queue.async {
                guard !self.finished, self.process != nil else { continuation.resume(); return }
                self.shutdownWaiters.append(continuation)
                self.beginStop()
            }
        }
    }

    public func diagnosticDetails() async -> String? {
        await withCheckedContinuation { continuation in
            queue.async {
                let detail = String(decoding: self.stderrTail, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: detail.isEmpty ? nil : detail)
            }
        }
    }

    private func readOutput(_ handle: FileHandle) {
        let reader = DispatchSource.makeReadSource(fileDescriptor: handle.fileDescriptor, queue: queue)
        reader.setEventHandler { [weak self] in
            guard let self, !self.finished else { return }
            // One reader on the protocol queue consumes only signalled bytes.
            let data = handle.availableData
            if data.isEmpty {
                self.stdoutClosed = true
                self.outputReader?.cancel(); self.outputReader = nil
                self.finishIfExited()
            } else { self.consume(data) }
        }
        reader.setCancelHandler { try? handle.close() }
        outputReader = reader; reader.resume()
    }

    private func drainStderr(_ handle: FileHandle) {
        let reader = DispatchSource.makeReadSource(fileDescriptor: handle.fileDescriptor, queue: queue)
        reader.setEventHandler { [weak self] in
            guard let self, !self.finished else { return }
            // Keep only a small memory tail for explicit user inspection. Never
            // print or persist provider/configuration diagnostics.
            let bytes = handle.availableData
            if bytes.isEmpty {
                self.errorReader?.cancel(); self.errorReader = nil
            } else {
                self.stderrTail.append(bytes.suffix(8_192))
                if self.stderrTail.count > 8_192 { self.stderrTail = Data(self.stderrTail.suffix(8_192)) }
            }
        }
        reader.setCancelHandler { try? handle.close() }
        errorReader = reader; reader.resume()
    }

    private func consume(_ data: Data) {
        guard !finished else { return }
        do {
            for line in try framer.append(data) {
                let frame = try JSONDecoder().decode(JSONValue.self, from: line)
                guard frame["jsonrpc"].string == "2.0" else { throw ConnectionFailure.protocolError("invalid JSON-RPC envelope") }
                if let method = frame["method"].string {
                    if frame["id"] != .null {
                        if ["approval/request", "userInput/request"].contains(method) {
                            // MSP SS5.3.3 RequestReceipt (schema fingerprint
                            // expectedFingerprint): {} acknowledges presentation
                            // only. It changes no approval/question state; the
                            // human decision uses approval/decide or userInput/answer.
                            send(.object(["jsonrpc": .string("2.0"), "id": frame["id"], "result": .object([:])]))
                        } else {
                            send(.object(["jsonrpc": .string("2.0"), "id": frame["id"],
                                "error": .object(["code": .number(-32601), "message": .string("Client method is not supported")])]))
                            continue
                        }
                    }
                    eventBatch.append(frame)
                    if eventBatch.count >= 256 { flush() }
                    else if !flushScheduled {
                        flushScheduled = true
                        queue.asyncAfter(deadline: .now() + .milliseconds(24)) { [weak self] in self?.flush() }
                    }
                } else if let id = frame["id"].string, let entry = pending.removeValue(forKey: id) {
                    entry.1.cancel()
                    if let code = frame["error"]["code"].int {
                        entry.0.resume(throwing: ConnectionFailure.rpc(code, frame["error"]["message"].string ?? "Muse rejected the request", frame["error"]["data"]["kind"].string))
                    } else if frame.object.keys.contains("result") {
                        entry.0.resume(returning: frame["result"])
                    } else { entry.0.resume(throwing: ConnectionFailure.protocolError("response has no result or error")) }
                }
            }
        } catch { abort(error) }
    }

    private func send(_ frame: JSONValue) {
        guard let handle = input, !finished else { abort(ConnectionFailure.notRunning); return }
        do {
            var data = try JSONEncoder().encode(frame)
            guard data.count <= 8 * 1_024 * 1_024 else { throw ConnectionFailure.protocolError("request exceeds the 8 MiB limit") }
            data.append(0x0A)
            writer.async { [weak self] in
                do { try handle.write(contentsOf: data) }
                catch { self?.queue.async { [weak self] in self?.abort(ConnectionFailure.protocolError("the input pipe was closed")) } }
            }
        } catch { abort(error) }
    }

    private func flush() {
        flushScheduled = false
        guard !eventBatch.isEmpty else { return }
        let batch = eventBatch
        eventBatch.removeAll(keepingCapacity: true)
        onEvents(batch)
    }

    private func abort(_ error: Error) {
        if forcedFailure == nil { forcedFailure = error }
        beginStop()
    }

    private func beginStop() {
        guard !stopping, !finished else { return }
        stopping = true
        guard let child = process else { finish(forcedFailure); return }
        if let handle = input { writer.async { try? handle.close() } }
        queue.asyncAfter(deadline: .now() + .milliseconds(750)) {
            if child.isRunning { child.terminate() }
        }
        queue.asyncAfter(deadline: .now() + .seconds(3)) {
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
        }
    }

    private func finishIfExited() {
        guard let code = exitStatus, !finished else { return }
        if stdoutClosed { finish(forcedFailure ?? (stopping ? nil : ConnectionFailure.hostExit(code))); return }
        guard !exitDrainScheduled else { return }
        exitDrainScheduled = true
        // Preserve already-buffered final frames, but descendants inheriting a
        // pipe must not keep the app's shutdown or reconnect waiting forever.
        queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
            guard let self else { return }
            self.finish(self.forcedFailure ?? (self.stopping ? nil : ConnectionFailure.hostExit(code)))
        }
    }

    private func finish(_ error: Error?) {
        guard !finished else { return }
        finished = true
        outputReader?.cancel(); outputReader = nil
        errorReader?.cancel(); errorReader = nil
        flush()
        for (_, entry) in pending { entry.1.cancel(); entry.0.resume(throwing: error ?? ConnectionFailure.notRunning) }
        pending.removeAll()
        process = nil; input = nil
        for waiter in shutdownWaiters { waiter.resume() }
        shutdownWaiters.removeAll()
        onExit(error?.localizedDescription)
    }
}
