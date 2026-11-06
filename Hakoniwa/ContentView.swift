//
//  ContentView.swift
//  Hakoniwa
//

import SwiftUI
import AppKit

struct PixelCanvasRepresentable: NSViewRepresentable {
    @ObservedObject var appModel = HakoniwaAppModel.shared
    
    func makeNSView(context: Context) -> PixelCanvasNSView {
        let view = PixelCanvasNSView(frame: .zero)
        view.onPointerDown = { pt in
            appModel.currentScene.handlePointerDown(screenPoint: pt)
        }
        view.onPointerMove = { pt in
            appModel.currentScene.handlePointerMove(screenPoint: pt)
        }
        view.onPointerUp = {
            appModel.currentScene.handlePointerUp()
        }
        view.onActionKey = {
            appModel.currentScene.handleActionKey()
        }
        
        appModel.onFrameRendered = { [weak view] pixels in
            view?.updateFrame(with: pixels)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: PixelCanvasNSView, context: Context) {}
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let win = view.window { callback(win) }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @StateObject private var appModel = HakoniwaAppModel.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingRules = false
    @State private var selectedScene = "balote"
    
    // Smooth adaptive colors: very light grey in light mode, very dark grey in dark mode (no pure white, no pure black)
    private var windowBgColor: Color {
        settings.isDarkMode
            ? Color(red: 28/255, green: 29/255, blue: 33/255)
            : Color(red: 242/255, green: 243/255, blue: 246/255)
    }
    
    var body: some View {
        ZStack {
            WindowAccessor { win in
                AppSettings.shared.mainWindow = win
                win.delegate = HakoniwaWindowDelegate.shared
            }
            
            // Adaptive Window Background filling entire window
            windowBgColor
                .ignoresSafeArea()
            
            // The Interactive Pixel Canvas directly in the window
            PixelCanvasRepresentable()
            
            // Floating Status & Controls Overlay (Glassmorphism Pill)
            VStack {
                Spacer()
                
                HStack(spacing: 14) {
                    // Status Text
                    Text(appModel.hudStatusText.isEmpty ? "Drag back, release to throw" : appModel.hudStatusText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Divider()
                        .frame(height: 14)
                    
                    // Keyboard Shortcut Hints
                    HStack(spacing: 6) {
                        KeyBadge(text: "Space")
                        Text("Throw")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(settings.isDarkMode ? Color.white.opacity(0.14) : Color.white.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(settings.isDarkMode ? 0.35 : 0.12), radius: 16, x: 0, y: 6)
                .padding(.bottom, 22)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: settings.isDarkMode)
        .preferredColorScheme(settings.themeMode == .system ? nil : (settings.themeMode == .dark ? .dark : .light))
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            // Leading: Scene Selector Menu
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button(action: { selectedScene = "balote" }) {
                        Label("Balote (Bocce)", systemImage: "circle.circle.fill")
                    }
                    Divider()
                    Section("More Dioramas Coming Soon") {
                        Label("Stari Most (Bridge Dive)", systemImage: "water.waves")
                            .foregroundColor(.secondary)
                        Label("Rooftop Laundry", systemImage: "tshirt")
                            .foregroundColor(.secondary)
                        Label("Tie-Break (Tennis)", systemImage: "tennisball")
                            .foregroundColor(.secondary)
                        Label("Mini Ramp (Skateboard)", systemImage: "figure.skating")
                            .foregroundColor(.secondary)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("Balote")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .menuStyle(.borderlessButton)
            }
            
            // Trailing: Controls & Wallpaper Toggle
            ToolbarItemGroup(placement: .primaryAction) {
                // Sound Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        appModel.isMuted.toggle()
                    }
                }) {
                    Image(systemName: appModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                }
                .help(appModel.isMuted ? "Unmute Sound" : "Mute Sound")
                
                // Pause / Play Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        appModel.isPaused.toggle()
                    }
                }) {
                    Image(systemName: appModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12))
                }
                .help(appModel.isPaused ? "Resume Simulation" : "Pause Simulation")
                
                // Rules & Info Button
                Button(action: { showingRules.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13))
                }
                .help("Game Rules & Credits")
                .popover(isPresented: $showingRules) {
                    RulesPopoverView()
                }
                
                // Preferences / Settings Button
                Button(action: {
                    NSApplication.shared.setActivationPolicy(.regular)
                    openSettings()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                }
                .help("Settings (⌘,)")
                
                // Desktop Wallpaper Toggle
                Toggle(isOn: $appModel.isWallpaperEnabled) {
                    HStack(spacing: 5) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 12))
                        Text("Wallpaper")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .toggleStyle(.button)
                .help("Set dynamic pixel diorama as desktop wallpaper")
            }
        }
    }
}

// MARK: - Key Badge Helper
struct KeyBadge: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }
}

// MARK: - Rules Popover View
struct RulesPopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balote (Bocce)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Isometric Pixel Diorama Game")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "circle.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                RuleRow(number: "1", text: "Get your red balls closer to the small yellow jack than the rival’s blue ones.")
                RuleRow(number: "2", text: "Drag back and release to throw. A longer pull throws further. Keyboard: space to throw.")
                RuleRow(number: "3", text: "Whoever is further from the jack throws next.")
                RuleRow(number: "4", text: "Score one point for each ball closer than the rival’s best. First to 5 wins.")
            }
            
            Divider()
            
            HStack {
                Text("Based on Pixel Plays by AmirMushich & abhi")
                    .font(.caption2)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Spacer()
                Text("Native Swift 60 FPS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .frame(width: 380)
    }
}

struct RuleRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
