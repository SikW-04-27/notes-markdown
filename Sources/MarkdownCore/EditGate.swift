import Foundation

public struct EditSample: Equatable {
    public let line: String
    public let lineOffset: Int
    public let caret: Int
    public let characterCount: Int

    public init(line: String, lineOffset: Int, caret: Int, characterCount: Int) {
        self.line = line
        self.lineOffset = lineOffset
        self.caret = caret
        self.characterCount = characterCount
    }
}

public enum EditGate {
    /// Cursor navigation, opening old notes, deletes, undo, and large pastes aren't typing.
    public static func isSmallInsertion(from previous: EditSample, to current: EditSample) -> Bool {
        let delta = current.caret - previous.caret
        guard (1...16).contains(delta),
              current.characterCount - previous.characterCount == delta,
              current.lineOffset == previous.lineOffset,
              current.line.hasPrefix(previous.line),
              (current.line as NSString).length - (previous.line as NSString).length == delta else { return false }
        return true
    }
}
