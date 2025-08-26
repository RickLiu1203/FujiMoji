import SwiftUI

class FujiMojiState: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var isCool: Bool = true
    
    private let keyDetection = KeyDetection.shared

    init() {
        updateKeyDetection()
    }
    
    func updateKeyDetection() {
        if isEnabled {
            keyDetection.start()
        } else {
            keyDetection.stop()
        }
    }
}

