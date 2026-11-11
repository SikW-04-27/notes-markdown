import AppKit

public enum StyledText {
    public static func inline(_ text: String, style: InlineStyle, base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var original = base
        // AX may expose nonstandard text attributes; emit only those AppKit can serialize.
        original = original.filter { [.font, .foregroundColor, .paragraphStyle, .backgroundColor].contains($0.key) }
        let font = original[.font] as? NSFont ?? NSFont.systemFont(ofSize: 17)
        original[.font] = font
        var formatted = original
        switch style {
        case .bold: formatted[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        case .italic: formatted[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        case .boldItalic: formatted[.font] = NSFontManager.shared.convert(font, toHaveTrait: [.boldFontMask, .italicFontMask])
        case .strike: formatted[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        case .code: formatted[.font] = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        case .link(let url): formatted[.link] = url
        }
        let result = NSMutableAttributedString(string: text, attributes: original)
        // The trailing trigger space preserves the original typing style after the span.
        let contentLength = max(0, (text as NSString).length - (text.hasSuffix(" ") ? 1 : 0))
        result.addAttributes(formatted, range: NSRange(location: 0, length: contentLength))
        return result
    }

    public static func demoParagraph(_ style: ParagraphStyle) -> [NSAttributedString.Key: Any] {
        let font: NSFont
        switch style {
        case .title: font = NSFont.systemFont(ofSize: 28, weight: .bold)
        case .heading: font = NSFont.systemFont(ofSize: 22, weight: .bold)
        case .subheading: font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        case .monospaced: font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        default: font = NSFont.systemFont(ofSize: 16)
        }
        return [.font: font, .foregroundColor: NSColor.textColor]
    }
}
