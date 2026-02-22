import Foundation
import AppKit

final class MappingStore: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }
    @Published var statusDotColorPreset: IndicatorColorPreset {
        didSet { defaults.set(statusDotColorPreset.rawValue, forKey: Keys.statusDotColorPreset) }
    }
    @Published var switchDotColorPreset: IndicatorColorPreset {
        didSet { defaults.set(switchDotColorPreset.rawValue, forKey: Keys.switchDotColorPreset) }
    }
    @Published var isGlobalLocked: Bool {
        didSet { defaults.set(isGlobalLocked, forKey: Keys.isGlobalLocked) }
    }
    @Published var lockedInputSourceID: String {
        didSet { defaults.set(lockedInputSourceID, forKey: Keys.lockedInputSourceID) }
    }
    @Published var filterMode: AppFilterMode {
        didSet { defaults.set(filterMode.rawValue, forKey: Keys.filterMode) }
    }
    @Published var filteredBundleIDs: [String] {
        didSet { defaults.set(filteredBundleIDs, forKey: Keys.filteredBundleIDs) }
    }
    @Published var mappings: [AppInputMapping] {
        didSet { persistMappings() }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let isEnabled = "input_auto_switcher_enabled"
        static let statusDotColorPreset = "input_auto_switcher_status_dot_color_preset"
        static let switchDotColorPreset = "input_auto_switcher_switch_dot_color_preset"
        static let isGlobalLocked = "input_auto_switcher_global_locked"
        static let lockedInputSourceID = "input_auto_switcher_locked_input_source_id"
        static let filterMode = "input_auto_switcher_filter_mode"
        static let filteredBundleIDs = "input_auto_switcher_filtered_bundle_ids"
        static let mappings = "input_auto_switcher_mappings"
    }

    init() {
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        if let raw = defaults.string(forKey: Keys.statusDotColorPreset),
           let preset = IndicatorColorPreset(rawValue: raw) {
            self.statusDotColorPreset = preset
        } else {
            self.statusDotColorPreset = .green
        }
        if let raw = defaults.string(forKey: Keys.switchDotColorPreset),
           let preset = IndicatorColorPreset(rawValue: raw) {
            self.switchDotColorPreset = preset
        } else {
            self.switchDotColorPreset = .yellow
        }
        self.isGlobalLocked = defaults.object(forKey: Keys.isGlobalLocked) as? Bool ?? false
        self.lockedInputSourceID = defaults.string(forKey: Keys.lockedInputSourceID) ?? ""
        if let modeRawValue = defaults.string(forKey: Keys.filterMode),
           let mode = AppFilterMode(rawValue: modeRawValue) {
            self.filterMode = mode
        } else {
            self.filterMode = .all
        }
        self.filteredBundleIDs = defaults.stringArray(forKey: Keys.filteredBundleIDs) ?? []
        if let data = defaults.data(forKey: Keys.mappings),
           let decoded = try? JSONDecoder().decode([AppInputMapping].self, from: data) {
            self.mappings = decoded
        } else {
            self.mappings = []
        }
    }

    func setGlobalLock(_ enabled: Bool, currentInputSourceID: String) {
        isGlobalLocked = enabled
        if enabled {
            let normalized = currentInputSourceID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                lockedInputSourceID = normalized
            }
        }
    }

    func mapping(for bundleID: String) -> AppInputMapping? {
        mappings.first { $0.appBundleID == bundleID }
    }

    func addEmptyMapping() {
        mappings.append(AppInputMapping(appBundleID: "", inputSourceID: ""))
    }

    func addMappingFromCurrentContext(currentSourceID: String?) {
        let appBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        upsertMapping(appBundleID: appBundleID, inputSourceID: currentSourceID ?? "")
    }

    func upsertMapping(appBundleID: String, inputSourceID: String) {
        let normalizedBundleID = appBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBundleID.isEmpty else { return }

        if let index = mappings.firstIndex(where: { $0.appBundleID == normalizedBundleID }) {
            mappings[index].inputSourceID = inputSourceID
        } else {
            mappings.append(
                AppInputMapping(
                    appBundleID: normalizedBundleID,
                    inputSourceID: inputSourceID
                )
            )
        }
    }

    func removeMapping(id: UUID) {
        mappings.removeAll { $0.id == id }
    }

    func moveMappingUp(id: UUID) {
        guard let index = mappings.firstIndex(where: { $0.id == id }), index > 0 else { return }
        mappings.swapAt(index, index - 1)
    }

    func moveMappingDown(id: UUID) {
        guard let index = mappings.firstIndex(where: { $0.id == id }), index < mappings.count - 1 else { return }
        mappings.swapAt(index, index + 1)
    }

    func canMoveUp(id: UUID) -> Bool {
        guard let index = mappings.firstIndex(where: { $0.id == id }) else { return false }
        return index > 0
    }

    func canMoveDown(id: UUID) -> Bool {
        guard let index = mappings.firstIndex(where: { $0.id == id }) else { return false }
        return index < mappings.count - 1
    }

    func shouldHandle(bundleID: String) -> Bool {
        switch filterMode {
        case .all:
            return true
        case .whitelist:
            return filteredBundleIDs.contains(bundleID)
        case .blacklist:
            return !filteredBundleIDs.contains(bundleID)
        }
    }

    func addFilteredApp(bundleID: String) {
        let normalized = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !filteredBundleIDs.contains(normalized) else { return }
        filteredBundleIDs.append(normalized)
    }

    func removeFilteredApp(bundleID: String) {
        filteredBundleIDs.removeAll { $0 == bundleID }
    }

    private func persistMappings() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        defaults.set(data, forKey: Keys.mappings)
    }
}
