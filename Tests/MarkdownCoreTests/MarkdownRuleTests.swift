import XCTest
@testable import MarkdownCore

final class MarkdownRuleTests: XCTestCase {
    let rule = MarkdownRule()

    func testNativeParagraphs() {
        let examples: [(String, ParagraphStyle, Int)] = [
            ("# 标题", .title, 2), ("## 小标题", .heading, 3), ("### 副标题", .subheading, 4),
            ("- ", .dash, 2), ("* ", .bullet, 2), ("+ ", .bullet, 2), ("1. ", .numbered, 3),
            ("[ ] ", .checklist, 4), ("[x] ", .checkedChecklist, 4), ("- [ ] ", .checklist, 6),
            ("> ", .quote, 2), ("``` ", .monospaced, 4)
        ]
        for (source, style, length) in examples {
            XCTAssertEqual(rule.conversion(line: source, offset: 100), .paragraph(range: NSRange(location: 100, length: length), style: style), source)
        }
    }

    func testInlineStylesWithBoundary() {
        let examples: [(String, String, InlineStyle)] = [
            ("**你好** ", "你好 ", .bold), ("__你好__ ", "你好 ", .bold),
            ("*你好* ", "你好 ", .italic), ("_你好_ ", "你好 ", .italic),
            ("***你好*** ", "你好 ", .boldItalic), ("~~你好~~ ", "你好 ", .strike),
            ("`let x = 1` ", "let x = 1 ", .code)
        ]
        for (source, text, style) in examples {
            XCTAssertEqual(rule.conversion(line: source), .inline(range: NSRange(location: 0, length: (source as NSString).length), text: text, style: style))
        }
        XCTAssertEqual(rule.conversion(line: "**不用按空格**"), .inline(range: NSRange(location: 0, length: 9), text: "不用按空格", style: .bold))
        XCTAssertNil(rule.conversion(line: "~~还没有按空格~~"))
    }

    func testUTF16AndMidlineConversion() {
        let source = "🍎 **中文👨‍👩‍👧‍👦** 后续"
        let ns = source as NSString
        let range = ns.range(of: "**中文👨‍👩‍👧‍👦** ")
        XCTAssertEqual(rule.conversion(line: source, offset: 50, insertedAfter: 58), .inline(range: NSRange(location: 50 + range.location, length: range.length), text: "中文👨‍👩‍👧‍👦 ", style: .bold))
    }

    func testExistingSyntaxIsNotReconverted() {
        XCTAssertNil(rule.conversion(line: "# old title more", insertedAfter: 11))
        XCTAssertNil(rule.conversion(line: "**old** more", insertedAfter: 8))
        XCTAssertEqual(rule.conversion(line: "# old **new** ", insertedAfter: 12), .inline(range: NSRange(location: 6, length: 8), text: "new ", style: .bold))
    }

    func testEscapesCodeAndIncompleteTokensRemainLiteral() {
        for source in [#"\**literal** "#, #"\*literal* "#, "foo_bar_ ", "** ** ", "**incomplete ", "`**literal** ", "`[literal](https://example.com) ", "```**literal** ", "![image](https://example.com) ", "[run](javascript:alert) ", "[local](file:///tmp/a) ", "#### heading "] {
            XCTAssertNil(rule.conversion(line: source), source)
        }
    }

    func testLinkWithoutNetworkAccess() {
        let source = "[苹果](https://apple.com) "
        XCTAssertEqual(rule.conversion(line: source), .inline(range: NSRange(location: 0, length: (source as NSString).length), text: "苹果 ", style: .link(URL(string: "https://apple.com")!)))
    }

    func testTypingGateRejectsNavigationUndoDeleteAndPastes() {
        let before = EditSample(line: "**中文**", lineOffset: 20, caret: 26, characterCount: 50)
        XCTAssertTrue(EditGate.isSmallInsertion(from: before, to: EditSample(line: "**中文** ", lineOffset: 20, caret: 27, characterCount: 51)))
        XCTAssertFalse(EditGate.isSmallInsertion(from: before, to: EditSample(line: "**中文** ", lineOffset: 20, caret: 27, characterCount: 50)))
        XCTAssertFalse(EditGate.isSmallInsertion(from: before, to: EditSample(line: "**中文*", lineOffset: 20, caret: 25, characterCount: 49)))
        XCTAssertFalse(EditGate.isSmallInsertion(from: before, to: EditSample(line: "other note ", lineOffset: 20, caret: 27, characterCount: 51)))
        XCTAssertFalse(EditGate.isSmallInsertion(from: before, to: EditSample(line: "**中文** " + String(repeating: "a", count: 100), lineOffset: 20, caret: 127, characterCount: 151)))
    }
}
