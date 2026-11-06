import AppKit
import Carbon
import MarkdownCore

private final class ClipboardLease {
    private let board = NSPasteboard.general
    private let saved: [NSPasteboardItem]
    private var ownedCount: Int?

    init?() {
        var copies: [NSPasteboardItem] = []
        var size = 0
        for item in board.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                guard let data = item.data(forType: type) else { return nil }
                size += data.count
                guard size <= 16 * 1024 * 1024 else { return nil }
                copy.setData(data, forType: type)
            }
            copies.append(copy)
        }
        saved = copies
    }

    func write(_ text: NSAttributedString) throws {
        let rtf = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let item = NSPasteboardItem()
        item.setData(rtf, forType: .rtf)
        item.setString(text.string, forType: .string)
        board.clearContents()
        guard board.writeObjects([item]) else {
            ownedCount = board.changeCount
            restore()
            throw NSError(domain: "NotesMarkdown", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法写入临时剪贴板"])
        }
        ownedCount = board.changeCount
    }

    func restore() {
        guard let ownedCount, board.changeCount == ownedCount else { return }
        board.clearContents()
        if !saved.isEmpty { board.writeObjects(saved) }
        self.ownedCount = nil
    }
    deinit { restore() }
}

/// A guarded, localized edit. It never sets AXValue / the entire note body.
final class EditorTransaction {
    private let snapshot: EditorSnapshot
    private let conversion: Conversion
    private var clipboard: ClipboardLease?
    private var attempts = 0
    private var done: ((Result<Bool, Error>) -> Void)?
    private var didMutate = false
    private var typingTraitsToRestore: NSFontTraitMask = []

    init(snapshot: EditorSnapshot, conversion: Conversion) {
        self.snapshot = snapshot
        self.conversion = conversion
    }

    func run(completion: @escaping (Result<Bool, Error>) -> Void) {
        done = completion
        guard let current = NotesAccessibility.snapshot(), current.sameEditor(as: snapshot), current.sample == snapshot.sample else {
            finish(.success(false)); return
        }
        do {
            if case .inline(_, let text, let style) = conversion {
                guard let lease = ClipboardLease() else { throw failure("剪贴板内容较大或无法完整备份，已跳过转换") }
                clipboard = lease
                let attributes = NotesAccessibility.baseAttributes(snapshot.element, range: conversion.range)
                if !text.hasSuffix(" ") {
                    let base = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 17)
                    let traits = NSFontManager.shared.traits(of: base)
                    if [.bold, .boldItalic].contains(style), !traits.contains(.boldFontMask) { typingTraitsToRestore.insert(.boldFontMask) }
                    if [.italic, .boldItalic].contains(style), !traits.contains(.italicFontMask) { typingTraitsToRestore.insert(.italicFontMask) }
                }
                try lease.write(StyledText.inline(text, style: style, base: attributes))
            }
            guard NotesAccessibility.stillFocused(snapshot), NotesAccessibility.setSelection(conversion.range, in: snapshot.element),
                  let selected = NotesAccessibility.selectedRange(snapshot.element), selected.location == conversion.range.location,
                  selected.length == conversion.range.length else {
                throw failure("编辑焦点发生变化，已取消转换")
            }
            switch conversion {
            case .inline:
                sendKey(UInt16(kVK_ANSI_V), flags: .maskCommand)
                // Queue after Paste so the next character keeps the user's original typing traits.
                if typingTraitsToRestore.contains(.boldFontMask) { sendKey(UInt16(kVK_ANSI_B), flags: .maskCommand) }
                if typingTraitsToRestore.contains(.italicFontMask) { sendKey(UInt16(kVK_ANSI_I), flags: .maskCommand) }
            case .paragraph: sendKey(UInt16(kVK_Delete))
            }
            didMutate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { self.verifyReplacement() }
        } catch { finish(.failure(error)) }
    }

    private var replacement: String {
        if case .inline(_, let text, _) = conversion { return text }
        return ""
    }

    private func verifyReplacement() {
        attempts += 1
        let replacementLength = (replacement as NSString).length
        let expectedCount = snapshot.sample.characterCount - conversion.range.length + replacementLength
        let count = NotesAccessibility.attribute(snapshot.element, kAXNumberOfCharactersAttribute) as? Int
        let range = CFRange(location: conversion.range.location, length: replacementLength)
        let inserted = NotesAccessibility.text(snapshot.element, range: range)
        let countMatches: Bool
        if case .inline = conversion { countMatches = (count ?? -1) >= expectedCount }
        else { countMatches = count == expectedCount }
        if countMatches, inserted == replacement {
            clipboard?.restore()
            guard NotesAccessibility.stillFocused(snapshot) else { finish(.success(true)); return }
            let caret = snapshot.sample.caret - conversion.range.length + replacementLength
            // Don't move the user's cursor if they typed or navigated during the transaction.
            guard let selection = NotesAccessibility.selectedRange(snapshot.element), selection.length == 0,
                  selection.location == conversion.range.location + replacementLength, count == expectedCount else {
                finish(.success(true)); return
            }
            guard NotesAccessibility.setSelection(NSRange(location: caret, length: 0), in: snapshot.element) else {
                finish(.failure(failure("已转换文字，光标位置恢复失败"))); return
            }
            if case .paragraph(_, let style) = conversion {
                applyParagraph(style)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { self.finish(.success(true)) }
            } else { finish(.success(true)) }
        } else if attempts < 8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { self.verifyReplacement() }
        } else { finish(.failure(failure("未能确认备忘录已接收转换，自动转换已暂停；请检查当前文字"))) }
    }

    private func applyParagraph(_ style: ParagraphStyle) {
        guard NotesAccessibility.stillFocused(snapshot) else { return }
        let flags: CGEventFlags = [.maskCommand, .maskShift]
        switch style {
        case .title: sendKey(UInt16(kVK_ANSI_T), flags: flags)
        case .heading: sendKey(UInt16(kVK_ANSI_H), flags: flags)
        case .subheading: sendKey(UInt16(kVK_ANSI_J), flags: flags)
        case .bullet: sendKey(UInt16(kVK_ANSI_7), flags: flags)
        case .dash: sendKey(UInt16(kVK_ANSI_8), flags: flags)
        case .numbered: sendKey(UInt16(kVK_ANSI_9), flags: flags)
        case .checklist, .checkedChecklist:
            sendKey(UInt16(kVK_ANSI_L), flags: flags)
            if style == .checkedChecklist {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                    if NotesAccessibility.stillFocused(self.snapshot) { self.sendKey(UInt16(kVK_ANSI_U), flags: flags) }
                }
            }
        case .quote: sendKey(UInt16(kVK_ANSI_Quote), flags: .maskCommand)
        case .monospaced: sendKey(UInt16(kVK_ANSI_M), flags: flags)
        }
    }

    private func sendKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .privateState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.postToPid(snapshot.pid)
        up?.postToPid(snapshot.pid)
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "NotesMarkdown", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func finish(_ result: Result<Bool, Error>) {
        clipboard?.restore()
        if !didMutate, NotesAccessibility.stillFocused(snapshot) {
            _ = NotesAccessibility.setSelection(NSRange(location: snapshot.sample.caret, length: 0), in: snapshot.element)
        }
        let completion = done
        done = nil
        completion?(result)
    }
}
