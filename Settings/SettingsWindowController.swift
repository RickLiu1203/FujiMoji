import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    convenience init() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "FujiMoji ⚙️"
        window.setContentSize(NSSize(width: 300, height: 100))
        window.styleMask = [.titled, .closable, .resizable]
        window.level = .floating
        
        self.init(window: window)
        self.window = window
    }
}
