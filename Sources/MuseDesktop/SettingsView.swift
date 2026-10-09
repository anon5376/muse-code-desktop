import SwiftUI
import AppKit
import MuseCore

/// Connection settings: Muse executable override, offline diagnostic
/// self-test, and the unofficial-client disclosure.
struct SettingsView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var path = ""
    @State private var diagnostic = ""
    @State private var testing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    MuseMark(size: 28)
                    Text("Muse Code settings").font(.system(size: 20, weight: .semibold))
                    Spacer()
                }
                Text("Unofficial desktop client. This is not the official Muse Code desktop app and is not affiliated with or endorsed by Meta.")
                    .font(.system(size: 12)).foregroundStyle(MuseTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("CLI executable").font(.system(size: 12, weight: .medium))
                HStack {
                    TextField("Auto-detect ~/.local/bin/muse", text: $path).textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced))
                    Button("Choose…") { chooseExecutable() }.controlSize(.small)
                }
                Text("The app runs muse serve and uses your existing Muse login, model, and permission settings.")
                    .font(.system(size: 12)).foregroundStyle(MuseTheme.secondary)
            }
            Hairline()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.hostVersion.isEmpty ? store.engineLabel : "Muse \(store.hostVersion) · \(store.engineLabel)").font(.system(size: 12, weight: .medium))
                    Spacer()
                    if testing { ProgressView().controlSize(.small) }
                }
                Button("Test local connection") { testConnection() }.controlSize(.small).disabled(testing)
                Text(diagnostic.isEmpty ? "The test uses the offline echo provider and an isolated temporary session. It makes no model request." : diagnostic)
                    .font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Need to sign in?").font(.system(size: 12, weight: .medium))
                Text("Run muse login in Terminal, then reconnect here.").font(.system(size: 12)).foregroundStyle(MuseTheme.secondary)
                HStack {
                    Button("Copy login command") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString("muse login", forType: .string) }
                    Button("Open Terminal") { NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: .init()) }
                }.controlSize(.small)
            }
            Hairline()
            HStack {
                Text("Native UI · local CLI engine").font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
                Spacer()
                Button("Cancel") { store.settingsVisible = false }.keyboardShortcut(.cancelAction)
                Button("Save & reconnect") { store.executablePath = path; store.saveExecutable() }.keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent).tint(MuseTheme.controlAccent)
            }
        }.padding(28).frame(width: 540).background(MuseTheme.canvas).foregroundStyle(MuseTheme.text)
            .preferredColorScheme(.dark).onAppear { path = store.executablePath }
    }

    private func chooseExecutable() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = true; picker.canChooseDirectories = false; picker.allowsMultipleSelection = false
        picker.prompt = "Choose Muse"
        picker.begin { result in if result == .OK, let url = picker.url { path = url.path } }
    }
    private func testConnection() {
        guard let executable = MuseExecutable.locate(preferredPath: path.isEmpty ? nil : path) else { diagnostic = "Muse executable was not found."; return }
        testing = true; diagnostic = "Testing…"
        Task {
            defer { testing = false }
            do {
                let result = try await EchoDiagnostic.run(executable: executable)
                diagnostic = result.reply.hasPrefix("echo:")
                    ? "Passed: Muse \(result.version), streamed echo reply and clean shutdown in \(result.elapsedMilliseconds) ms."
                    : "Passed: Muse \(result.version) completed a streamed turn and clean shutdown in \(result.elapsedMilliseconds) ms. (Host did not echo the probe text — it is a fixture or non-echo provider, not the real echo CLI.)"
            } catch { diagnostic = "Failed: \(error.localizedDescription)" }
        }
    }
}
