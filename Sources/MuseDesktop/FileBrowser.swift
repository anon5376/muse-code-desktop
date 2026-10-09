// FileBrowser: workspace file tree for the Files inspector — hidden files,
// symlinks, and heavy dependency dirs excluded by policy.
import Foundation

/// A node in the workspace file tree (directory or file, lazily loaded).
struct FileNode: Identifiable, Sendable {
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

/// Bounded read-only preview: text capped at 256 KiB, hidden files and
/// symlinks skipped.
struct FilePreview: Sendable {
    let url: URL
    let relativePath: String
    let text: String
    let truncated: Bool
}

/// Workspace scanning for the Files tab — read-only, bounded, and
/// never follows symlinks or hidden entries.
enum FileBrowser {
    static let omitted = Set(["node_modules", "build", "dist", "target", "Pods", "__pycache__", "vendor"])

    static func scan(_ root: URL) throws -> [FileNode] {
        var remaining = 2_000
        func walk(_ folder: URL, depth: Int) throws -> [FileNode] {
            guard depth < 6, remaining > 0 else { return [] }
            let urls = try FileManager.default.contentsOfDirectory(at: folder,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
            var nodes: [FileNode] = []
            for url in urls {
                guard remaining > 0 else { break }
                guard !omitted.contains(url.lastPathComponent),
                      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]), values.isSymbolicLink != true else { continue }
                remaining -= 1
                let directory = values.isDirectory == true
                let children = directory ? ((try? walk(url, depth: depth + 1)) ?? []) : nil
                nodes.append(FileNode(url: url, isDirectory: directory, children: children))
            }
            return nodes.sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
        return try walk(root, depth: 0)
    }

    static func preview(_ url: URL, in root: URL) throws -> FilePreview {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let base = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolved.path.hasPrefix(base + "/"),
              try resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw CocoaError(.fileReadNoPermission)
        }
        let handle = try FileHandle(forReadingFrom: resolved)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 256 * 1_024 + 1) ?? Data()
        let truncated = data.count > 256 * 1_024
        let content = Data(data.prefix(256 * 1_024))
        guard !content.contains(0) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        // A byte limit may split the last scalar; replacement is limited to that
        // final fragment, while unsupported/binary files remain rejected.
        guard String(data: content, encoding: .utf8) != nil || (truncated && String(data: content.dropLast(4), encoding: .utf8) != nil) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return FilePreview(url: resolved, relativePath: String(resolved.path.dropFirst(base.count + 1)),
            text: String(decoding: content, as: UTF8.self), truncated: truncated)
    }
}
