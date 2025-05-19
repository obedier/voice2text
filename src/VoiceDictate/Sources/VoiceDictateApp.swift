import SwiftUI
import AppKit

@main
struct VoiceDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Ensure proper initialization of NSApplication for menu bar app
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Configure app behavior
        UserDefaults.standard.register(defaults: [
            "NSApplicationCrashOnExceptions": true
        ])
    }
    
    var body: some Scene {
        Settings {
            PreferencesView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 300)
    }
} 