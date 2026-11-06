//
//  KeystrokeMonitor.swift
//  Hakoniwa
//
//  Privacy-safe keyboard activity monitor.
//  Tracks typing frequency, keystroke counts, and idle state WITHOUT inspecting or recording characters.
//

import Foundation
import AppKit
import Combine

public final class KeystrokeMonitor: ObservableObject {
    public static let shared = KeystrokeMonitor()
    
    @Published public var totalKeystrokesToday: Int = 0
    @Published public var sessionKeystrokes: Int = 0
    @Published public var currentWPM: Double = 0.0
    @Published public var combo: Int = 0
    @Published public var isTyping: Bool = false
    
    // Callbacks for scenes
    public var onKeystroke: (() -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastKeystrokeTime: CFTimeInterval = 0
    private var keystrokeTimestamps: [CFTimeInterval] = []
    private var decayTimer: Timer?
    
    private let userDefaultsKey = "Hakoniwa_TotalKeystrokesToday"
    private let lastDateKey = "Hakoniwa_LastKeystrokeDate"
    
    private init() {
        loadPersistedCount()
        startMonitoring()
        startDecayTimer()
    }
    
    private func loadPersistedCount() {
        let defaults = UserDefaults.standard
        let todayString = currentDateString()
        let savedDate = defaults.string(forKey: lastDateKey)
        
        if savedDate == todayString {
            totalKeystrokesToday = defaults.integer(forKey: userDefaultsKey)
        } else {
            totalKeystrokesToday = 0
            defaults.set(todayString, forKey: lastDateKey)
            defaults.set(0, forKey: userDefaultsKey)
        }
    }
    
    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func startMonitoring() {
        // 1. Local event monitor for when Hakoniwa window is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.recordKeystroke()
            return event
        }
        
        // 2. Global event monitor for when user types in other foreground apps (IDE, browser, etc.)
        // Note: Global monitor receives events without consuming or modifying them.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            self?.recordKeystroke()
        }
    }
    
    public func recordKeystroke() {
        let now = CACurrentMediaTime()
        
        // Check day change
        let todayString = currentDateString()
        if UserDefaults.standard.string(forKey: lastDateKey) != todayString {
            totalKeystrokesToday = 0
            UserDefaults.standard.set(todayString, forKey: lastDateKey)
        }
        
        // Update counts
        totalKeystrokesToday += 1
        sessionKeystrokes += 1
        UserDefaults.standard.set(totalKeystrokesToday, forKey: userDefaultsKey)
        
        // Combo detection (reset if idle for more than 2.5s)
        if lastKeystrokeTime > 0 && (now - lastKeystrokeTime) < 2.5 {
            combo += 1
        } else {
            combo = 1
        }
        lastKeystrokeTime = now
        isTyping = true
        
        // Maintain sliding window for WPM (last 5 seconds)
        keystrokeTimestamps.append(now)
        let cutoff = now - 5.0
        keystrokeTimestamps.removeAll { $0 < cutoff }
        
        // Estimate WPM: (keystrokes / 5 chars per word) * (60 / windowSeconds)
        let countInWindow = Double(keystrokeTimestamps.count)
        let wpm = (countInWindow / 5.0) * (60.0 / 5.0)
        currentWPM = wpm
        
        // Notify scenes
        onKeystroke?()
    }
    
    private func startDecayTimer() {
        decayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = CACurrentMediaTime()
            if self.lastKeystrokeTime > 0 && (now - self.lastKeystrokeTime) > 3.0 {
                // Decay WPM when idle
                self.currentWPM = max(0, self.currentWPM * 0.7)
                if self.currentWPM < 1.0 {
                    self.currentWPM = 0
                    self.isTyping = false
                }
                if (now - self.lastKeystrokeTime) > 5.0 {
                    self.combo = 0
                }
            }
        }
    }
    
    deinit {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
        decayTimer?.invalidate()
    }
}
