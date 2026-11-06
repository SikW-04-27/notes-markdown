import AppKit
import ApplicationServices
import MarkdownCore

struct EditorSnapshot {
    let element: AXUIElement
    let pid: pid_t
    let sample: EditSample

    func sameEditor(as other: EditorSnapshot) -> Bool { pid == other.pid && CFEqual(element, other.element) }
}

enum NotesAccessibility {
    static let bundleID = "com.apple.Notes"

    static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }

    static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let raw = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(raw as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    static func setSelection(_ range: NSRange, in element: AXUIElement) -> Bool {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let value = AXValueCreate(.cfRange, &cfRange) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success
    }

    static func text(_ element: AXUIElement, range: CFRange) -> String? {
        var range = range
        guard let value = AXValueCreate(.cfRange, &range) else { return nil }
        var raw: CFTypeRef?
        if AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, value, &raw) == .success {
            return raw as? String
        }
        // Some Notes builds don't expose range reads. Bound the fallback to modest notes.
        guard let all = attribute(element, kAXValueAttribute) as? String,
              (all as NSString).length <= 200_000,
              range.location >= 0, range.location + range.length <= (all as NSString).length else { return nil }
        return (all as NSString).substring(with: NSRange(location: range.location, length: range.length))
    }

    static func baseAttributes(_ element: AXUIElement, range: NSRange) -> [NSAttributedString.Key: Any] {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let value = AXValueCreate(.cfRange, &cfRange) else { return [:] }
        var raw: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXAttributedStringForRangeParameterizedAttribute as CFString, value, &raw) == .success,
              let attributed = raw as? NSAttributedString, attributed.length > 0 else { return [:] }
        var attributes = attributed.attributes(at: 0, effectiveRange: nil)
        // Accessibility emits AXFont dictionaries rather than AppKit's NSFont key.
        let axFont = attributes[NSAttributedString.Key(kAXFontTextAttribute.takeUnretainedValue() as String)] as? [String: Any]
        if attributes[.font] == nil, let axFont {
            let size = (axFont[kAXFontSizeKey.takeUnretainedValue() as String] as? NSNumber)?.doubleValue ?? 17
            if let name = axFont[kAXFontNameKey.takeUnretainedValue() as String] as? String, let font = NSFont(name: name, size: size) {
                attributes[.font] = font
            } else { attributes[.font] = NSFont.systemFont(ofSize: size) }
        }
        return attributes
    }

    static func snapshot() -> EditorSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == bundleID else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.15)
        guard let raw = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let element = raw as! AXUIElement
        var focusedPID: pid_t = 0
        guard AXUIElementGetPid(element, &focusedPID) == .success, focusedPID == app.processIdentifier else { return nil }
        guard attribute(element, kAXRoleAttribute) as? String == kAXTextAreaRole,
              attribute(element, kAXIdentifierAttribute) as? String == "Note Body Text View",
              let selection = selectedRange(element), selection.length == 0, selection.location >= 0,
              let count = attribute(element, kAXNumberOfCharactersAttribute) as? Int,
              selection.location <= count else { return nil }
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success, settable.boolValue else { return nil }
        let start = max(0, selection.location - 2048)
        guard let chunk = text(element, range: CFRange(location: start, length: selection.location - start)) else { return nil }
        let ns = chunk as NSString
        let newline = ns.rangeOfCharacter(from: .newlines, options: .backwards)
        // Skip truncated long lines rather than mistaking the window boundary for a line start.
        guard start == 0 || newline.location != NSNotFound else { return nil }
        let lineStart = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        let line = ns.substring(from: lineStart)
        return EditorSnapshot(element: element, pid: app.processIdentifier, sample: EditSample(
            line: line, lineOffset: start + lineStart, caret: selection.location, characterCount: count
        ))
    }

    static func stillFocused(_ snapshot: EditorSnapshot) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid,
              let raw = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) else { return false }
        return CFEqual(raw, snapshot.element)
    }
}
