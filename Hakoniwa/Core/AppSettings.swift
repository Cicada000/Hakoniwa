//
//  AppSettings.swift
//  Hakoniwa
//

import SwiftUI
import AppKit
import Combine

public enum CloseBehavior: String, CaseIterable, Identifiable {
    case keepInDock = "keepInDock"
    case quitApp = "quitApp"
    case menuBarOnly = "menuBarOnly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .keepInDock: return "保留在 Dock 栏（默认）"
        case .quitApp: return "直接全部退出应用"
        case .menuBarOnly: return "仅常驻菜单栏（Dock 隐藏活动）"
        }
    }
    
    public var icon: String {
        switch self {
        case .keepInDock: return "dock.rectangle"
        case .quitApp: return "xmark.circle"
        case .menuBarOnly: return "menubar.rectangle"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .keepInDock: return "关闭主窗口后，应用仍在后台运行，Dock 栏图标保留活动指示灯。"
        case .quitApp: return "关闭主窗口时，彻底退出整个程序并清理所有后台资源。"
        case .menuBarOnly: return "关闭主窗口后，Dock 图标完全隐匿，仅在顶部菜单栏驻留，不占任务栏空间。"
        }
    }
}

public enum TargetFPS: Int, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60
    case fps120 = 120
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .fps30: return "30 FPS（节能模式 / 低能耗）"
        case .fps60: return "60 FPS（流畅平衡 / 推荐）"
        case .fps120: return "120 FPS（ProMotion 极致高刷）"
        }
    }
}

public enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .system: return "跟随系统外观"
        case .light: return "始终浅色模式"
        case .dark: return "始终深色模式"
        }
    }
}

public enum SceneType: String, CaseIterable, Identifiable {
    case balote = "balote"
    case zenBonsai = "zen_bonsai"
    case monumentBuilder = "monument_builder"
    case pachinko = "pachinko"
    case aquariumPond = "aquarium_pond"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .balote: return "法式滚球 (Balote)"
        case .zenBonsai: return "禅意盆景 (Zen Bonsai)"
        case .monumentBuilder: return "微缩建造 (Builder)"
        case .pachinko: return "弹珠连击 (Pachinko)"
        case .aquariumPond: return "浮岛鱼塘 (Aquarium)"
        }
    }
    
    public var icon: String {
        switch self {
        case .balote: return "circle.circle.fill"
        case .zenBonsai: return "leaf.fill"
        case .monumentBuilder: return "hammer.fill"
        case .pachinko: return "flame.fill"
        case .aquariumPond: return "drop.fill"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .balote: return "经典 3D 滚球投掷与 AI 对弈"
        case .zenBonsai: return "打字蓄养分，盆景抽枝繁花"
        case .monumentBuilder: return "敲击搬砖筑屋，点亮烟囱炊烟"
        case .pachinko: return "打字蓄能弹珠，一键倾泻解压"
        case .aquariumPond: return "清澈浮岛鱼塘，点击水波喂食"
        }
    }
    
    public func createScene() -> HakoniwaScene {
        switch self {
        case .balote: return BaloteScene()
        case .zenBonsai: return ZenBonsaiScene()
        case .monumentBuilder: return MonumentBuilderScene()
        case .pachinko: return PachinkoScene()
        case .aquariumPond: return AquariumPondScene()
        }
    }
}

public enum WallpaperBackgroundStyle: String, CaseIterable, Identifiable {
    case solid = "solid"
    case transparent = "transparent"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .solid: return "纯色自适应"
        case .transparent: return "透明背景"
        }
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    @AppStorage("closeBehavior") public var closeBehaviorRaw: String = CloseBehavior.keepInDock.rawValue
    @AppStorage("targetFPS") public var targetFPS: Int = 60
    @AppStorage("themeMode") public var themeModeRaw: String = AppThemeMode.system.rawValue
    @AppStorage("currentSceneType") public var currentSceneTypeRaw: String = SceneType.balote.rawValue
    @AppStorage("wallpaperBackgroundStyle") public var wallpaperBackgroundStyleRaw: String = WallpaperBackgroundStyle.solid.rawValue
    @AppStorage("desktopInteractionEnabled") public var desktopInteractionEnabled: Bool = true
    @AppStorage("desktopScale") public var desktopScaleRaw: Double = 0.90
    @AppStorage("soundVolume") public var soundVolume: Double = 1.0 {
        didSet {
            SoundManager.shared.volume = Float(soundVolume)
        }
    }
    
    public var currentSceneType: SceneType {
        get { SceneType(rawValue: currentSceneTypeRaw) ?? .balote }
        set {
            currentSceneTypeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    public var wallpaperBackgroundStyle: WallpaperBackgroundStyle {
        get { WallpaperBackgroundStyle(rawValue: wallpaperBackgroundStyleRaw) ?? .solid }
        set {
            wallpaperBackgroundStyleRaw = newValue.rawValue
            WallpaperManager.shared.updateDesktopTheme(animated: true)
            objectWillChange.send()
        }
    }
    
    public var desktopScale: Double {
        get { desktopScaleRaw }
        set {
            desktopScaleRaw = newValue
            WallpaperManager.shared.updateDesktopScale()
            objectWillChange.send()
        }
    }
    
    public var isDarkMode: Bool {
        switch themeMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            if let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
                return match == .darkAqua
            }
            return false
        }
    }
    
    public var closeBehavior: CloseBehavior {
        get { CloseBehavior(rawValue: closeBehaviorRaw) ?? .keepInDock }
        set {
            closeBehaviorRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    public var themeMode: AppThemeMode {
        get { AppThemeMode(rawValue: themeModeRaw) ?? .system }
        set {
            themeModeRaw = newValue.rawValue
            applyTheme(newValue)
            objectWillChange.send()
        }
    }
    
    public func applyTheme(_ mode: AppThemeMode) {
        let appearance: NSAppearance?
        switch mode {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }
        
        NSApp.appearance = appearance
        for win in NSApplication.shared.windows {
            win.appearance = appearance
        }
        WallpaperManager.shared.updateDesktopTheme(animated: true)
        HakoniwaAppModel.shared.updateDockIcon()
    }
    
    public weak var mainWindow: NSWindow?
    
    private init() {
        SoundManager.shared.volume = Float(soundVolume)
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSystemThemeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.applyTheme(self.themeMode)
        }
    }
    
    @objc private func handleSystemThemeChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.themeMode == .system {
                self.applyTheme(.system)
                self.objectWillChange.send()
            }
        }
    }
    
    public func handleWindowClose(window: NSWindow) {
        switch closeBehavior {
        case .quitApp:
            NSApplication.shared.terminate(nil)
        case .menuBarOnly:
            window.orderOut(nil)
            NSApplication.shared.setActivationPolicy(.accessory)
        case .keepInDock:
            window.orderOut(nil)
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }
    
    public func showMainWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        if let win = mainWindow {
            win.makeKeyAndOrderFront(nil)
        } else {
            // Find non-desktop window
            for win in NSApplication.shared.windows {
                if win.level.rawValue == 0 && !(win is DesktopWallpaperWindow) {
                    mainWindow = win
                    win.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    public static func openSettingsWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

public final class HakoniwaWindowDelegate: NSObject, NSWindowDelegate {
    public static let shared = HakoniwaWindowDelegate()
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender is DesktopWallpaperWindow { return true }
        AppSettings.shared.handleWindowClose(window: sender)
        return false // We handle orderOut / terminate manually
    }
}
