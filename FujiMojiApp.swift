import SwiftUI

@main
struct FujiMojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            EmojiMappingView()
        }
    }
}

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "🤠"  // You can set your desired emoji or text here
            button.action = #selector(statusBarButtonClicked(_:))
        }
        constructMenu()

        // Load emoji mappings from JSON file
        if let emojiMappings = loadEmojiMappings() {
            EventMonitor.shared.emojiMap = emojiMappings
            print("Emoji mappings loaded: \(emojiMappings)")
        } else {
            print("Failed to load emoji mappings")
        }

        // Start monitoring keyboard events
        EventMonitor.shared.start()
    }

    @objc func statusBarButtonClicked(_ sender: Any?) {
        // Optionally show some UI or handle the click
    }

    func constructMenu() {
        let menu = NSMenu()

        // Add a title to the menu
        let titleItem = NSMenuItem()
        titleItem.title = "FujiMoji"
        titleItem.isEnabled = true // Make the title appear as active (white text)
        menu.addItem(titleItem)

        // Add a separator
        menu.addItem(NSMenuItem.separator())

        // Add the Quit menu item
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction(_:)), keyEquivalent: "Q"))

        statusItem?.menu = menu
    }

    @objc func quitAction(_ sender: Any?) {
        EventMonitor.shared.stop() // Stop monitoring keyboard events
        NSApplication.shared.terminate(self)
    }

    func loadEmojiMappings() -> [String: String]? {
        guard let url = Bundle.main.url(forResource: "emojiMappings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mappings = try? JSONDecoder().decode([String: String].self, from: data) else {
            print("Failed to load emoji mappings")
            return nil
        }
        return mappings
    }
}
