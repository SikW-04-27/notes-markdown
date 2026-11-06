import AppKit
import SwiftUI

struct WelcomeView: View {
    @ObservedObject var engine: NotesEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "note.text").font(.system(size: 34)).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes Markdown").font(.system(size: 28, weight: .bold))
                        Text("在苹果备忘录里，用 Markdown 写作。").font(.title3).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("自动转换", isOn: $engine.enabled).toggleStyle(.switch).fixedSize()
                }
                HStack {
                    Circle().fill(engine.trusted && engine.enabled ? Color.green : Color.orange).frame(width: 8, height: 8)
                    Text(engine.status).font(.callout)
                    Spacer()
                    Text("已转换 \(engine.conversionCount) 次").font(.caption).foregroundStyle(.secondary)
                }
                .padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                if !engine.trusted {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("首次使用：开启辅助功能权限").font(.headline)
                        Text("系统设置 → 隐私与安全性 → 辅助功能，开启 Notes Markdown。助手需要读取当前编辑行并调用备忘录的格式命令，授权后会自动就绪。")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button("打开辅助功能设置") { engine.requestPermission() }.buttonStyle(.borderedProminent)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("怎么写").font(.headline)
                    Text("标题和列表：行首输入语法，再按空格。\n粗体、斜体：闭合标记后自动转换。其他行内样式：闭合后按空格。")
                        .font(.callout).foregroundStyle(.secondary)
                    Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 8) {
                        syntax("# ", "标题")
                        syntax("##  /  ### ", "小标题 / 副标题")
                        syntax("**粗体** ", "粗体")
                        syntax("*斜体*  /  ~~删除线~~ ", "斜体 / 删除线")
                        syntax("`代码`  /  [名称](https://…)", "等宽文本 / 链接")
                        syntax("-  /  *  /  1. ", "短划线 / 项目符号 / 编号列表")
                        syntax("[ ]  /  [x] ", "原生核对清单 / 已勾选项目")
                        syntax(">  /  ``` ", "引用 / 等宽段落")
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("先在这里试写").font(.headline)
                    Text(verbatim: "输入 **你好** 会自动变成粗体，或在空行输入 # 再按空格。这里无需授权；列表在试写区显示为示意符号。")
                        .font(.caption).foregroundStyle(.secondary)
                    Playground().frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                }

                HStack {
                    Button("打开备忘录") {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
                            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        }
                    }.buttonStyle(.borderedProminent)
                    Text("关闭此窗口后，助手仍在菜单栏运行。").font(.caption).foregroundStyle(.secondary)
                }
                Text("本地处理 · 只在备忘录正文输入时工作 · 菜单栏可随时暂停\n暂不处理表格、图片、嵌套 Markdown 或整篇粘贴。转换后可用备忘录的 ⌘Z 撤销；段落格式可能需要撤销两次。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
        }
        .frame(minWidth: 660, minHeight: 760)
        .onChange(of: engine.enabled) { _ in engine.reset() }
    }

    @ViewBuilder private func syntax(_ source: String, _ label: String) -> some View {
        GridRow {
            Text(source).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
            Text(label).font(.callout).foregroundStyle(.secondary)
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
        addItem("使用说明与试写", action: #selector(showWindow), to: menu)
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
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 690, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            win.title = "Notes Markdown — 使用说明与试写"
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
