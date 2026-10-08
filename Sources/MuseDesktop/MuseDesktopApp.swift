import SwiftUI
import AppKit

@main
enum MuseDesktopApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = MuseAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class MuseAppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let store = WorkspaceStore()
    private var window: NSWindow?
    private var quitting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenus()
        let content = WorkspaceView(store: store)
            .frame(minWidth: 980, minHeight: 608)
            .preferredColorScheme(.dark)
            .tint(MuseTheme.accent)
            .task { [store] in await store.start() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1_280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Muse Code · Unofficial"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 980, height: 640)
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.setFrameAutosaveName("MuseWorkspace")
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !quitting else { return .terminateLater }
        if store.anyRunning {
            let alert = NSAlert()
            alert.messageText = "Quit while Muse is working?"
            alert.informativeText = "Active turns will stop. You can resume their sessions next time."
            alert.addButton(withTitle: "Quit Muse Code"); alert.addButton(withTitle: "Keep Working")
            guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
        }
        quitting = true
        var replied = false
        let finish: @MainActor () -> Void = {
            guard !replied else { return }
            replied = true; sender.reply(toApplicationShouldTerminate: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { finish() }
        Task {
            await store.shutdownAndWait()
            finish()
        }
        return .terminateLater
    }

    @objc private func newSession() { store.newSession() }
    @objc private func openWorkspace() { store.chooseWorkspace() }
    @objc private func showSettings() { store.settingsVisible = true }
    @objc private func toggleInspector() { store.inspectorVisible.toggle() }
    @objc private func showLibrary() { store.openLibrary() }
    @objc private func toggleSessions() { store.sidebarVisible.toggle() }
    @objc private func sendMessage() { store.send() }
    @objc private func interruptTurn() { store.interrupt() }
    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Muse Code Desktop (Unofficial)",
            .credits: NSAttributedString(string: "Independent desktop client for the Muse Code CLI.\nThis is not the official Muse Code desktop app.\nNot affiliated with or endorsed by Meta.\n\nMuse and its logo belong to Meta.\nThe logo is not covered by this project's MIT license.")
        ])
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(newSession): return store.engine == .ready && !store.isBusy && !store.isChangingModel
        case #selector(openWorkspace): return !store.isBusy
        case #selector(sendMessage): return store.canSend
        case #selector(interruptTurn): return store.isRunning
        default: return true
        }
    }

    private func installMenus() {
        let bar = NSMenu()
        func menu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title); item.submenu = submenu; bar.addItem(item)
            return submenu
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = target; menu.addItem(item)
        }
        let appMenu = menu("Muse Code")
        add(appMenu, "About Muse Code", #selector(showAbout), target: self)
        appMenu.addItem(.separator())
        add(appMenu, "Settings…", #selector(showSettings), ",", target: self)
        appMenu.addItem(.separator())
        add(appMenu, "Hide Muse Code", #selector(NSApplication.hide(_:)), "h")
        add(appMenu, "Show All", #selector(NSApplication.unhideAllApplications(_:)))
        appMenu.addItem(.separator())
        add(appMenu, "Quit Muse Code", #selector(NSApplication.terminate(_:)), "q")
        let file = menu("File")
        add(file, "New Session", #selector(newSession), "n", target: self)
        add(file, "Open Workspace…", #selector(openWorkspace), "o", target: self)
        file.addItem(.separator())
        add(file, "Send Message", #selector(sendMessage), "\r", target: self)
        add(file, "Stop Turn", #selector(interruptTurn), ".", target: self)
        file.addItem(.separator())
        add(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
        let edit = menu("Edit")
        add(edit, "Undo", Selector(("undo:")), "z")
        add(edit, "Redo", Selector(("redo:")), "Z")
        edit.addItem(.separator())
        add(edit, "Cut", #selector(NSText.cut(_:)), "x")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Paste", #selector(NSText.paste(_:)), "v")
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        let view = menu("View")
        add(view, "Skills & Commands", #selector(showLibrary), "k", target: self)
        add(view, "Toggle Sessions", #selector(toggleSessions), "s", target: self)
        view.items.last?.keyEquivalentModifierMask = [.command, .control]
        add(view, "Toggle Inspector", #selector(toggleInspector), "i", target: self)
        view.items.last?.keyEquivalentModifierMask = [.command, .option]
        let windows = menu("Window")
        add(windows, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(windows, "Zoom", #selector(NSWindow.performZoom(_:)))
        NSApplication.shared.windowsMenu = windows
        NSApplication.shared.mainMenu = bar
    }
}
