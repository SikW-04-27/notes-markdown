import Foundation

public enum InlineStyle: Equatable {
    case bold, italic, boldItalic, strike, code, link(URL)
}

public enum ParagraphStyle: Equatable {
    case title, heading, subheading, bullet, dash, numbered, checklist, checkedChecklist, quote, monospaced
}

public enum Conversion: Equatable {
    case inline(range: NSRange, text: String, style: InlineStyle)
    case paragraph(range: NSRange, style: ParagraphStyle)

    public var range: NSRange {
        switch self {
        case .inline(let range, _, _), .paragraph(let range, _): return range
        }
    }
}

/// Ranges use UTF-16, the same units as AppKit and Accessibility. No document rewrite.
public struct MarkdownRule {
    private struct Pattern {
        let regex: NSRegularExpression
        let style: InlineStyle
    }
    private static let patterns: [Pattern] = {
        let specifications: [(String, InlineStyle)] = [
        (#"(?<![\\*])\*\*\*([^*\n]+?)\*\*\*(?: |$)"#, .boldItalic),
        (#"(?<![\\*])\*\*([^*\n]+?)\*\*(?: |$)"#, .bold),
        (#"(?<![\\\p{L}\p{N}_])__([^_\n]+?)__(?: |$)"#, .bold),
        (#"(?<![\\*])\*([^*\n]+?)\*(?: |$)"#, .italic),
        (#"(?<![\\\p{L}\p{N}_])_([^_\n]+?)_(?: |$)"#, .italic),
        (#"(?<![\\~])~~([^~\n]+?)~~ "#, .strike),
        (#"(?<![\\`])`([^`\n]+?)` "#, .code)
        ]
        return specifications.map { Pattern(regex: try! NSRegularExpression(pattern: $0.0), style: $0.1) }
    }()
    private static let link = try! NSRegularExpression(pattern: #"(?<![\\!])\[([^\]\n]+)\]\(([^\s\n)]+)\) "#)
    private static let ordered = try! NSRegularExpression(pattern: #"^1[.)] "#)

    public init() {}

    /// Inspect only the current line before the caret. The caller supplies its absolute offset.
    public func conversion(line: String, offset: Int = 0, insertedAfter: Int = -1) -> Conversion? {
        let prefixStyles: [String: ParagraphStyle] = [
            "# ": .title, "## ": .heading, "### ": .subheading,
            "- ": .dash, "* ": .bullet, "+ ": .bullet,
            "[ ] ": .checklist, "[x] ": .checkedChecklist, "[X] ": .checkedChecklist,
            "- [ ] ": .checklist, "- [x] ": .checkedChecklist,
            "> ": .quote, "``` ": .monospaced
        ]
        let length = (line as NSString).length
        for prefix in prefixStyles.keys.sorted(by: { $0.count > $1.count }) {
            let markerLength = (prefix as NSString).length
            if line.hasPrefix(prefix), offset + markerLength > insertedAfter {
                return .paragraph(range: NSRange(location: offset, length: markerLength), style: prefixStyles[prefix]!)
            }
        }
        if let match = Self.ordered.firstMatch(in: line, range: NSRange(location: 0, length: length)), offset + match.range.length > insertedAfter {
            return .paragraph(range: shifted(match.range, by: offset), style: .numbered)
        }
        // Fence content remains literal until the user switches back to body style.
        if line.hasPrefix("```") { return nil }
        let searchRange = NSRange(location: 0, length: length)
        if let match = Self.link.matches(in: line, range: searchRange).last(where: { offset + NSMaxRange($0.range) > insertedAfter }),
           let labelRange = Range(match.range(at: 1), in: line),
           let urlRange = Range(match.range(at: 2), in: line),
           !hasOpenCodeSpan((line as NSString).substring(to: match.range.location)),
           let url = URL(string: String(line[urlRange])),
           let scheme = url.scheme?.lowercased(), ["https", "http", "mailto"].contains(scheme) {
            return .inline(range: shifted(match.range, by: offset), text: String(line[labelRange]) + " ", style: .link(url))
        }
        for pattern in Self.patterns {
            guard let match = pattern.regex.matches(in: line, range: searchRange).last(where: { offset + NSMaxRange($0.range) > insertedAfter }),
                  let contentRange = Range(match.range(at: 1), in: line) else { continue }
            let content = String(line[contentRange])
            guard !content.hasPrefix(" "), !content.hasSuffix(" ") else { continue }
            // Inline code shields Markdown inside it. Backslash escapes stay untouched.
            let before = (line as NSString).substring(to: match.range.location)
            if hasOpenCodeSpan(before) || isEscaped(line, at: match.range.location) { continue }
            let matched = (line as NSString).substring(with: match.range)
            let boundary = matched.hasSuffix(" ") ? " " : ""
            return .inline(range: shifted(match.range, by: offset), text: content + boundary, style: pattern.style)
        }
        return nil
    }

    private func shifted(_ range: NSRange, by offset: Int) -> NSRange {
        NSRange(location: range.location + offset, length: range.length)
    }

    private func isEscaped(_ text: String, at position: Int) -> Bool {
        let ns = text as NSString
        var index = position - 1
        var count = 0
        while index >= 0, ns.character(at: index) == 92 { count += 1; index -= 1 }
        return count % 2 == 1
    }

    private func hasOpenCodeSpan(_ text: String) -> Bool {
        let ns = text as NSString
        var count = 0
        for index in 0..<ns.length where ns.character(at: index) == 96 {
            if !isEscaped(text, at: index) { count += 1 }
        }
        return count % 2 == 1
    }
}
