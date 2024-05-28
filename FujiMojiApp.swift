import SwiftUI

@main
struct FujiMojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings{EmptyView()}
    }
}




class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "🍎"
            button.action = #selector(statusBarButtonClicked(_:))
        }
        constructMenu()
        
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
        // Optionally handle status bar button click
    }

    func constructMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "S")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction(_:)), keyEquivalent: "Q"))

        statusItem?.menu = menu
    }
    
    @objc func openSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(self)
    }


    @objc func quitAction(_ sender: Any?) {
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
