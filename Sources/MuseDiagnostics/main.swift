import Foundation
import MuseCore
import Darwin

guard let executable = MuseExecutable.locate(preferredPath: CommandLine.arguments.dropFirst().first) else {
    print("FAIL: Muse CLI was not found. Install Muse or pass its executable path.")
    exit(1)
}
do {
    let result = try await EchoDiagnostic.run(executable: executable)
    print("PASS Muse \(result.version): initialize → session → streamed reply → completed turn → shutdown")
    print("Reply: \(result.reply)")
    print("Schema: \(result.fingerprint)")
    print("Offline round trip: \(result.elapsedMilliseconds) ms (not a model benchmark)")
} catch {
    print("FAIL: \(error.localizedDescription)")
    exit(1)
}
