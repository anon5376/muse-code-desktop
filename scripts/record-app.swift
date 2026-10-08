// Records only this app's windows. No desktop, other applications, or audio.
// Developer utility; macOS 15+ is needed for ScreenCaptureKit's file writer.
import AppKit
import AVFoundation
import ScreenCaptureKit

@available(macOS 15.0, *)
final class RecordingDelegate: NSObject, SCRecordingOutputDelegate {
    var finished = false
    var failure: Error?
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        print("RECORDING: Muse desktop windows only; no audio")
        fflush(stdout)
    }
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { finished = true }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        failure = error; finished = true
    }
}

@main
enum RecordMuseApp {
    static func main() async throws {
        guard #available(macOS 15.0, *) else { fatalError("Recording utility requires macOS 15 or later") }
        let args = CommandLine.arguments
        guard args.count == 4, let pid = Int32(args[1]),
              NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "local.musecode.native" else {
            fatalError("Usage: record-app <Muse PID> <new output.mp4> <stop-file>")
        }
        let destination = URL(fileURLWithPath: args[2])
        guard !FileManager.default.fileExists(atPath: destination.path),
              !FileManager.default.fileExists(atPath: args[3]) else { fatalError("Output and stop-file must be new paths") }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let application = content.applications.first(where: { $0.processID == pid }),
              let window = content.windows.filter({ $0.owningApplication?.processID == pid && $0.windowLayer == 0 })
                .max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }),
              let display = content.displays.first(where: { $0.frame.contains(window.frame) }) else {
            fatalError("Muse window must fit on one display")
        }
        let filter = SCContentFilter(display: display, including: [application], exceptingWindows: [])
        filter.includeMenuBar = false
        let configuration = SCStreamConfiguration()
        configuration.width = 1280; configuration.height = 820
        configuration.sourceRect = window.frame.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.showsCursor = false
        configuration.capturesAudio = false; configuration.captureMicrophone = false
        configuration.includeChildWindows = true; configuration.ignoreShadowsDisplay = true
        let outputConfiguration = SCRecordingOutputConfiguration()
        outputConfiguration.outputURL = destination
        outputConfiguration.videoCodecType = .h264; outputConfiguration.outputFileType = .mp4
        let delegate = RecordingDelegate()
        let output = SCRecordingOutput(configuration: outputConfiguration, delegate: delegate)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addRecordingOutput(output)
        try await stream.startCapture()
        let deadline = Date().addingTimeInterval(180)
        while !FileManager.default.fileExists(atPath: args[3]), Date() < deadline, delegate.failure == nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        try await stream.stopCapture()
        let finishDeadline = Date().addingTimeInterval(5)
        while !delegate.finished, Date() < finishDeadline { try await Task.sleep(for: .milliseconds(100)) }
        if let error = delegate.failure { throw error }
        guard delegate.finished else { fatalError("Recording did not finish within five seconds") }
        print("SAVED:", destination.path)
    }
}
