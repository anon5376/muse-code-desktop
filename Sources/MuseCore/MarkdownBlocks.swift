// Structural Markdown splitter feeding the transcript renderer — block
// boundaries only; inline markup is left to the view.
import Foundation

// A bounded native presentation parser, not an HTML renderer. Inline syntax
// remains Foundation's job; these blocks supply the missing desktop layout.
/// A single rendered unit of assistant markdown.
///
/// The transcript renders a list of blocks top-to-bottom; `.partial` marks a
/// trailing block that is still being streamed and may grow with the next delta.
public enum MarkdownBlock: Equatable, Sendable {
    case paragraph(String), partial(String), heading(level: Int, text: String)
    case listItem(marker: String, text: String, indent: Int), quote(String)
    case code(language: String, text: String), table(headers: [String], rows: [[String]]), rule
}

/// Line-oriented Markdown splitter for transcript text.
///
/// This is deliberately a structural splitter, not a full Markdown parser: it
/// recognizes the block shapes the assistant actually emits (headings, ` ``` `
/// and `~~~` fences, lists, quotes, tables, rules) and leaves inline markup
/// untouched.
public enum MarkdownBlocks {
    /// Splits `text` into blocks. With `isStreaming`, an unterminated trailing
    /// region (no final newline) becomes `.partial` instead of a stable block,
    /// so completed blocks stay stable while the tail keeps updating.
    public static func parse(_ text: String, isStreaming: Bool = false) -> [MarkdownBlock] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = [], index = 0
        func trim(_ line: String) -> String { line.trimmingCharacters(in: .whitespaces) }
        func isPartial(_ end: Int) -> Bool { isStreaming && end >= lines.count && !text.hasSuffix("\n") }
        while index < lines.count {
            let line = lines[index], clean = trim(line)
            if clean.isEmpty { index += 1; continue }
            if let fence = fence(clean) {
                let start = index
                index += 1
                var code: [String] = []
                while index < lines.count {
                    let candidate = trim(lines[index])
                    if candidate.prefix(while: { $0 == fence.character }).count >= fence.count,
                       candidate.drop(while: { $0 == fence.character }).trimmingCharacters(in: .whitespaces).isEmpty { break }
                    code.append(lines[index]); index += 1
                }
                if index < lines.count {
                    blocks.append(.code(language: fence.language, text: code.joined(separator: "\n"))); index += 1
                } else if isStreaming {
                    blocks.append(.partial(lines[start...].joined(separator: "\n")))
                } else { blocks.append(.code(language: fence.language, text: code.joined(separator: "\n"))) }
                continue
            }
            if index + 1 < lines.count, clean.contains("|"), tableDivider(lines[index + 1]) {
                let headers = cells(clean)
                index += 2
                var rows: [[String]] = []
                while index < lines.count, lines[index].contains("|"), !trim(lines[index]).isEmpty {
                    if isPartial(index + 1) { break }
                    rows.append(cells(lines[index])); index += 1
                }
                blocks.append(.table(headers: headers, rows: rows)); continue
            }
            if let heading = heading(clean) {
                blocks.append(isPartial(index + 1) ? .partial(line) : .heading(level: heading.level, text: heading.text))
                index += 1; continue
            }
            if rule(clean) { blocks.append(.rule); index += 1; continue }
            if let item = listItem(line) {
                blocks.append(isPartial(index + 1) ? .partial(line) : .listItem(marker: item.marker, text: item.text, indent: item.indent))
                index += 1; continue
            }
            if clean.hasPrefix(">") {
                var quote: [String] = []
                while index < lines.count, trim(lines[index]).hasPrefix(">") {
                    quote.append(String(trim(lines[index]).dropFirst()).trimmingCharacters(in: .whitespaces)); index += 1
                }
                blocks.append(.quote(quote.joined(separator: "\n"))); continue
            }
            var paragraph: [String] = [line]
            index += 1
            while index < lines.count {
                let next = trim(lines[index])
                if next.isEmpty || heading(next) != nil || fence(next) != nil || rule(next) || listItem(lines[index]) != nil || next.hasPrefix(">") { break }
                if index + 1 < lines.count, next.contains("|"), tableDivider(lines[index + 1]) { break }
                paragraph.append(lines[index]); index += 1
            }
            let body = paragraph.joined(separator: "\n")
            blocks.append(isPartial(index) ? .partial(body) : .paragraph(body))
        }
        return blocks
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level), line.dropFirst(level).first?.isWhitespace == true else { return nil }
        return (level, String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces))
    }
    private static func fence(_ line: String) -> (character: Character, count: Int, language: String)? {
        guard let character = line.first, character == "`" || character == "~" else { return nil }
        let count = line.prefix(while: { $0 == character }).count
        guard count >= 3 else { return nil }
        return (character, count, String(line.dropFirst(count)).trimmingCharacters(in: .whitespaces))
    }
    private static func listItem(_ line: String) -> (marker: String, text: String, indent: Int)? {
        let indent = line.prefix(while: { $0 == " " }).count / 2
        let clean = line.trimmingCharacters(in: .whitespaces)
        if let first = clean.first, "-*+".contains(first), clean.dropFirst().first?.isWhitespace == true {
            return ("•", String(clean.dropFirst(2)), indent)
        }
        let digits = clean.prefix(while: { $0.isNumber })
        let rest = clean.dropFirst(digits.count)
        guard !digits.isEmpty, let punctuation = rest.first, ".)".contains(punctuation), rest.dropFirst().first?.isWhitespace == true else { return nil }
        return (String(digits) + String(punctuation), String(rest.dropFirst(2)), indent)
    }
    private static func rule(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        return compact.count >= 3 && ["-", "*", "_"].contains { marker in compact.allSatisfy { String($0) == marker } }
    }
    private static func cells(_ line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        return value.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    private static func tableDivider(_ line: String) -> Bool {
        let values = cells(line)
        return !values.isEmpty && values.allSatisfy {
            let dash = $0.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return dash.count >= 3 && dash.allSatisfy { $0 == "-" }
        }
    }
}
