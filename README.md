# Notes Markdown

简体中文 · [English](README.en.md)

在 macOS 原生备忘录里输入 Markdown，自动转换为备忘录的原生富文本。使用 Swift 和 AppKit 开发，驻留在菜单栏，无第三方依赖和网络请求。

可按下方步骤[从源码构建](#构建与测试)。如果手头有预览 ZIP，参见[安装说明](INSTALL.zh-CN.md)。

## 使用

1. 打开构建或安装好的 `Notes Markdown.app`。
2. 首次使用，在「系统设置 → 隐私与安全性 → 辅助功能」开启 Notes Markdown。
3. 切换到备忘录，将光标放在正文，输入下面的语法。
4. 菜单栏「Notes Markdown」图标可暂停、恢复或退出助手。关闭说明窗口后仍会运行。

| 输入 | 触发时机 | 原生备忘录中的结果 |
| --- | --- | --- |
| `# ` | 行首，空格 | 标题 |
| `## ` / `### ` | 行首，空格 | 小标题 / 副标题 |
| `**粗体**` / `__粗体__` | 闭合标记 | 粗体 |
| `*斜体*` / `_斜体_` | 闭合标记 | 斜体 |
| `***粗斜体***` | 闭合标记 | 粗体加斜体 |
| `~~删除线~~ ` | 闭合后空格 | 删除线 |
| `` `代码` `` 后接空格 | 闭合后空格 | 等宽字体 |
| `[苹果](https://apple.com) ` | 闭合后空格 | 可点击链接 |
| `- ` | 行首，空格 | 短划线列表 |
| `* ` / `+ ` | 行首，空格 | 项目符号列表 |
| `1. ` / `1) ` | 行首，空格 | 编号列表 |
| `[ ] ` / `[x] ` | 行首，空格 | 未勾选 / 已勾选的原生核对清单 |
| `> ` | 行首，空格 | 原生块引用 |
| 三个反引号后接空格 | 行首，空格 | 原生等宽段落 |

标题、列表和核对清单使用备忘录自己的格式命令，因此列表的回车续写由备忘录负责。等宽段落不是围栏代码块；回到正文可以按 ⇧⌘B。

撤销使用备忘录的 ⌘Z。段落的「移除标记」和「应用原生格式」是两步，可能需要撤销两次。助手会识别恢复的原文，避免立刻再次转换。

## 当前边界

- 属于输入语法转换助手，不是完整的 Typora 编辑器；转换后存储的是备忘录原生富文本。
- 支持 macOS 13 以上构建；实际设备验证环境为 macOS 15.3.1。其他系统版本和非 iCloud / 本机账户需要另行验证。
- 只处理前台 `com.apple.Notes` 应用里标识为 `Note Body Text View` 的正文编辑区，不处理搜索框、其他应用或既有笔记的自动批量转换。
- 默认读取光标前最多 2048 个 UTF-16 单元。如果局部读取失败，应用会从辅助功能接口读取整篇正文。正文超过 200,000 个 UTF-16 单元时跳过处理，否则只提取光标附近需要的片段。
- 转换触发需要采样之间有小幅文本插入。大段粘贴、跨行语法、嵌套 Markdown、表格、图片、脚注、公式和语法高亮不在此版本范围内。
- 反斜杠转义、代码内的 Markdown、未闭合标记尽量保持原文。仅允许 `http`、`https`、`mailto` 链接。
- 行内转换短暂使用系统剪贴板。会先完整备份并在备忘录接收后恢复；如果期间出现新的剪贴板内容，则保留新内容。备份超过 16 MiB 或不可读取时跳过转换。
- 如果转换不能被确认，应用暂停并显示原因。没有日志上传、笔记落盘或全局键盘监听。
- 使用辅助功能读取文本并发送备忘录格式快捷键；系统权限由用户开启，不修改 TCC 数据库或系统安全设置。
- 预览应用使用 ad hoc 签名，尚未经过 Apple 公证；转发给其他人后可能被 macOS 拦截，安装者需自行确认是否信任该文件。正式签名与公证完成前，按测试包分发。

## 构建与测试

需要 macOS 13 或以上，以及提供 Swift 5.9 或以上版本的 Xcode 或 Xcode Command Line Tools。在项目根目录运行：

```sh
swift test
zsh scripts/build.sh
```

产物位于 `dist/Notes Markdown.app`。可复制到个人 Applications 文件夹；更新前先从菜单栏退出旧版本，保持安装路径不变。

如需生成 Apple 芯片预览 ZIP 和 SHA-256 校验文件，运行 `zsh scripts/package.sh --skip-build`。省略 `--skip-build` 时会先重新构建。ZIP 包含 App、安装说明、中英文 README 和许可证。

应用图标由 `scripts/generate-icon.swift` 使用 AppKit 绘制，构建时生成完整尺寸的 ICNS；可编辑这个源文件调整配色与形状。预览图为 `Resources/AppIcon.png`。

## 实现

- `MarkdownCore/MarkdownRule.swift`：局部语法识别，使用 UTF-16 范围。
- `MarkdownCore/EditGate.swift`：区分小幅输入、移动光标、删除与大段粘贴。
- `MarkdownCore/StyledText.swift`：生成保留字号及后续输入样式的富文本。
- `NotesMarkdown/Accessibility.swift`：限定备忘录正文、读取局部文本与光标。
- `NotesMarkdown/EditorTransaction.swift`：验证输入快照，局部替换，恢复剪贴板，调用原生格式。
- `NotesMarkdown/NotesEngine.swift`：前台限定的辅助功能事件订阅、轮询兜底、撤销抑制与暂停状态。
- `NotesMarkdown/Playground.swift`：无需辅助功能授权的内置试写区。

API 和格式命令参考：[Apple 的备忘录快捷键](https://support.apple.com/guide/notes/keyboard-shortcuts-and-gestures-apd46c25187e/mac)、[Accessibility 信任检查](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)、[NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)。macOS 26 的原生 Markdown 文件导入导出与本工具的输入时转换是两个流程，参见 [Apple 导入说明](https://support.apple.com/en-is/102223)。

## 许可证

本项目使用 [MIT 许可证](LICENSE)。
