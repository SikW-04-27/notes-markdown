# Install and use Notes Markdown

[简体中文](INSTALL.zh-CN.md) · English

For Apple silicon Macs with macOS 13 or later. Live typing has been verified on macOS 15.3.1. This free preview uses ad hoc signing and is awaiting Developer ID signing and Apple notarization.

## 1. Download and install

1. Download `Notes-Markdown-0.1.2-arm64-preview.zip` from the [v0.1.2 release](https://github.com/SikW-04-27/notes-markdown/releases/tag/v0.1.2).
2. Unzip the download and open **00-先读我-START-HERE.html** in a browser for the offline guide.
3. Move **Notes Markdown.app** to **Applications** in Finder.
4. Open the app from Applications. After the macOS first-launch confirmation, a setup window opens and a Notes Markdown icon appears in the menu bar.

The ZIP contains the ready-to-run app. GitHub's Source code downloads are for building the app yourself. The app interface is currently in Simplified Chinese. The labels below match the interface.

### If macOS blocks the first launch

If macOS says the developer cannot be verified or Apple cannot check the app, verify its source and integrity first. If you trust the download, follow these steps.

1. Choose **Done** in the alert to keep the app.
2. Open **System Settings → Privacy & Security** and scroll down to Security.
3. Find the message about Notes Markdown being blocked and click **Open Anyway**.
4. Authenticate as requested and confirm **Open**. The app's setup window will appear.

If the button is missing, try opening the app from Applications again, choose Done, and return to Privacy & Security. [Illustrated first-launch guide](https://sikw-04-27.github.io/notes-markdown/start.html#english) · [Apple's opening instructions](https://support.apple.com/en-us/102445)

If macOS reports known malware, damage, or that the app will damage your computer, stop opening it and check the source and checksum. A managed Mac may require an administrator's approval.

## 2. Grant Accessibility access

1. Click **打开辅助功能设置** (Open Accessibility Settings) in the setup window.
2. Enable **Notes Markdown** under **System Settings → Privacy & Security → Accessibility**.
3. If the app is missing, click **+** and select **Notes Markdown.app** in Applications.
4. Return to setup. The permission status updates within a few seconds, and step 1 shows **已完成** (Completed).

Accessibility access lets the app read the current note body, select a local span, and send formatting shortcuts to Notes. Inline conversions briefly use the system clipboard and restore it afterward. Text is processed locally. [Apple's Accessibility guide](https://support.apple.com/guide/mac-help/mh43185/mac)

## 3. Try your first conversion

1. Enable **自动转换** (Automatic conversion) at the top of setup, then click **打开苹果备忘录** (Open Apple Notes).
2. Create a test note and place the cursor on a blank line in the **note body**.
3. Type `**hello**` character by character. After the closing stars, the markers disappear and the word becomes bold.
4. On another blank line, type `#` followed by Space to create a title.

Type the example character by character. Bulk pastes skip conversion. For headings, lists, and checklists, type the marker at the start of a line and then press Space. See the [syntax table](README.en.md#usage).

You can also practice in the setup window's editor. This editor works without Accessibility permission and displays lists using illustrative symbols.

## 4. Pause, undo, and reopen setup

- The app stays in the menu bar after you close setup. Choose **开始使用与试写** (Setup and practice) from its menu to reopen the guide.
- Choose **暂停自动转换** (Pause) or **恢复自动转换** (Resume) to control conversion. Launch the app manually when you want to use it.
- Press **⌘Z** in Notes to undo. Paragraph conversions remove a marker and apply formatting in separate steps, so you may need to undo twice.
- If an edit fails, the app pauses and keeps the reason visible in setup. Check your current text before resuming.

## Troubleshooting

| What you see | What to try |
| --- | --- |
| Text stays unchanged | Check Accessibility and the Automatic conversion switch. Type `**hello**` on a blank line in the Apple Notes body. |
| A heading or list stays plain | Start the marker at the beginning of the line, then press Space. |
| The cursor is in Search or the note title | Move to a blank line in the note body. |
| The setup window has disappeared | Open the Notes Markdown icon in the macOS menu bar. |
| Permissions stop working after an update | Quit the app, remove its old Accessibility entry, add the new app from Applications, and reopen it. |
| A clipboard backup error appears | Copy a short piece of plain text, check the current note, and resume conversion. |
| Another macOS version or account behaves differently | Reproduce with sample text and report the macOS version, chip, steps, and app message in [Issues](https://github.com/SikW-04-27/notes-markdown/issues/new). |

## Verify the download

Put the ZIP and `.sha256` file in the same folder and run this command there. An `OK` result confirms that the archive matches the published checksum.

```sh
shasum -a 256 -c Notes-Markdown-0.1.2-arm64-preview.zip.sha256
```

## Update or uninstall

To update, quit from the menu bar and replace the app in Applications at the same path. macOS may ask you to grant Accessibility access again.

To uninstall, quit the app, move it to the Trash, and remove its Accessibility entry. Notes keeps text that was already converted.
