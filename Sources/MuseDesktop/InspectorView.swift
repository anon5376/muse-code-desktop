import SwiftUI
import AppKit

struct InspectorView: View {
    @ObservedObject var store: WorkspaceStore
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workspace").font(.system(size: 12, weight: .medium))
                Spacer()
                IconButton(symbol: "xmark", label: "Close inspector") { store.inspectorVisible = false }
            }.padding(.horizontal, 18).frame(height: 52)
            Hairline()
            Picker("Inspector", selection: $store.inspectorTab) {
                Text("Files").tag("Files")
                Text("Activity").tag("Activity")
                Text("Skills").tag("Skills")
                Text("Session").tag("Session")
            }.pickerStyle(.segmented).tint(MuseTheme.controlAccent).labelsHidden().font(.system(size: 11)).padding(12)
            if store.inspectorTab == "Files" { files }
            else if store.inspectorTab == "Activity" { ActivityInspectorView(store: store) }
            else if store.inspectorTab == "Skills" { SkillsInspectorView(store: store) }
            else { SessionControlsView(store: store) }
        }.frame(maxHeight: .infinity).background(MuseTheme.sidebar)
    }

    private var files: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.workspace?.lastPathComponent ?? "No workspace").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).lineLimit(1)
                Spacer()
                IconButton(symbol: "arrow.clockwise", label: "Refresh files") { store.refreshFiles() }
            }.padding(.horizontal, 16)
            if store.filesLoading { ProgressView().controlSize(.small).padding(20) }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    OutlineGroup(store.fileNodes, children: \.children) { node in
                        if node.isDirectory {
                            Label(node.name, systemImage: "folder").font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).lineLimit(1).padding(.vertical, 4)
                        } else {
                            Button { store.previewFile(node.url) } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "doc.text").font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
                                    Text(node.name).font(.system(size: 11)).lineLimit(1)
                                    Spacer(minLength: 0)
                                }.padding(.vertical, 4).foregroundStyle(store.filePreview?.url == node.url ? MuseTheme.accent : MuseTheme.secondary).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(.horizontal, 18).padding(.bottom, 12).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: store.filePreview == nil ? .infinity : 240)
            if let error = store.fileError {
                Text(error).font(.system(size: 11)).foregroundStyle(MuseTheme.secondary).padding(16)
            }
            if let preview = store.filePreview {
                Hairline()
                HStack {
                    Text(preview.relativePath).font(.system(size: 11, design: .monospaced)).lineLimit(1).help(preview.relativePath)
                    Spacer()
                    IconButton(symbol: "arrow.up.right.square", label: "Open file in default editor") { NSWorkspace.shared.open(preview.url) }
                }.padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 6)
                NativeCodeView(text: preview.text).frame(maxHeight: .infinity)
                HStack {
                    Text(preview.truncated ? "Preview truncated" : "Read-only preview").font(.system(size: 11)).foregroundStyle(MuseTheme.muted)
                    Spacer()
                    Button("Add to message") { store.mentionFile() }.font(.system(size: 11)).buttonStyle(.bordered).controlSize(.small).accessibilityLabel("Add file to message")
                }.padding(12)
            } else if store.workspace == nil {
                Text("Open a project to inspect its files.").font(.system(size: 12)).foregroundStyle(MuseTheme.muted).padding(20)
            }
        }.frame(maxHeight: .infinity)
    }

}

struct NativeCodeView: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true; scroll.drawsBackground = false; scroll.borderType = .noBorder
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 264, height: 300))
        view.isEditable = false; view.isSelectable = true; view.isRichText = false
        view.drawsBackground = false; view.textColor = NSColor(MuseTheme.secondary)
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 12, height: 10)
        view.isVerticallyResizable = true; view.isHorizontallyResizable = true
        view.autoresizingMask = [.width]
        view.minSize = .zero; view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.containerSize = view.maxSize
        view.textContainer?.widthTracksTextView = false
        view.setAccessibilityLabel("Read-only file contents")
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {
        guard let editor = view.documentView as? NSTextView, editor.string != text else { return }
        editor.string = text
        view.contentView.scroll(to: .zero)
        view.reflectScrolledClipView(view.contentView)
    }
}
