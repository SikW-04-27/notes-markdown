import AppKit
import XCTest
@testable import MarkdownCore

final class StyledTextTests: XCTestCase {
    func testBoldKeepsFontSizeAndTrailingSpaceIsPlain() throws {
        let base = NSFont.systemFont(ofSize: 21)
        let output = StyledText.inline("中文 ", style: .bold, base: [.font: base])
        let content = try XCTUnwrap(output.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let space = try XCTUnwrap(output.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(content.pointSize, 21)
        XCTAssertTrue(NSFontManager.shared.traits(of: content).contains(.boldFontMask))
        XCTAssertEqual(space, base)
    }

    func testImmediateBoldFormatsTheLastCharacterToo() throws {
        let output = StyledText.inline("中文", style: .bold, base: [.font: NSFont.systemFont(ofSize: 17)])
        let last = try XCTUnwrap(output.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(NSFontManager.shared.traits(of: last).contains(.boldFontMask))
    }

    func testRTFRoundTripKeepsStrikeAndLinkAndTheirBoundaries() throws {
        for style: InlineStyle in [.strike, .link(URL(string: "https://example.com")!)] {
            let output = StyledText.inline("测试 ", style: style, base: [.font: NSFont.systemFont(ofSize: 17)])
            let data = try output.data(from: NSRange(location: 0, length: output.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            let restored = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            XCTAssertEqual(restored.string, "测试 ")
            if style == .strike {
                XCTAssertEqual(restored.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int, 1)
                XCTAssertNil(restored.attribute(.strikethroughStyle, at: 2, effectiveRange: nil))
            } else {
                XCTAssertNotNil(restored.attribute(.link, at: 0, effectiveRange: nil))
                XCTAssertNil(restored.attribute(.link, at: 2, effectiveRange: nil))
            }
        }
    }
}
