import Foundation
import AppKit
import Carbon

final class InputSwitcherService: ObservableObject {
    @Published private(set) var currentAppBundleID: String = ""
    @Published private(set) var currentInputSourceID: String = ""
    @Published private(set) var lastSwitchAt: Date?
    @Published private(set) var lastSwitchSignal: UUID = UUID()
    @Published private(set) var lastError: String?
    @Published private(set) var logs: [SwitchLogEntry] = []

    private var observation: NSObjectProtocol?

    deinit {
        if let observation {
            NSWorkspace.shared.notificationCenter.removeObserver(observation)
        }
    }

    func start(with store: MappingStore) {
        guard observation == nil else { return }
        refreshCurrentContext()

        observation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak store] notification in
            guard let self, let store else { return }
            self.handleActivation(notification, store: store)
        }
    }

    func refreshCurrentContext() {
        currentAppBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        currentInputSourceID = currentKeyboardInputSourceID() ?? ""
    }

    func availableInputSources() -> [InputSourceOption] {
        guard let listRef = TISCreateInputSourceList(nil, false)?.takeRetainedValue(),
              let inputSources = listRef as? [TISInputSource] else {
            return []
        }

        let filtered = inputSources.compactMap { source -> InputSourceOption? in
            guard let sourceID = stringProperty(of: source, key: kTISPropertyInputSourceID),
                  let name = stringProperty(of: source, key: kTISPropertyLocalizedName) else {
                return nil
            }

            let category = stringProperty(of: source, key: kTISPropertyInputSourceCategory) ?? ""
            let isSelectCapable = boolProperty(of: source, key: kTISPropertyInputSourceIsSelectCapable)

            guard category == (kTISCategoryKeyboardInputSource as String), isSelectCapable else {
                return nil
            }

            return InputSourceOption(sourceID: sourceID, displayName: name)
        }

        return filtered.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func inputSourceDisplayName(sourceID: String) -> String? {
        guard let source = inputSource(for: sourceID) else { return nil }
        return stringProperty(of: source, key: kTISPropertyLocalizedName)
    }

    func inputSourceIcon(sourceID: String) -> NSImage? {
        guard let source = inputSource(for: sourceID) else { return nil }
        if let iconURL = urlProperty(of: source, key: kTISPropertyIconImageURL) {
            return NSImage(contentsOf: iconURL)
        }
        return nil
    }

    func appIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func clearLogs() {
        logs.removeAll()
    }

    @discardableResult
    func switchInputSource(sourceID: String) -> Bool {
        let trimmed = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let filter = [kTISPropertyInputSourceID as String: trimmed] as CFDictionary
        guard let listRef = TISCreateInputSourceList(filter, false)?.takeRetainedValue(),
              let inputSources = listRef as? [TISInputSource],
              let inputSource = inputSources.first else {
            lastError = "找不到输入法：\(trimmed)"
            return false
        }

        let status = TISSelectInputSource(inputSource)
        guard status == noErr else {
            lastError = "切换失败，状态码：\(status)"
            return false
        }

        lastSwitchAt = Date()
        lastSwitchSignal = UUID()
        currentInputSourceID = currentKeyboardInputSourceID() ?? trimmed
        lastError = nil
        return true
    }

    private func handleActivation(_ notification: Notification, store: MappingStore) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            let bundleID = app.bundleIdentifier
        else { return }

        currentAppBundleID = bundleID

        if store.isGlobalLocked {
            let targetSourceID = store.lockedInputSourceID
            guard !targetSourceID.isEmpty else { return }

            if currentInputSourceID != targetSourceID {
                if switchInputSource(sourceID: targetSourceID) {
                    currentInputSourceID = targetSourceID
                    addLog(
                        appBundleID: bundleID,
                        inputSourceID: targetSourceID,
                        success: true,
                        message: "全局锁定生效"
                    )
                } else {
                    addLog(
                        appBundleID: bundleID,
                        inputSourceID: targetSourceID,
                        success: false,
                        message: lastError ?? "全局锁定切换失败"
                    )
                }
            } else {
                addLog(
                    appBundleID: bundleID,
                    inputSourceID: targetSourceID,
                    success: true,
                    message: "全局锁定保持"
                )
            }
            return
        }

        guard store.isEnabled else { return }

        guard store.shouldHandle(bundleID: bundleID) else {
            currentInputSourceID = currentKeyboardInputSourceID() ?? currentInputSourceID
            addLog(
                appBundleID: bundleID,
                inputSourceID: currentInputSourceID,
                success: true,
                message: "跳过：不在当前过滤范围"
            )
            return
        }

        guard let mapping = store.mapping(for: bundleID) else {
            currentInputSourceID = currentKeyboardInputSourceID() ?? currentInputSourceID
            addLog(
                appBundleID: bundleID,
                inputSourceID: currentInputSourceID,
                success: true,
                message: "跳过：未配置规则"
            )
            return
        }

        if switchInputSource(sourceID: mapping.inputSourceID) {
            currentInputSourceID = mapping.inputSourceID
            addLog(
                appBundleID: bundleID,
                inputSourceID: mapping.inputSourceID,
                success: true,
                message: "切换成功"
            )
        } else {
            addLog(
                appBundleID: bundleID,
                inputSourceID: mapping.inputSourceID,
                success: false,
                message: lastError ?? "切换失败"
            )
        }
    }

    private func addLog(appBundleID: String, inputSourceID: String, success: Bool, message: String) {
        logs.insert(
            SwitchLogEntry(
                timestamp: Date(),
                appBundleID: appBundleID,
                inputSourceID: inputSourceID,
                success: success,
                message: message
            ),
            at: 0
        )
        if logs.count > 80 {
            logs.removeLast(logs.count - 80)
        }
    }

    private func currentKeyboardInputSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return stringProperty(of: source, key: kTISPropertyInputSourceID)
    }

    private func inputSource(for sourceID: String) -> TISInputSource? {
        let trimmed = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let filter = [kTISPropertyInputSourceID as String: trimmed] as CFDictionary
        guard let listRef = TISCreateInputSourceList(filter, false)?.takeRetainedValue(),
              let inputSources = listRef as? [TISInputSource] else {
            return nil
        }
        return inputSources.first
    }

    private func stringProperty(of source: TISInputSource, key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        let value = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
        return value as? String
    }

    private func urlProperty(of source: TISInputSource, key: CFString) -> URL? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        let value = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
        return value as? URL
    }

    private func boolProperty(of source: TISInputSource, key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        let value = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
        return (value as? NSNumber)?.boolValue ?? false
    }
}
