//
//  FujiMojiState.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import SwiftUI
import AppKit

// MARK: - Key Combo
struct KeyCombo: Codable, Equatable {
    var key: String
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool
    
    init(key: String = "/", command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        self.key = key
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }
    
    var hasModifiers: Bool {
        command || option || control || shift
    }
    
    var displayString: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        parts.append(key.uppercased())
        return parts.joined()
    }
    
    func matches(event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        let commandMatch = command == flags.contains(.command)
        let optionMatch = option == flags.contains(.option)
        let controlMatch = control == flags.contains(.control)
        let shiftMatch = shift == flags.contains(.shift)
        let keyMatch = event.charactersIgnoringModifiers?.lowercased() == key.lowercased()
        return commandMatch && optionMatch && controlMatch && shiftMatch && keyMatch
    }
}

enum SkinTone: String, CaseIterable, Codable, Hashable {
    case yellow
    case light
    case mediumLight
    case medium
    case mediumDark
    case dark

    var displayColor: Color {
        switch self {
        case .yellow:      return Color(red: 1.00, green: 0.85, blue: 0.20)
        case .light:       return Color(red: 0.98, green: 0.86, blue: 0.76)
        case .mediumLight: return Color(red: 0.91, green: 0.75, blue: 0.58)
        case .medium:      return Color(red: 0.78, green: 0.58, blue: 0.42)
        case .mediumDark:  return Color(red: 0.60, green: 0.39, blue: 0.24)
        case .dark:        return Color(red: 0.38, green: 0.28, blue: 0.22)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .yellow:      return "Default Yellow"
        case .light:       return "Light Skin Tone"
        case .mediumLight: return "Medium-light Skin Tone"
        case .medium:      return "Medium Skin Tone"
        case .mediumDark:  return "Medium-dark Skin Tone"
        case .dark:        return "Dark Skin Tone"
        }
    }
}

class FujiMojiState: ObservableObject {
    static let shared = FujiMojiState()
    
    @Published var isEnabled: Bool = true
    @Published var isCool: Bool = true
    @Published var showSuggestionPopup: Bool = true
    @Published var needsInputMonitoring: Bool = false
    @Published var triggerCombo: KeyCombo = KeyCombo()
    @Published var enterEndsCapture: Bool = true
    @Published var tabEndsCapture: Bool = true
    @Published var selectedSkinTone: SkinTone = .yellow
    @Published var skinToneModifier: String = ""
    private var variantEmojiKeys: Set<String> = []
    private var requiresVS16Keys: Set<String> = []
    private var toneCacheByTone: [SkinTone: [String: String]] = [:]
    
    private let keyDetection = KeyDetection.shared

    private init() {
        loadCaptureSettings()
        loadSkinTone()
        loadVariantEmojiKeys()
        ensureCacheForCurrentTone()
        updateKeyDetection()
        keyDetection.updateTriggerCombo(triggerCombo)
    }
    
    // MARK: - Input Monitoring
    func checkInputMonitoringAuthorization() {
        let accessibilityTrusted = AXIsProcessTrusted()
        if !accessibilityTrusted {
            DispatchQueue.main.async {
                self.needsInputMonitoring = true
            }
        }
    }

    func openInputMonitoringSettings() {
        let urls: [String] = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent", 
            "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for urlString in urls {
            if let url = URL(string: urlString) {
                if NSWorkspace.shared.open(url) {
                    break
                }
            }
        }
    }

    func relaunchApp() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [Bundle.main.bundlePath]
        do {
            try task.run()
        } catch {
            print("Failed to schedule relaunch: \(error)")
        }
        NSApp.terminate(nil)
    }
    
    private func loadCaptureSettings() {
        // Migrate from old string-based keys if present
        if let oldStart = UserDefaults.standard.string(forKey: "startCaptureKey") {
            triggerCombo = KeyCombo(key: oldStart)
            UserDefaults.standard.removeObject(forKey: "startCaptureKey")
            UserDefaults.standard.removeObject(forKey: "endCaptureKey")
            UserDefaults.standard.removeObject(forKey: "triggerKey")
            saveTriggerCombo()
        } else if let oldTrigger = UserDefaults.standard.string(forKey: "triggerKey") {
            triggerCombo = KeyCombo(key: oldTrigger)
            UserDefaults.standard.removeObject(forKey: "triggerKey")
            saveTriggerCombo()
        } else if let data = UserDefaults.standard.data(forKey: "triggerCombo"),
                  let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            triggerCombo = combo
        } else {
            triggerCombo = KeyCombo()
        }
        enterEndsCapture = UserDefaults.standard.object(forKey: "enterEndsCapture") as? Bool ?? true
        tabEndsCapture = UserDefaults.standard.object(forKey: "tabEndsCapture") as? Bool ?? true
    }
    
    private func saveTriggerCombo() {
        if let data = try? JSONEncoder().encode(triggerCombo) {
            UserDefaults.standard.set(data, forKey: "triggerCombo")
        }
    }
    
    func updateTriggerCombo() {
        saveTriggerCombo()
        keyDetection.updateTriggerCombo(triggerCombo)
    }
    
    func updateEnterEndsCapture() {
        UserDefaults.standard.set(enterEndsCapture, forKey: "enterEndsCapture")
    }
    
    func updateTabEndsCapture() {
        UserDefaults.standard.set(tabEndsCapture, forKey: "tabEndsCapture")
    }
    
    func updateKeyDetection() {
        if isEnabled {
            keyDetection.start()
        } else {
            keyDetection.stop()
        }
    }
    
    func setTriggerCombo(_ combo: KeyCombo) {
        triggerCombo = combo
        updateTriggerCombo()
    }

    // MARK: - Skin tone persistence
    private let skinToneKey = "selectedSkinTone"

    private func loadSkinTone() {
        if let raw = UserDefaults.standard.string(forKey: skinToneKey),
           let tone = SkinTone(rawValue: raw) {
            selectedSkinTone = tone
        } else {
            selectedSkinTone = .yellow
        }
        skinToneModifier = modifier(for: selectedSkinTone)
    }

    func saveSkinTone() {
        UserDefaults.standard.set(selectedSkinTone.rawValue, forKey: skinToneKey)
        skinToneModifier = modifier(for: selectedSkinTone)
        ensureCacheForCurrentTone(forceRebuildIfMissing: true)
    }

    // MARK: - Skin tone helpers
    private func modifier(for tone: SkinTone) -> String {
        switch tone {
        case .yellow:      return ""
        case .light:       return "\u{1F3FB}"
        case .mediumLight: return "\u{1F3FC}"
        case .medium:      return "\u{1F3FD}"
        case .mediumDark:  return "\u{1F3FE}"
        case .dark:        return "\u{1F3FF}"
        }
    }

    func applySkinTone(_ emoji: String) -> String {
        let normalized = normalizeForCache(emoji)
        if let cached = toneCacheByTone[selectedSkinTone]?[normalized] {
            return cached
        }
        return emoji
    }

    // MARK: - Variant keys + cache
    private func loadVariantEmojiKeys() {
        guard variantEmojiKeys.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "variant_emojis", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var keys: Set<String> = []
                keys.reserveCapacity(dict.keys.count)
                var vs16Set: Set<String> = []
                vs16Set.reserveCapacity(dict.keys.count)
                for key in dict.keys {
                    let hadVS16 = key.unicodeScalars.contains { $0.value == 0xFE0F }
                    let normalized = normalizeForCache(key)
                    keys.insert(normalized)
                    if hadVS16 {
                        vs16Set.insert(normalized)
                    }
                }
                variantEmojiKeys = keys
                requiresVS16Keys = vs16Set
            }
        } catch {
            print("Failed to load variant_emojis.json: \(error)")
        }
    }

    private func ensureCacheForCurrentTone(forceRebuildIfMissing: Bool = false) {
        if !forceRebuildIfMissing, toneCacheByTone[selectedSkinTone] != nil { return }
        guard !variantEmojiKeys.isEmpty else { return }
        var cache: [String: String] = [:]
        cache.reserveCapacity(variantEmojiKeys.count)

        for normalizedKey in variantEmojiKeys {
            let toned = buildTonedEmoji(fromNormalizedKey: normalizedKey, tone: selectedSkinTone)
            cache[normalizedKey] = toned
        }
        toneCacheByTone[selectedSkinTone] = cache
    }

    private func buildTonedEmoji(fromNormalizedKey normalizedKey: String, tone: SkinTone) -> String {
        if tone == .yellow {
            if requiresVS16Keys.contains(normalizedKey) {
                var scalars = Array(normalizedKey.unicodeScalars)
                scalars.append(UnicodeScalar(0xFE0F)!)
                return String(String.UnicodeScalarView(scalars))
            }
            return normalizedKey
        }
        guard let mod = modifier(for: tone).unicodeScalars.first else { return normalizedKey }
        let humanBases: Set<UnicodeScalar> = [
            UnicodeScalar(0x1F9D1)!, // person
            UnicodeScalar(0x1F468)!, // man
            UnicodeScalar(0x1F469)!, // woman
            UnicodeScalar(0x1F466)!, // boy
            UnicodeScalar(0x1F467)!  // girl
        ]
        let zwj = UnicodeScalar(0x200D)!

        var output: [UnicodeScalar] = []
        output.reserveCapacity(normalizedKey.unicodeScalars.count + 2)

        var insertedAny = false
        for s in normalizedKey.unicodeScalars {
            output.append(s)
            if humanBases.contains(s) {
                output.append(mod)
                insertedAny = true
            }
        }

        if !insertedAny {
            if let firstZWJIndex = output.firstIndex(of: zwj) {
                output.insert(mod, at: firstZWJIndex)
            } else {
                output.append(mod)
            }
        }

        return String(String.UnicodeScalarView(output))
    }

    private func normalizeForCache(_ s: String) -> String {
        let toneRange = 0x1F3FB...0x1F3FF
        let toneSet: Set<UnicodeScalar> = Set(toneRange.compactMap { UnicodeScalar($0) })
        let vs15 = UnicodeScalar(0xFE0E)!
        let vs16 = UnicodeScalar(0xFE0F)!
        let filtered = s.unicodeScalars.filter { !toneSet.contains($0) && $0 != vs15 && $0 != vs16 }
        return String(String.UnicodeScalarView(filtered))
    }
}

