import AppKit
import SwiftUI
import MarkdownCore

struct Playground: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let text = NSTextView()
        text.isRichText = true
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.allowsUndo = true
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainerInset = NSSize(width: 14, height: 14)
        text.font = NSFont.systemFont(ofSize: 16)
        text.backgroundColor = .textBackgroundColor
        text.delegate = context.coordinator
        text.setAccessibilityIdentifier("markdown-playground")
        text.setAccessibilityLabel("Markdown 试写区")
        scroll.documentView = text
        context.coordinator.previous = EditSample(line: "", lineOffset: 0, caret: 0, characterCount: 0)
        return scroll
    }
    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    final class Coordinator: NSObject, NSTextViewDelegate {
        var previous: EditSample?
        private var applying = false
        private var beforeConversion: EditSample?
        private let rule = MarkdownRule()

        func textDidChange(_ notification: Notification) {
            guard !applying, let text = notification.object as? NSTextView, !text.hasMarkedText(), text.selectedRange().length == 0 else { return }
            let sample = sampleFor(text)
            defer { previous = sampleFor(text) }
            guard let previous, EditGate.isSmallInsertion(from: previous, to: sample), sample != beforeConversion,
                  let conversion = rule.conversion(line: sample.line, offset: sample.lineOffset, insertedAfter: previous.caret) else { return }
            beforeConversion = sample
            applying = true
            defer { applying = false }
            let base = text.typingAttributes
            let replacement: NSAttributedString
            switch conversion {
            case .inline(_, let content, let style): replacement = StyledText.inline(content, style: style, base: base)
            case .paragraph(_, let style):
                let marker: String
                switch style {
                case .bullet: marker = "• "
                case .dash: marker = "– "
                case .numbered: marker = "1. "
                case .checklist: marker = "☐ "
                case .checkedChecklist: marker = "☑ "
                case .quote: marker = "│ "
                default: marker = ""
                }
                replacement = NSAttributedString(string: marker, attributes: StyledText.demoParagraph(style))
            }
            guard text.shouldChangeText(in: conversion.range, replacementString: replacement.string) else { return }
            text.textStorage?.replaceCharacters(in: conversion.range, with: replacement)
            let caret = sample.caret - conversion.range.length + replacement.length
            text.setSelectedRange(NSRange(location: caret, length: 0))
            text.typingAttributes = base
            if case .paragraph(_, let style) = conversion {
                let paragraphRange = (text.string as NSString).paragraphRange(for: NSRange(location: max(0, caret - 1), length: 0))
                text.textStorage?.addAttributes(StyledText.demoParagraph(style), range: paragraphRange)
                text.typingAttributes = StyledText.demoParagraph(style)
            }
            text.didChangeText()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !applying, let text = notification.object as? NSTextView else { return }
            // Selection notifications precede textDidChange during typing. Update only on navigation.
            let sample = sampleFor(text)
            if sample.characterCount == previous?.characterCount { previous = sample }
        }

        private func sampleFor(_ text: NSTextView) -> EditSample {
            let ns = text.string as NSString
            let caret = min(text.selectedRange().location, ns.length)
            let prefix = ns.substring(to: caret) as NSString
            let newline = prefix.rangeOfCharacter(from: .newlines, options: .backwards)
            let offset = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
            return EditSample(line: prefix.substring(from: offset), lineOffset: offset, caret: caret, characterCount: ns.length)
        }
    }
}
