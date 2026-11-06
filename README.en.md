# Notes Markdown

[简体中文](README.md) · English

Type Markdown directly in Apple Notes on macOS. Notes Markdown runs in the menu bar and converts supported syntax to rich text as you type. It's built with Swift and AppKit, with zero third-party dependencies. Conversion runs entirely on your Mac.

[Build from source](#build-and-test) or, if you have a preview ZIP, see the [installation guide in Simplified Chinese](INSTALL.zh-CN.md).

## Usage

1. Open `Notes Markdown.app`.
2. In **System Settings → Privacy & Security → Accessibility**, enable **Notes Markdown**.
3. Open Notes, place the cursor in the note body, and try typing `**hello**`. The markers disappear and **hello** appears in bold.
4. Use the menu bar icon to pause (暂停自动转换), resume (恢复自动转换), or quit (退出 Notes Markdown). Closing the app window leaves it running in the menu bar.

| Input | Trigger | Result in Notes |
| --- | --- | --- |
| `#` | Line start, then Space | Title |
| `##` / `###` | Line start, then Space | Heading / subheading |
| `**bold**` / `__bold__` | Closing marker | Bold |
| `*italic*` / `_italic_` | Closing marker | Italic |
| `***bold italic***` | Closing marker | Bold italic |
| `~~strike~~` | Space after the closing marker | Strikethrough |
| `` `code` `` | Space after the closing backtick | Monospaced text |
| `[Apple](https://apple.com)` | Space after the closing parenthesis | Clickable link |
| `-` | Line start, then Space | Dashed list |
| `*` / `+` | Line start, then Space | Bulleted list |
| `1.` / `1)` | Line start, then Space | Numbered list |
| `[ ]` / `[x]` | Line start, then Space | Unchecked / checked checklist item |
| `>` | Line start, then Space | Block quote |
| Three backticks | Line start, then Space | Monospaced paragraph |

Headings, lists, and checklists use Notes' own formatting commands. Press Return to continue a list. The three-backtick shortcut applies the Monospaced paragraph style. Press ⇧⌘B to return to Body.

Press ⌘Z in Notes to undo a conversion. Paragraph conversions remove the marker and apply formatting in separate steps, so you may need to undo twice. The app recognizes the restored text and skips immediate reconversion.

## Compatibility and limits

- The minimum deployment target is macOS 13. Live typing was verified on macOS 15.3.1 on Apple silicon. Other macOS versions and account types beyond iCloud and On My Mac need separate testing.
- Conversion works as you type in the note body while Notes is the foreground app. Each edit must be a small insertion, and supported syntax fits on a single line.
- Notes saves the result as rich text. For importing existing Markdown files into Notes on macOS Tahoe 26 or later, see [Apple's import guide](https://support.apple.com/en-is/102223).
- The parser aims to preserve escaped markers, Markdown inside code spans, and incomplete syntax. Supported link schemes are `http`, `https`, and `mailto`.

## Accessibility and clipboard

- Accessibility access lets the app read the current note body and send Notes formatting shortcuts. You grant this permission in System Settings.
- The app normally reads up to 2,048 UTF-16 code units before the cursor. If that read fails, it fetches the full note body through Accessibility, then checks its length. It skips processing above 200,000 UTF-16 code units and otherwise extracts the relevant slice.
- Inline conversions briefly use the system clipboard to paste rich text. The app backs up the clipboard first and restores it after Notes receives the paste. If the clipboard changes in the meantime, the newer contents take precedence. The app skips the conversion if it cannot read the clipboard backup or the backup exceeds 16 MiB.
- If the app cannot confirm an edit, it pauses automatic conversion. It processes text locally and records only the length of successfully converted spans in its conversion log.

## Build and test

Use macOS 13 or later and Xcode or the Xcode Command Line Tools with Swift 5.9 or later. Run these commands from the project root.

```sh
swift test
zsh scripts/build.sh
```

The app is built at `dist/Notes Markdown.app`. You can move it to your Applications folder. When updating, quit the running copy from the menu bar and replace it at the same path.

Run `zsh scripts/package.sh --skip-build` to package the existing build as an Apple silicon preview ZIP with a SHA-256 checksum. Run `zsh scripts/package.sh` to rebuild before packaging. The ZIP includes the app, both READMEs, the installation guide, and the license.

The preview is ad hoc signed. Gatekeeper may block downloaded copies on first launch. For installation and checksum steps, see the [installation guide](INSTALL.zh-CN.md).

The AppKit script at `scripts/generate-icon.swift` draws the app icon. The build generates the ICNS file, and `Resources/AppIcon.png` shows the full-size preview.

## Implementation

- `Sources/MarkdownCore/MarkdownRule.swift` recognizes local syntax and reports UTF-16 ranges.
- `Sources/MarkdownCore/EditGate.swift` detects small insertions between editor snapshots.
- `Sources/MarkdownCore/StyledText.swift` builds rich text and preserves font size and typing styles.
- `Sources/NotesMarkdown/Accessibility.swift` identifies the Notes body editor and reads text and cursor position.
- `Sources/NotesMarkdown/EditorTransaction.swift` verifies the snapshot, replaces the marked text, restores the clipboard, and invokes Notes formatting commands.
- `Sources/NotesMarkdown/NotesEngine.swift` observes the editor, polls as a fallback, and handles undo and pause state.
- `Sources/NotesMarkdown/Playground.swift` provides a practice editor that works without Accessibility access.

## License

Released under the [MIT License](LICENSE).
