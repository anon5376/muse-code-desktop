// Developer verification through the real app's accessibility surface.
// Deliberately restricted to this bundle; no production-only test hooks.
import AppKit
import ApplicationServices
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3, let pid = Int32(args[1]),
      let running = NSRunningApplication(processIdentifier: pid), running.bundleIdentifier == "local.musecode.native" else {
    fatalError("Usage: ui-check.swift <Muse PID> dump|press|set|resize|window [arguments]")
}
guard AXIsProcessTrusted() else { fatalError("macOS accessibility permission is unavailable") }
let app = AXUIElementCreateApplication(pid)
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}
func text(_ element: AXUIElement, _ key: String) -> String { attribute(element, key) as? String ?? "" }
func children(_ element: AXUIElement) -> [AXUIElement] { attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func find(_ element: AXUIElement, label: String, role: String? = nil, depth: Int = 0) -> AXUIElement? {
    guard depth < 24 else { return nil }
    if text(element, kAXRoleAttribute) == kAXApplicationRole {
        for window in attribute(element, kAXWindowsAttribute) as? [AXUIElement] ?? [] {
            if let result = find(window, label: label, role: role, depth: depth + 1) { return result }
        }
        return nil
    }
    if (role == nil || text(element, kAXRoleAttribute) == role),
       [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].contains(where: { text(element, $0) == label }) { return element }
    for child in children(element) { if let result = find(child, label: label, role: role, depth: depth + 1) { return result } }
    return nil
}
func check(_ status: AXError) {
    guard status == .success else {
        print("Accessibility operation returned \(status.rawValue); verify the resulting UI state separately.")
        exit(1)
    }
}
switch args[2] {
case "dump":
    var count = 0
    func dump(_ element: AXUIElement, depth: Int) {
        guard depth < 18, count < 500 else { return }; count += 1
        let role = text(element, kAXRoleAttribute)
        let title = text(element, kAXTitleAttribute)
        let label = text(element, kAXDescriptionAttribute)
        let value = text(element, kAXValueAttribute)
        print(String(repeating: " ", count: depth) + [role, title, label, String(value.prefix(200))].filter { !$0.isEmpty }.joined(separator: " | "))
        for child in children(element) { dump(child, depth: depth + 1) }
    }
    for window in attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? [] { dump(window, depth: 0) }
case "press":
    guard args.count >= 4, let target = find(app, label: args[3]) else { fatalError("Control was not found") }
    check(AXUIElementPerformAction(target, kAXPressAction as CFString))
    print("Pressed: \(args[3])")
case "set":
    guard args.count >= 5, let target = find(app, label: args[3], role: kAXTextAreaRole) ?? find(app, label: args[3], role: kAXTextFieldRole) else { fatalError("Text input was not found") }
    check(AXUIElementSetAttributeValue(target, kAXValueAttribute as CFString, args[4] as CFString))
    print("Set text input: \(args[3])")
case "type":
    guard args.count >= 5, let target = find(app, label: args[3], role: kAXTextAreaRole) ?? find(app, label: args[3], role: kAXTextFieldRole) else { fatalError("Text input was not found") }
    check(AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue))
    for pressed in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: pressed)!
        event.flags = .maskCommand; event.postToPid(pid)
    }
    let units = Array(args[4].utf16)
    for pressed in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: pressed)!
        units.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
        event.postToPid(pid)
    }
    print("Typed into Muse input: \(args[3])")
case "resize":
    guard args.count >= 5, let width = Double(args[3]), let height = Double(args[4]),
          let window = (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first(where: { text($0, kAXTitleAttribute).hasPrefix("Muse Code") }) else { fatalError("Workspace window or size was not found") }
    var size = CGSize(width: width, height: height)
    check(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!))
    print("Resized Muse: \(width) × \(height)")
case "send-key":
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false) else { fatalError("Key event unavailable") }
    down.flags = .maskCommand; up.flags = .maskCommand
    down.postToPid(pid); up.postToPid(pid)
    print("Sent Command-Return only to Muse")
case "key":
    guard args.count >= 4, let code = UInt16(args[3]), code < 128 else { fatalError("Key code unavailable") }
    for pressed in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: pressed)!
        if args.count >= 5, args[4] == "command" { event.flags = .maskCommand }
        event.postToPid(pid)
    }
    print("Sent key only to Muse")
case "type-current":
    guard args.count >= 4 else { fatalError("Text unavailable") }
    let units = Array(args[3].utf16)
    for pressed in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: pressed)!
        units.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
        event.postToPid(pid)
    }
    print("Typed into Muse's existing keyboard focus")
case "window":
    let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    for window in windows where (window[kCGWindowOwnerPID as String] as? Int32) == pid && (window[kCGWindowLayer as String] as? Int) == 0 {
        print("Window \(window[kCGWindowNumber as String] ?? 0): \(window[kCGWindowBounds as String] ?? [:])")
    }
default: fatalError("Unknown UI check")
}
