import AppKit
import Foundation

final class MenuBarIconRenderer {
    static let shared = MenuBarIconRenderer()

    private let fileManager = FileManager.default
    private let cacheDir: URL

    private init() {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        cacheDir = base.appendingPathComponent("InputAutoSwitcher/MenuIcons", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func icon(
        inputSourceID: String,
        appBundleID: String,
        inputIcon: NSImage?,
        appIcon: NSImage?,
        enabled: Bool,
        pulse: Bool,
        statusDotColorPreset: IndicatorColorPreset,
        switchDotColorPreset: IndicatorColorPreset
    ) -> NSImage {
        let key = "v5|\(inputSourceID)|\(appBundleID)|\(enabled ? 1 : 0)|\(pulse ? 1 : 0)|\(statusDotColorPreset.rawValue)|\(switchDotColorPreset.rawValue)"
            .replacingOccurrences(of: "/", with: "_")
        let cachedURL = cacheDir.appendingPathComponent("\(key).png")

        if let cached = NSImage(contentsOf: cachedURL) {
            cached.isTemplate = false
            return cached
        }

        let image = drawComposite(
            inputIcon: inputIcon,
            appIcon: appIcon,
            enabled: enabled,
            pulse: pulse,
            statusDotColorPreset: statusDotColorPreset,
            switchDotColorPreset: switchDotColorPreset
        )
        writePNG(image, to: cachedURL)
        return image
    }

    private func drawComposite(
        inputIcon: NSImage?,
        appIcon: NSImage?,
        enabled: Bool,
        pulse: Bool,
        statusDotColorPreset: IndicatorColorPreset,
        switchDotColorPreset: IndicatorColorPreset
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            image.isTemplate = false
            return image
        }

        let glyphColor = enabled ? NSColor.white : NSColor(calibratedWhite: 0.72, alpha: 1.0)
        let glyphRect = CGRect(x: 1.0, y: 1.0, width: 12.8, height: 12.8)
        if let inputIcon {
            drawTemplate(image: inputIcon, in: glyphRect, color: glyphColor, context: context)
        } else if let fallback = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) {
            drawTemplate(image: fallback, in: glyphRect, color: glyphColor, context: context)
        }

        if enabled {
            context.setFillColor(color(for: statusDotColorPreset).cgColor)
            context.fillEllipse(in: CGRect(x: 0.2, y: 13.2, width: 4.0, height: 4.0))
        }

        let badgeRect = CGRect(x: 10.5, y: 0.5, width: 7.0, height: 7.0)

        let appDrawRect = badgeRect
        if let appIcon {
            let clipPath = CGPath(ellipseIn: appDrawRect, transform: nil)
            context.saveGState()
            context.addPath(clipPath)
            context.clip()
            appIcon.draw(in: appDrawRect)
            context.restoreGState()
        } else if let fallback = NSImage(systemSymbolName: "app", accessibilityDescription: nil) {
            drawTemplate(image: fallback, in: appDrawRect, color: .black, context: context)
        }

        if pulse {
            context.setFillColor(color(for: switchDotColorPreset).cgColor)
            context.fillEllipse(in: CGRect(x: 0.4, y: 0.4, width: 4.2, height: 4.2))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawTemplate(image: NSImage, in rect: CGRect, color: NSColor, context: CGContext) {
        context.saveGState()
        image.draw(in: rect)
        context.setBlendMode(.sourceIn)
        context.setFillColor(color.cgColor)
        context.fill(rect)
        context.restoreGState()
    }

    private func writePNG(_ image: NSImage, to url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        try? png.write(to: url, options: .atomic)
    }

    private func color(for preset: IndicatorColorPreset) -> NSColor {
        switch preset {
        case .green:
            return .systemGreen
        case .yellow:
            return .systemYellow
        case .orange:
            return .systemOrange
        case .red:
            return .systemRed
        case .blue:
            return .systemBlue
        case .pink:
            return .systemPink
        case .white:
            return .white
        }
    }
}
