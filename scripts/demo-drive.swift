// Drives the built Muse Code app for genuine demo capture.
// Posts raw input events only to the app's PID and reads public window
// geometry. No accessibility-tree access is required for the event path;
// `dump` uses it only when the system already trusts this process.
import AppKit
import ApplicationServices
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 2 else {
    fatalError("Usage: demo-drive.swift <command> [args] — probe|window|key|type|click|drag|shot|dump")
}

func pid(_ index: Int) -> Int32 {
    guard args.count > index, let value = Int32(args[index]) else { fatalError("Missing PID") }
    return value
}

func windowInfo(_ pid: Int32) -> (id: CGWindowID, frame: CGRect)? {
    let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    var best: (id: CGWindowID, frame: CGRect, area: CGFloat)?
    for entry in list {
        guard (entry[kCGWindowOwnerPID as String] as? Int32) == pid,
              (entry[kCGWindowLayer as String] as? Int) == 0,
              let raw = entry[kCGWindowBounds as String] as? [String: Any],
              let number = entry[kCGWindowNumber as String] as? Int else { continue }
        let frame = CGRect(x: raw["X"] as? CGFloat ?? 0, y: raw["Y"] as? CGFloat ?? 0,
                           width: raw["Width"] as? CGFloat ?? 0, height: raw["Height"] as? CGFloat ?? 0)
        let area = frame.width * frame.height
        if best == nil || area > best!.area { best = (CGWindowID(number), frame, area) }
    }
    guard let found = best else { return nil }
    return (found.id, found.frame)
}

func postKey(_ pid: Int32, _ code: UInt16, command: Bool = false, option: Bool = false, shift: Bool = false, control: Bool = false) {
    for pressed in [true, false] {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: pressed) else { fatalError("Key event unavailable") }
        var flags = CGEventFlags()
        if command { flags.insert(.maskCommand) }
        if option { flags.insert(.maskAlternate) }
        if shift { flags.insert(.maskShift) }
        if control { flags.insert(.maskControl) }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

func postMouse(_ pid: Int32, _ type: CGEventType, _ point: CGPoint) {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { fatalError("Mouse event unavailable") }
    event.post(tap: .cghidEventTap)
    usleep(30_000)
}

switch args[1] {
case "probe":
    print("AXIsProcessTrusted: \(AXIsProcessTrusted())")
    if #available(macOS 10.15, *) {
        print("CGPreflightScreenCaptureAccess: \(CGPreflightScreenCaptureAccess())")
    }
case "window":
    let target = pid(2)
    guard let info = windowInfo(target) else { fatalError("No layer-0 window for PID \(target)") }
    print("\(info.id),\(Int(info.frame.minX)),\(Int(info.frame.minY)),\(Int(info.frame.width)),\(Int(info.frame.height))")
case "key":
    let target = pid(2)
    guard args.count >= 4, let code = UInt16(args[3]), code < 128 else { fatalError("Usage: key <pid> <code> [command|option|shift|control...]") }
    let flags = args.dropFirst(4)
    postKey(target, code,
            command: flags.contains("command"), option: flags.contains("option"),
            shift: flags.contains("shift"), control: flags.contains("control"))
    print("Sent key \(code) to \(target)")
case "type":
    let target = pid(2)
    guard args.count >= 4 else { fatalError("Usage: type <pid> <text>") }
    let units = Array(args[3].utf16)
    for pressed in [true, false] {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: pressed) else { fatalError("Key event unavailable") }
        units.withUnsafeBufferPointer { event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
        event.post(tap: .cghidEventTap)
    }
    print("Typed \(args[3].count) chars to \(target)")
case "click":
    let target = pid(2)
    guard args.count >= 5, let x = Double(args[3]), let y = Double(args[4]) else { fatalError("Usage: click <pid> <x> <y>") }
    let point = CGPoint(x: x, y: y)
    // Move first: SwiftUI/AppKit tracking areas need hover state before a
    // click is treated as a real press.
    postMouse(target, .mouseMoved, point)
    usleep(80_000)
    postMouse(target, .leftMouseDown, point)
    postMouse(target, .leftMouseUp, point)
    print("Clicked \(Int(x)),\(Int(y))")
case "drag":
    let target = pid(2)
    guard args.count >= 7,
          let x1 = Double(args[3]), let y1 = Double(args[4]),
          let x2 = Double(args[5]), let y2 = Double(args[6]) else { fatalError("Usage: drag <pid> <x1> <y1> <x2> <y2> [steps]") }
    let steps = args.count >= 8 ? Int(args[7]) ?? 16 : 16
    let start = CGPoint(x: x1, y: y1)
    postMouse(target, .leftMouseDown, start)
    for step in 1...steps {
        let t = CGFloat(step) / CGFloat(steps)
        postMouse(target, .leftMouseDragged, CGPoint(x: x1 + (x2 - x1) * t, y: y1 + (y2 - y1) * t))
    }
    postMouse(target, .leftMouseUp, CGPoint(x: x2, y: y2))
    print("Dragged \(Int(x1)),\(Int(y1)) -> \(Int(x2)),\(Int(y2))")
case "shot":
    // CGWindowListCreateImage is obsoleted in the macOS 15 SDK; delegate to
    // /usr/sbin/screencapture, which capture-demo.sh also prefers directly.
    let target = pid(2)
    guard args.count >= 4, let info = windowInfo(target) else { fatalError("Window capture unavailable") }
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", String(info.id), args[3]]
    try capture.run()
    capture.waitUntilExit()
    guard capture.terminationStatus == 0 else { fatalError("screencapture exited \(capture.terminationStatus)") }
    print("Saved \(args[3]) (window \(info.id))")
case "dump":
    // Only useful when the process is already accessibility-trusted; the
    // event path above never requires it.
    guard AXIsProcessTrusted() else { fatalError("Accessibility permission is unavailable") }
    let target = pid(2)
    let app = AXUIElementCreateApplication(target)
    func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }
    func text(_ element: AXUIElement, _ key: String) -> String { attribute(element, key) as? String ?? "" }
    var count = 0
    func dump(_ element: AXUIElement, _ depth: Int) {
        guard depth < 18, count < 500 else { return }; count += 1
        print(String(repeating: " ", count: depth) + [text(element, kAXRoleAttribute), text(element, kAXTitleAttribute), text(element, kAXDescriptionAttribute)].filter { !$0.isEmpty }.joined(separator: " | "))
        for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []) { dump(child, depth + 1) }
    }
    for window in attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? [] { dump(window, 0) }
default:
    fatalError("Unknown command: \(args[1])")
}
