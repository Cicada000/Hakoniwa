//
//  HakoniwaApp.swift
//  Hakoniwa
//

import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppSettings.shared.showMainWindow()
        }
        return true
    }
}

struct MenuBarContent: View {
    @ObservedObject var appModel: HakoniwaAppModel
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        Text("Hakoniwa (箱庭)")
            .font(.headline)
        
        Divider()
        
        Button("显示主窗口") {
            AppSettings.shared.showMainWindow()
        }
        .keyboardShortcut("o")
        
        Toggle("桌面动态壁纸", isOn: $appModel.isWallpaperEnabled)
        Toggle("暂停画面动画", isOn: $appModel.isPaused)
        Toggle("静音音效", isOn: $appModel.isMuted)
        
        Divider()
        
        Button("偏好设置…") {
            NSApplication.shared.setActivationPolicy(.regular)
            openSettings()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        
        Divider()
        
        Button("退出 Hakoniwa") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

@main
struct HakoniwaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appModel = HakoniwaAppModel.shared
    @StateObject private var settings = AppSettings.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        
        Settings {
            SettingsView()
        }
        
        MenuBarExtra {
            MenuBarContent(appModel: appModel)
        } label: {
            Image(systemName: "tree.fill")
        }
    }
}
