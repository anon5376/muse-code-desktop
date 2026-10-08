import SwiftUI
import AppKit
import MuseCore

struct MarkdownBody: View {
    let text: String
    var isStreaming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(MarkdownBlocks.parse(text, isStreaming: isStreaming).enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).tint(MuseTheme.accent)
    }

    @ViewBuilder private func render(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text): inline(text).font(.system(size: 14)).lineSpacing(7)
        case .partial(let text): Text(text).font(.system(size: 14)).lineSpacing(7)
        case .heading(let level, let text):
            inline(text).font(.system(size: level == 1 ? 20 : level == 2 ? 17 : 14, weight: .semibold)).padding(.top, 4)
        case .listItem(let marker, let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker).foregroundStyle(MuseTheme.secondary).frame(minWidth: 18, alignment: .trailing)
                inline(text).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.system(size: 14)).lineSpacing(7).padding(.leading, CGFloat(min(indent, 6) * 16))
        case .quote(let text):
            HStack(spacing: 12) {
                Rectangle().fill(MuseTheme.stroke).frame(width: 3)
                inline(text).font(.system(size: 14)).lineSpacing(7).foregroundStyle(MuseTheme.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }.fixedSize(horizontal: false, vertical: true)
        case .code(let language, let text):
            VStack(spacing: 0) {
                HStack {
                    Text(language.isEmpty ? "Code" : String(language.prefix(32))).font(.system(size: 11, design: .monospaced)).foregroundStyle(MuseTheme.secondary)
                    Spacer()
                    Button { copy(text) } label: { Label("Copy", systemImage: "doc.on.doc").font(.system(size: 11)) }
                        .buttonStyle(.plain).foregroundStyle(MuseTheme.secondary).accessibilityLabel("Copy code")
                }.padding(.horizontal, 12).padding(.vertical, 8)
                Hairline()
                ScrollView(.horizontal) {
                    Text(text).font(.system(size: 12, design: .monospaced)).lineSpacing(6).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.background(MuseTheme.sidebar, in: RoundedRectangle(cornerRadius: 8))
        case .table(let headers, let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in
                            inline(cell).font(.system(size: 12, weight: .semibold)).padding(10).frame(minWidth: 100, alignment: .leading)
                        }
                    }.background(MuseTheme.raised)
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        GridRow {
                            ForEach(headers.indices, id: \.self) { column in
                                inline(column < row.count ? row[column] : "").font(.system(size: 12)).padding(10).frame(minWidth: 100, alignment: .leading)
                            }
                        }.background(index.isMultiple(of: 2) ? Color.clear : MuseTheme.raised.opacity(0.5))
                    }
                }.overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(MuseTheme.stroke))
            }
        case .rule: Hairline().padding(.vertical, 4)
        }
    }

    private func inline(_ text: String) -> Text {
        Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
    }
    private func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
}
