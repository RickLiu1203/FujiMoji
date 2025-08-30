import SwiftUI

class FujiMojiState: ObservableObject {
    static let shared = FujiMojiState()
    
    @Published var isEnabled: Bool = true
    @Published var isCool: Bool = true
    @Published var showSuggestionPopup: Bool = true
    @Published var startCaptureKey: String = "/"
    @Published var endCaptureKey: String = "/"
    
    private let keyDetection = KeyDetection.shared

    private init() {
        loadCaptureKeys()
        updateKeyDetection()
        // Ensure KeyDetection uses the loaded capture keys
        keyDetection.updateDelimiters(start: startCaptureKey, end: endCaptureKey)
    }
    
    private func loadCaptureKeys() {
        startCaptureKey = UserDefaults.standard.string(forKey: "startCaptureKey") ?? "/"
        endCaptureKey = UserDefaults.standard.string(forKey: "endCaptureKey") ?? "/"
    }
    
    func updateCaptureKeys() {
        UserDefaults.standard.set(startCaptureKey, forKey: "startCaptureKey")
        UserDefaults.standard.set(endCaptureKey, forKey: "endCaptureKey")
        keyDetection.updateDelimiters(start: startCaptureKey, end: endCaptureKey)
    }
    
    func updateKeyDetection() {
        if isEnabled {
            keyDetection.start()
        } else {
            keyDetection.stop()
        }
    }
    
    func validateAndSetCaptureKeys(start: String, end: String) -> Bool {
        let trimmedStart = start.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = end.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedStart.isEmpty && !trimmedEnd.isEmpty else {
            return false
        }
        
        startCaptureKey = trimmedStart
        endCaptureKey = trimmedEnd
        updateCaptureKeys()
        return true
    }
}

