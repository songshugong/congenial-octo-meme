import SwiftUI
import AppKit

@main
struct InputAutoSwitcherApp: App {
    @StateObject private var store = MappingStore()
    @StateObject private var switcher = InputSwitcherService()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @State private var showSwitchPulse = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
                .environmentObject(switcher)
                .environmentObject(launchAtLogin)
                .frame(width: 430)
        } label: {
            menuBarDynamicIcon
        }
        .menuBarExtraStyle(.window)
        .onChange(of: switcher.lastSwitchSignal) { _ in
            withAnimation(.easeOut(duration: 0.15)) {
                showSwitchPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSwitchPulse = false
                }
            }
        }
        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(switcher)
                .environmentObject(launchAtLogin)
                .frame(minWidth: 640, minHeight: 420)
        }
    }

    @ViewBuilder
    private var menuBarDynamicIcon: some View {
        let appIcon = switcher.appIcon(bundleID: switcher.currentAppBundleID)
        let inputIcon = switcher.inputSourceIcon(sourceID: switcher.currentInputSourceID)
        let rendered = MenuBarIconRenderer.shared.icon(
            inputSourceID: switcher.currentInputSourceID,
            appBundleID: switcher.currentAppBundleID,
            inputIcon: inputIcon,
            appIcon: appIcon,
            enabled: store.isEnabled,
            pulse: showSwitchPulse,
            statusDotColorPreset: store.statusDotColorPreset,
            switchDotColorPreset: store.switchDotColorPreset
        )
        Image(nsImage: rendered)
            .interpolation(.high)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
            .help("输入法切换")
    }
}
