import AppKit
import SwiftUI

struct WelcomeView: View {
    @ObservedObject var engine: NotesEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "note.text").font(.system(size: 32)).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes Markdown").font(.system(size: 27, weight: .bold))
                        Text("苹果备忘录的 Markdown 输入助手").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("自动转换", isOn: $engine.enabled).toggleStyle(.switch).fixedSize()
                }

                HStack {
                    Image(systemName: engine.trusted && engine.enabled ? "checkmark.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(engine.trusted && engine.enabled ? Color.green : Color.orange)
                    Text(engine.status).font(.callout)
                    Spacer()
                    Text("本次已转换 \(engine.conversionCount) 次").font(.caption).foregroundStyle(.secondary)
                }
                .padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                if let error = engine.lastError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("转换已暂停，请先检查当前文字", systemImage: "exclamationmark.triangle")
                            .font(.headline).foregroundStyle(.orange)
                        Text(error).font(.callout).textSelection(.enabled)
                        Text("确认备忘录里的内容后，再恢复自动转换。需要撤销时请在备忘录按 ⌘Z。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("恢复自动转换") { engine.enabled = true }.buttonStyle(.bordered)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                } else if !engine.enabled {
                    Button("恢复自动转换，继续设置") { engine.enabled = true }.buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 10) {
                    stepHeading("1", "开启辅助功能", complete: engine.trusted)
                    Text(engine.trusted ? "权限已开启，可以前往备忘录试写。" : "打开系统设置 → 隐私与安全性 → 辅助功能，开启 Notes Markdown。列表里没有时，点 + 选择应用程序里的 App。")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    if !engine.trusted {
                        Button("打开辅助功能设置") { engine.requestPermission() }.buttonStyle(.borderedProminent)
                        Text("开启后回到这里，权限状态会在几秒内自动更新。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("此权限用于读取当前编辑的备忘录正文、选中文字并调用格式快捷键。行内转换会短暂使用系统剪贴板，完成后恢复。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    stepHeading("2", "完成第一次转换", complete: engine.conversionCount > 0)
                    Text("打开备忘录，新建一条测试笔记。把光标放在正文空行，逐字键入下面的内容。")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: "**你好**").font(.system(.title2, design: .monospaced)).textSelection(.enabled)
                    Text("输入最后两个星号后，星号会消失，文字变成粗体。请逐字输入，整段粘贴会跳过转换。")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("打开苹果备忘录") {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
                            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        }
                    }
                    .buttonStyle(.borderedProminent).disabled(!engine.trusted || !engine.enabled)
                    if engine.conversionCount > 0 {
                        Label("已经成功转换。继续在备忘录里输入即可。", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    stepHeading("3", "学会暂停与撤销", complete: false)
                    Text("屏幕顶部菜单栏 → Notes Markdown 图标 → 暂停自动转换 / 恢复自动转换。关闭这个窗口后，助手继续在菜单栏运行。")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Text("撤销请在备忘录按 ⌘Z。标题和列表会分两步修改，可能需要撤销两次。下次可从菜单栏打开「开始使用与试写」。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }

                DisclosureGroup("没有自动转换？按这里排查") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 确认上方权限已开启，自动转换开关处于开启状态。")
                        Text(verbatim: "• 光标放在苹果备忘录的正文空行，先试 **你好**。")
                        Text("• 逐字键入。标题和列表在行首输入标记后，再按空格。")
                        Text("• 更新 App 后权限失效时，退出 App，在辅助功能列表移除旧条目，再添加应用程序里的新 App。")
                        Text("• 若出现暂停原因，先检查备忘录里的文字，再恢复转换。")
                    }.font(.callout).padding(.top, 10).fixedSize(horizontal: false, vertical: true)
                }

                DisclosureGroup("支持哪些 Markdown 语法？") {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                        syntax("#  /  ##  /  ###", "行首输入后按空格 → 标题")
                        syntax("**粗体**  /  *斜体*", "闭合标记 → 粗体 / 斜体")
                        syntax("~~删除线~~  /  `代码`", "闭合后按空格 → 删除线 / 等宽文字")
                        syntax("[名称](https://example.com)", "闭合后按空格 → 链接")
                        syntax("-  /  *  /  1.", "行首输入后按空格 → 列表")
                        syntax("[ ]  /  [x]", "行首输入后按空格 → 核对清单")
                        syntax(">  /  ```", "行首输入后按空格 → 引用 / 等宽段落")
                    }.padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("也可以先在这里练习").font(.headline)
                    Text(verbatim: "这里无需辅助功能授权。逐字键入 **你好**，或在空行输入 # 再按空格。列表显示为示意符号。")
                        .font(.caption).foregroundStyle(.secondary)
                    Playground().frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                }

                Link("安装说明、完整语法与常见问题", destination: URL(string: "https://sikw-04-27.github.io/notes-markdown/#start")!)
                    .font(.callout)
                Text("内容保存在备忘录中，转换在本机进行。当前支持单行语法和小幅输入。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(26)
        }
        .frame(minWidth: 640, minHeight: 600)
        .onChange(of: engine.enabled) { _ in engine.reset() }
    }

    private func stepHeading(_ number: String, _ title: String, complete: Bool) -> some View {
        HStack(spacing: 9) {
            Text(complete ? "✓" : number).font(.system(.callout, design: .rounded).bold())
                .frame(width: 25, height: 25)
                .background(complete ? Color.green.opacity(0.15) : Color.orange.opacity(0.15), in: Circle())
            Text(title).font(.headline)
            Spacer()
            if complete { Text("已完成").font(.caption).foregroundStyle(.green) }
        }
    }

    @ViewBuilder private func syntax(_ source: String, _ label: String) -> some View {
        GridRow {
            Text(source).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = NotesEngine()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: "退出 Notes Markdown", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.badge.checkmark", accessibilityDescription: "Notes Markdown")
        statusItem.button?.toolTip = "Notes Markdown · 原生备忘录的 Markdown 助手"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        showWindow()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: engine.status, action: nil, keyEquivalent: "")
        menu.addItem(status)
        menu.addItem(.separator())
        addItem(engine.enabled ? "暂停自动转换" : "恢复自动转换", action: #selector(toggle), to: menu)
        addItem("开始使用与试写", action: #selector(showWindow), to: menu)
        if !engine.trusted { addItem("开启辅助功能权限…", action: #selector(permission), to: menu) }
        menu.addItem(.separator())
        addItem("退出 Notes Markdown", action: #selector(quit), to: menu)
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
    @objc private func toggle() { engine.enabled.toggle(); engine.reset() }
    @objc private func permission() { engine.requestPermission() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func showWindow() {
        if window == nil {
            let view = NSHostingView(rootView: WelcomeView(engine: engine))
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 730), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            win.title = "Notes Markdown — 开始使用与试写"
            win.contentView = view
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main enum NotesMarkdownMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
