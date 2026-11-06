import AppKit
import ApplicationServices
import MarkdownCore
import os

final class NotesEngine: ObservableObject {
    @Published var enabled = UserDefaults.standard.object(forKey: "automaticConversionEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "automaticConversionEnabled") }
    }
    @Published private(set) var trusted = false
    @Published private(set) var status = "等待辅助功能权限"
    @Published private(set) var conversionCount = 0
    private let rule = MarkdownRule()
    private var timer: Timer?
    private var baseline: EditorSnapshot?
    private var beforeLastConversion: EditorSnapshot?
    private var transaction: EditorTransaction?
    private var lastTrustCheck = Date.distantPast
    private var observer: AXObserver?
    private var observedPID: pid_t?
    private var observedEditor: AXUIElement?
    private var pendingNotification: DispatchWorkItem?
    private let logger = Logger(subsystem: "local.notes-markdown.app", category: "conversion")

    init() {
        trusted = AXIsProcessTrusted()
        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.04
    }

    func reset() { baseline = nil; beforeLastConversion = nil }

    private func observe(_ current: EditorSnapshot) {
        if observedPID != current.pid {
            if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
            observer = nil
            observedEditor = nil
            observedPID = current.pid
            var created: AXObserver?
            let callback: AXObserverCallback = { _, _, _, context in
                guard let context else { return }
                Unmanaged<NotesEngine>.fromOpaque(context).takeUnretainedValue().scheduleFromNotification()
            }
            if AXObserverCreate(current.pid, callback, &created) == .success, let created {
                observer = created
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
                AXObserverAddNotification(created, AXUIElementCreateApplication(current.pid), kAXFocusedUIElementChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
            }
        }
        guard let observer, observedEditor.map({ CFEqual($0, current.element) }) != true else { return }
        if let old = observedEditor {
            AXObserverRemoveNotification(observer, old, kAXValueChangedNotification as CFString)
            AXObserverRemoveNotification(observer, old, kAXSelectedTextChangedNotification as CFString)
        }
        observedEditor = current.element
        AXObserverAddNotification(observer, current.element, kAXValueChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(observer, current.element, kAXSelectedTextChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
    }

    private func scheduleFromNotification() {
        // Text and caret notifications arrive separately. Let AppKit finish the edit first.
        pendingNotification?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.tick() }
        pendingNotification = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012, execute: work)
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func tick() {
        if Date().timeIntervalSince(lastTrustCheck) >= 2 {
            trusted = AXIsProcessTrusted()
            lastTrustCheck = Date()
        }
        guard transaction == nil else { return }
        guard enabled else { baseline = nil; setStatus("自动转换已暂停"); return }
        guard trusted else { baseline = nil; setStatus("等待辅助功能权限"); return }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == NotesAccessibility.bundleID else {
            baseline = nil; setStatus("已就绪 · 切换到备忘录开始输入"); return
        }
        let modifiers = CGEventSource.flagsState(.combinedSessionState)
        guard modifiers.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else {
            baseline = nil; return
        }
        guard let current = NotesAccessibility.snapshot() else {
            baseline = nil; setStatus("已就绪 · 请将光标放在备忘录正文"); return
        }
        observe(current)
        setStatus("正在备忘录中自动转换")
        defer { baseline = current }
        guard let previous = baseline, current.sameEditor(as: previous),
              EditGate.isSmallInsertion(from: previous.sample, to: current.sample) else { return }
        if let undo = beforeLastConversion, current.sameEditor(as: undo), current.sample == undo.sample { return }
        guard let conversion = rule.conversion(line: current.sample.line, offset: current.sample.lineOffset, insertedAfter: previous.sample.caret) else { return }
        let edit = EditorTransaction(snapshot: current, conversion: conversion)
        transaction = edit
        edit.run { [weak self] result in
            guard let self else { return }
            self.transaction = nil
            self.baseline = NotesAccessibility.snapshot()
            switch result {
            case .success(let converted):
                if converted {
                    self.beforeLastConversion = current
                    self.conversionCount += 1
                    self.logger.notice("Converted a Markdown span; length=\(conversion.range.length, privacy: .public)")
                }
            case .failure(let error):
                self.enabled = false
                self.status = error.localizedDescription
            }
        }
    }

    deinit {
        pendingNotification?.cancel()
        timer?.invalidate()
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
    }

    private func setStatus(_ value: String) { if status != value { status = value } }
}
