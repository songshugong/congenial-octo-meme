import Foundation

struct AppInputMapping: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var appBundleID: String
    var inputSourceID: String
}

struct AppOption: Identifiable, Hashable {
    let bundleID: String
    let displayName: String

    var id: String { bundleID }
}

struct InputSourceOption: Identifiable, Hashable {
    let sourceID: String
    let displayName: String

    var id: String { sourceID }
}

enum AppFilterMode: String, Codable, CaseIterable, Identifiable {
    case all
    case whitelist
    case blacklist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "全部应用"
        case .whitelist:
            return "仅白名单"
        case .blacklist:
            return "排除黑名单"
        }
    }
}

struct SwitchLogEntry: Identifiable, Equatable {
    let id: UUID = UUID()
    let timestamp: Date
    let appBundleID: String
    let inputSourceID: String
    let success: Bool
    let message: String
}

enum IndicatorColorPreset: String, Codable, CaseIterable, Identifiable {
    case green
    case yellow
    case orange
    case red
    case blue
    case pink
    case white

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .green:
            return "绿色"
        case .yellow:
            return "黄色"
        case .orange:
            return "橙色"
        case .red:
            return "红色"
        case .blue:
            return "蓝色"
        case .pink:
            return "粉色"
        case .white:
            return "白色"
        }
    }
}
