import SwiftUI
import Defaults

extension Defaults.Keys {
    static let selectedLanguage = Key<String>("selectedLanguage", default: "en-US")
    static let shortcutEnabled = Key<Bool>("shortcutEnabled", default: true)
    static let showTranscriptionWindow = Key<Bool>("showTranscriptionWindow", default: true)
}

struct PreferencesView: View {
    @Default(.selectedLanguage) private var selectedLanguage
    @Default(.shortcutEnabled) private var shortcutEnabled
    @Default(.showTranscriptionWindow) private var showTranscriptionWindow
    
    private let availableLanguages = [
        "en-US": "English (US)",
        "en-GB": "English (UK)",
        "es-ES": "Spanish",
        "fr-FR": "French",
        "de-DE": "German",
        "ja-JP": "Japanese"
    ]
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            accessibilityTab
                .tabItem {
                    Label("Accessibility", systemImage: "person.circle")
                }
        }
        .padding()
        .frame(width: 500, height: 300)
    }
    
    private var generalTab: some View {
        Form {
            Picker("Language", selection: $selectedLanguage) {
                ForEach(Array(availableLanguages.keys.sorted()), id: \.self) { key in
                    Text(availableLanguages[key] ?? key)
                        .tag(key)
                }
            }
            
            Toggle("Show Transcription Window", isOn: $showTranscriptionWindow)
                .help("Display a floating window with real-time transcription")
            
            Section(header: Text("Privacy")) {
                Text("Voice recognition is performed locally when possible")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var shortcutsTab: some View {
        Form {
            Toggle("Enable Global Shortcut", isOn: $shortcutEnabled)
            
            if shortcutEnabled {
                HStack {
                    Text("Start/Stop Dictation:")
                    KeyboardShortcutView(shortcut: "⌘ + Space")
                }
            }
        }
    }
    
    private var accessibilityTab: some View {
        Form {
            Section(header: Text("Voice Commands")) {
                Text("Common Commands:")
                    .bold()
                VStack(alignment: .leading) {
                    Text("• 'New Line' - Start a new line")
                    Text("• 'Period' - Add a period")
                    Text("• 'Question Mark' - Add a question mark")
                    Text("• 'Delete Last Word' - Remove the last word")
                }
                .foregroundColor(.secondary)
            }
        }
    }
}

struct KeyboardShortcutView: View {
    let shortcut: String
    
    var body: some View {
        Text(shortcut)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(6)
    }
} 