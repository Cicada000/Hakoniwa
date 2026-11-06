//
//  SettingsView.swift
//  Hakoniwa
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var appModel = HakoniwaAppModel.shared
    
    public init() {}
    
    public var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
            
            WallpaperSettingsTab(settings: settings, appModel: appModel)
                .tabItem {
                    Label("壁纸与交互", systemImage: "desktopcomputer")
                }
            
            AudioSettingsTab(settings: settings, appModel: appModel)
                .tabItem {
                    Label("音效", systemImage: "speaker.wave.2")
                }
            
            AboutSettingsTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 530, height: 480)
    }
}

// MARK: - General Settings Tab
private struct GeneralSettingsTab: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 窗口管理
            VStack(alignment: .leading, spacing: 6) {
                Text("窗口管理")
                    .font(.system(size: 13, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(CloseBehavior.allCases) { item in
                        Button(action: { settings.closeBehavior = item }) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.closeBehavior == item ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(settings.closeBehavior == item ? .accentColor : .secondary)
                                    .font(.system(size: 13))
                                Image(systemName: item.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16)
                                Text(item.title)
                                    .font(.system(size: 13))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                
                Text(settings.closeBehavior.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // 性能控制
            VStack(alignment: .leading, spacing: 6) {
                Text("性能控制")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack {
                    Text("渲染帧率上限")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $settings.targetFPS) {
                        ForEach(TargetFPS.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text("60 FPS 为平衡推荐模式；30 FPS 可显著降低功耗；120 FPS 适合 ProMotion 屏幕。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // 外观主题
            VStack(alignment: .leading, spacing: 8) {
                Text("外观主题")
                    .font(.system(size: 13, weight: .semibold))
                
                Picker("", selection: $settings.themeMode) {
                    ForEach(AppThemeMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
}

// MARK: - Wallpaper Settings Tab
private struct WallpaperSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var appModel: HakoniwaAppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 动态壁纸
            VStack(alignment: .leading, spacing: 6) {
                Text("动态壁纸")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle("启用动态桌面壁纸", isOn: $appModel.isWallpaperEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                Text("将当前 3D 像素箱庭置于 macOS 桌面最底层，完全保留桌面图标与文件。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // 壁纸背景风格
            VStack(alignment: .leading, spacing: 8) {
                Text("壁纸背景风格")
                    .font(.system(size: 13, weight: .semibold))
                
                Picker("", selection: $settings.wallpaperBackgroundStyle) {
                    ForEach(WallpaperBackgroundStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                Text(settings.wallpaperBackgroundStyle == .solid
                    ? "纯色自适应：采用 macOS 经典深浅纯色底色，提供独立纯净的箱庭空间。"
                    : "透明背景：背景完全透明，箱庭场景直接悬浮于当前系统壁纸之上。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // 桌面交互
            VStack(alignment: .leading, spacing: 6) {
                Text("桌面交互")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle("允许在桌面空白处鼠标互动", isOn: $settings.desktopInteractionEnabled)
                    .toggleStyle(.checkbox)
                    .disabled(!appModel.isWallpaperEnabled)
                    .font(.system(size: 13))
                
                Text("开启后，当 Finder 处于最前台且点击桌面空白处时，可拖拽控制地滚球蓄力与投掷。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // 画面尺寸 (完全无级平滑调节，去除刻度)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("画面尺寸")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(Int(round(settings.desktopScale * 100)))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    // 无级平滑调节滑块（无 step 参数即无刻度线）
                    Slider(value: $settings.desktopScale, in: 0.5...1.2)
                    
                    Image(systemName: "photo.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Button("重置") {
                        withAnimation(.spring(response: 0.3)) {
                            settings.desktopScale = 0.90
                        }
                    }
                    .controlSize(.small)
                    .disabled(abs(settings.desktopScale - 0.90) < 0.005)
                }
                
                Text("无级调节桌面壁纸画面的尺寸大小。默认推荐为 90%，为顶部菜单栏和底部留出适当留白。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // 零干扰安全性设计卡片
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("零干扰安全性设计")
                        .font(.system(size: 12, weight: .semibold))
                    Text("壁纸窗口位于 kCGDesktopWindowLevel，绝不遮挡或拦截正常软件窗口的点击与关闭。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
}

// MARK: - Audio Settings Tab
private struct AudioSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var appModel: HakoniwaAppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 声音控制
            VStack(alignment: .leading, spacing: 6) {
                Text("声音控制")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle("静音所有音效", isOn: $appModel.isMuted)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
            }
            
            Divider()
            
            // 音效主音量 (无级滑块)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("音效主音量")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(Int(settings.soundVolume * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $settings.soundVolume, in: 0.0...1.0)
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        SoundManager.shared.play(.clack(amount: 1.0))
                    }) {
                        Label("试听", systemImage: "play.circle")
                    }
                    .controlSize(.small)
                }
                .disabled(appModel.isMuted)
            }
            
            Divider()
            
            Text("所有音效均为基于 AVAudioEngine 实时合成的复古 8-bit / 16-bit 方波、三角波与正弦波模拟碰撞，无外部音频文件依赖。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
}

// MARK: - About Settings Tab
private struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: "AppIconDark") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 4) {
                Text("Hakoniwa (箱庭)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Version 1.0.0 (Build 2026.11)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("原生 Swift 编写的 30° 等轴测软光栅引擎与动态壁纸平台。\n搭载 Bayer 抖动算法、色相偏移梯度及实时物理模拟。")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Divider()
            
            HStack {
                Text("Based on Pixel Plays by AmirMushich & abhi")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Native macOS • Metal-Free • 60 FPS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
