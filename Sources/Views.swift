import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject private var store: MappingStore
    @EnvironmentObject private var switcher: InputSwitcherService
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @State private var showSwitchHighlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("启用自动切换", isOn: $store.isEnabled)
            Toggle(
                "全局锁定输入法",
                isOn: Binding(
                    get: { store.isGlobalLocked },
                    set: { store.setGlobalLock($0, currentInputSourceID: switcher.currentInputSourceID) }
                )
            )
            Toggle(
                "开机自启动",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            switchStatusView()

            Divider()

            HStack {
                Button("打开设置") {
                    openSettingsWindow()
                }
                Button("刷新") {
                    switcher.refreshCurrentContext()
                    launchAtLogin.refresh()
                }
            }

            Menu("诊断") {
                if switcher.logs.isEmpty {
                    Text("暂无日志")
                } else {
                    ForEach(Array(switcher.logs.prefix(8))) { log in
                        Text(logLine(log))
                    }
                }
                Divider()
                Button("清空日志") {
                    switcher.clearLogs()
                }
            }

            Menu("图标颜色") {
                Picker("状态点颜色", selection: $store.statusDotColorPreset) {
                    ForEach(IndicatorColorPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                Picker("切换点颜色", selection: $store.switchDotColorPreset) {
                    ForEach(IndicatorColorPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
            }

            if let lastError = launchAtLogin.lastError {
                Text(lastError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            if let lastError = switcher.lastError {
                Text(lastError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            if store.isGlobalLocked {
                Text("锁定输入法：\(lockedInputDisplayName())")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .onAppear {
            switcher.start(with: store)
            switcher.refreshCurrentContext()
            launchAtLogin.refresh()
        }
        .onChange(of: switcher.lastSwitchSignal) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                showSwitchHighlight = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSwitchHighlight = false
                }
            }
        }
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        AppSettingsWindowManager.shared.showOrFocus(
            store: store,
            switcher: switcher,
            launchAtLogin: launchAtLogin
        )
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func iconItem(title: String, image: NSImage?, fallbackSystemName: String, help: String) -> some View {
        VStack(spacing: 4) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: 18, weight: .regular))
            }
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help(help)
    }

    private func switchStatusView() -> some View {
        let appImage = switcher.appIcon(bundleID: switcher.currentAppBundleID)
        let inputImage = switcher.inputSourceIcon(sourceID: switcher.currentInputSourceID)
        let inputName = switcher.inputSourceDisplayName(sourceID: switcher.currentInputSourceID) ?? "未知输入法"

        return HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                if let appImage {
                    Image(nsImage: appImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: "app")
                        .resizable()
                        .foregroundStyle(.secondary)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                }

                if let inputImage {
                    Image(nsImage: inputImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 13, height: 13)
                        .background(Material.regularMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 1))
                        .offset(x: 2, y: 2)
                } else {
                    Image(systemName: "keyboard")
                        .resizable()
                        .foregroundStyle(.secondary)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 13, height: 13)
                        .background(Material.regularMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 1))
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(showSwitchHighlight ? "已切换输入法" : "当前输入法")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(inputName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(showSwitchHighlight ? Color.green.opacity(0.20) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help("\(currentAppHelp())\n\(currentInputHelp())")
    }

    private func currentAppHelp() -> String {
        let bundleID = switcher.currentAppBundleID
        guard !bundleID.isEmpty else { return "当前未识别应用" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url) {
            let name =
                (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                url.deletingPathExtension().lastPathComponent
            return "\(name)（\(bundleID)）"
        }
        return bundleID
    }

    private func currentInputHelp() -> String {
        let sourceID = switcher.currentInputSourceID
        guard !sourceID.isEmpty else { return "当前未识别输入法" }
        let name = switcher.inputSourceDisplayName(sourceID: sourceID) ?? sourceID
        return "\(name)（\(sourceID)）"
    }

    private func logLine(_ log: SwitchLogEntry) -> String {
        let stamp = log.timestamp.formatted(date: .omitted, time: .standard)
        let mark = log.success ? "OK" : "ERR"
        return "[\(stamp)] \(mark) \(log.appBundleID) -> \(log.inputSourceID) | \(log.message)"
    }

    private func lockedInputDisplayName() -> String {
        guard !store.lockedInputSourceID.isEmpty else { return "-" }
        return switcher.inputSourceDisplayName(sourceID: store.lockedInputSourceID) ?? store.lockedInputSourceID
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: MappingStore
    @EnvironmentObject private var switcher: InputSwitcherService
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @State private var appOptions: [AppOption] = []
    @State private var inputOptions: [InputSourceOption] = []
    @State private var selectedFilterBundleID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Toggle("启用自动切换", isOn: $store.isEnabled)
                Toggle(
                    "全局锁定输入法",
                    isOn: Binding(
                        get: { store.isGlobalLocked },
                        set: { store.setGlobalLock($0, currentInputSourceID: switcher.currentInputSourceID) }
                    )
                )
                Toggle(
                    "开机自启动",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                Button("新增规则") {
                    addRule()
                }
                Button("按当前应用新增") {
                    store.addMappingFromCurrentContext(currentSourceID: switcher.currentInputSourceID)
                }
                Button("刷新列表") {
                    refreshOptions()
                }
            }

            Text("为每条规则选择“应用”和“输入法”，切换到该应用时会自动切换输入法。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.isGlobalLocked {
                Text("当前全局锁定：\(lockedInputDisplayName())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Text("过滤模式")
                Picker("过滤模式", selection: $store.filterMode) {
                    ForEach(AppFilterMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .frame(width: 180)
                .pickerStyle(.menu)

                if store.filterMode != .all {
                    Picker("名单应用", selection: $selectedFilterBundleID) {
                        Text("选择应用").tag("")
                        ForEach(appOptions) { app in
                            Text(app.displayName).tag(app.bundleID)
                        }
                    }
                    .frame(width: 220)
                    .pickerStyle(.menu)
                    Button("加入名单") {
                        store.addFilteredApp(bundleID: selectedFilterBundleID)
                        selectedFilterBundleID = ""
                    }
                    .disabled(selectedFilterBundleID.isEmpty)
                }
            }

            if store.filterMode != .all {
                FlowChipsView(
                    title: store.filterMode == .whitelist ? "白名单应用" : "黑名单应用",
                    bundleIDs: store.filteredBundleIDs,
                    displayNameForBundleID: appDisplayName,
                    removeAction: { store.removeFilteredApp(bundleID: $0) }
                )
            }

            List {
                ForEach($store.mappings) { $mapping in
                    HStack {
                        appIconView(bundleID: mapping.appBundleID, size: 14)
                        Picker("应用", selection: $mapping.appBundleID) {
                            Text("请选择应用").tag("")
                            ForEach(appOptionsForCurrentMapping(mapping.appBundleID)) { app in
                                Text(app.displayName).tag(app.bundleID)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .controlSize(.small)

                        inputSourceIconView(sourceID: mapping.inputSourceID, size: 14)
                        Picker("输入法", selection: $mapping.inputSourceID) {
                            Text("请选择输入法").tag("")
                            ForEach(inputOptionsForCurrentMapping(mapping.inputSourceID)) { source in
                                Text(source.displayName).tag(source.sourceID)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .controlSize(.small)

                        Button("测试") {
                            _ = switcher.switchInputSource(sourceID: mapping.inputSourceID)
                        }
                        .buttonStyle(.bordered)
                        Button("上移") {
                            store.moveMappingUp(id: mapping.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canMoveUp(id: mapping.id))
                        Button("下移") {
                            store.moveMappingDown(id: mapping.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.canMoveDown(id: mapping.id))
                        Button("删除") {
                            store.removeMapping(id: mapping.id)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minHeight: 260)

            Divider()

            HStack(spacing: 14) {
                iconItem(
                    title: "当前应用",
                    image: switcher.appIcon(bundleID: switcher.currentAppBundleID),
                    fallbackSystemName: "app",
                    help: currentAppHelp()
                )
                iconItem(
                    title: "当前输入法",
                    image: switcher.inputSourceIcon(sourceID: switcher.currentInputSourceID),
                    fallbackSystemName: "keyboard",
                    help: currentInputHelp()
                )
            }

            if let lastSwitchAt = switcher.lastSwitchAt {
                Text("最近切换时间：\(lastSwitchAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
            }

            if let lastError = switcher.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let lastError = launchAtLogin.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .onAppear {
            switcher.start(with: store)
            switcher.refreshCurrentContext()
            launchAtLogin.refresh()
            refreshOptions()
        }
    }

    private func refreshOptions() {
        appOptions = AppDiscoveryService.discoverApplications()
        inputOptions = switcher.availableInputSources()
    }

    private func addRule() {
        let app = appOptions.first?.bundleID ?? ""
        let source = inputOptions.first?.sourceID ?? switcher.currentInputSourceID
        store.mappings.append(AppInputMapping(appBundleID: app, inputSourceID: source))
    }

    private func appDisplayName(bundleID: String) -> String {
        if let option = appOptions.first(where: { $0.bundleID == bundleID }) {
            return option.displayName
        }
        return bundleID
    }

    private func appOptionsForCurrentMapping(_ bundleID: String) -> [AppOption] {
        guard !bundleID.isEmpty, !appOptions.contains(where: { $0.bundleID == bundleID }) else {
            return appOptions
        }
        let fallback = AppOption(bundleID: bundleID, displayName: "\(bundleID)（已保存）")
        return [fallback] + appOptions
    }

    private func inputOptionsForCurrentMapping(_ sourceID: String) -> [InputSourceOption] {
        guard !sourceID.isEmpty, !inputOptions.contains(where: { $0.sourceID == sourceID }) else {
            return inputOptions
        }
        let fallback = InputSourceOption(sourceID: sourceID, displayName: "\(sourceID)（已保存）")
        return [fallback] + inputOptions
    }

    @ViewBuilder
    private func appIconView(bundleID: String, size: CGFloat) -> some View {
        if let image = switcher.appIcon(bundleID: bundleID) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .padding(.vertical, 1)
        } else {
            Image(systemName: "app")
                .font(.system(size: size, weight: .regular))
                .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private func inputSourceIconView(sourceID: String, size: CGFloat) -> some View {
        if let image = switcher.inputSourceIcon(sourceID: sourceID) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .padding(.vertical, 1)
        } else {
            Image(systemName: "keyboard")
                .font(.system(size: size, weight: .regular))
                .padding(.vertical, 1)
        }
    }

    private func iconItem(title: String, image: NSImage?, fallbackSystemName: String, help: String) -> some View {
        VStack(spacing: 4) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: 20, weight: .regular))
            }
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help(help)
    }

    private func currentAppHelp() -> String {
        let bundleID = switcher.currentAppBundleID
        guard !bundleID.isEmpty else { return "当前未识别应用" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url) {
            let name =
                (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                url.deletingPathExtension().lastPathComponent
            return "\(name)（\(bundleID)）"
        }
        return bundleID
    }

    private func currentInputHelp() -> String {
        let sourceID = switcher.currentInputSourceID
        guard !sourceID.isEmpty else { return "当前未识别输入法" }
        let name = switcher.inputSourceDisplayName(sourceID: sourceID) ?? sourceID
        return "\(name)（\(sourceID)）"
    }

    private func lockedInputDisplayName() -> String {
        guard !store.lockedInputSourceID.isEmpty else { return "-" }
        return switcher.inputSourceDisplayName(sourceID: store.lockedInputSourceID) ?? store.lockedInputSourceID
    }
}

struct FlowChipsView: View {
    let title: String
    let bundleIDs: [String]
    let displayNameForBundleID: (String) -> String
    let removeAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if bundleIDs.isEmpty {
                Text("暂无")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bundleIDs, id: \.self) { bundleID in
                            HStack(spacing: 6) {
                                Text(displayNameForBundleID(bundleID))
                                    .lineLimit(1)
                                Button("移除") {
                                    removeAction(bundleID)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
        }
    }
}

@MainActor
final class AppSettingsWindowManager {
    static let shared = AppSettingsWindowManager()
    private var window: NSWindow?

    private init() {}

    func showOrFocus(store: MappingStore, switcher: InputSwitcherService, launchAtLogin: LaunchAtLoginManager) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
            .environmentObject(store)
            .environmentObject(switcher)
            .environmentObject(launchAtLogin)

        let hostingController = NSHostingController(rootView: contentView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "输入法切换设置"
        newWindow.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        newWindow.setContentSize(NSSize(width: 1000, height: 620))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = newWindow
    }
}
