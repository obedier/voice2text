import SwiftUI
import Defaults
import AVFoundation

extension Defaults.Keys {
    static let selectedLanguage = Key<String>("selectedLanguage", default: "en-US")
    static let shortcutEnabled = Key<Bool>("shortcutEnabled", default: true)
    static let showTranscriptionWindow = Key<Bool>("showTranscriptionWindow", default: true)
    static let selectedMicrophoneID = Key<String>("selectedMicrophoneID", default: "")
    static let debugLoggingEnabled = Key<Bool>("debugLoggingEnabled", default: false)
    static let verboseLoggingEnabled = Key<Bool>("verboseLoggingEnabled", default: false)
    static let customShortcut = Key<String>("customShortcut", default: "⌘\\")
    static let speechBackend = Key<String>("speechBackend", default: "apple_auto")
    static let geminiApiKey = Key<String>("geminiApiKey", default: "")
}

class MicrophoneMonitor: ObservableObject {
    @Published var level: Float = 0.0
    private var timer: Timer?
    private var audioEngine: AVAudioEngine?
    private var levelTimer: Timer?
    
    func startMonitoring() {
        // Using AVAudioEngine for level monitoring instead of AVAudioRecorder
        // as it's more reliable on macOS
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Just install a tap to monitor audio levels
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            guard let self = self else { return }
            
            // Calculate RMS (root mean square) to get audio level
            let channelData = buffer.floatChannelData?[0]
            if let channelData = channelData {
                var sum: Float = 0
                let frames = buffer.frameLength
                
                // Sum the squares of all samples
                for i in 0..<Int(frames) {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                
                // Calculate RMS (root mean square)
                let rms = sqrt(sum / Float(frames))
                
                // Convert to decibels and normalize
                let db = 20 * log10(rms)
                DispatchQueue.main.async {
                    self.level = self.normalizeAudioLevel(level: db)
                }
            }
        }
        
        do {
            try audioEngine.start()
            DebugLogger.shared.log("Audio monitoring started", type: .debug)
        } catch {
            DebugLogger.shared.log("Failed to start audio monitoring: \(error.localizedDescription)", type: .error)
        }
    }
    
    func stopMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        // Reset level to 0
        DispatchQueue.main.async {
            self.level = 0
        }
        
        DebugLogger.shared.log("Audio monitoring stopped", type: .debug)
    }
    
    private func normalizeAudioLevel(level: Float) -> Float {
        // Convert from dB to a 0-1 scale
        let minDb: Float = -80.0
        if level < minDb {
            return 0.0
        } else if level >= 0.0 {
            return 1.0
        } else {
            return (level - minDb) / abs(minDb)
        }
    }
}

class DebugLogger: ObservableObject {
    @Published var logEntries: [LogEntry] = []
    @Published var isLoggingEnabled = false
    @Published var isVerboseLoggingEnabled = false
    
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType
        
        enum LogType: String {
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
            case debug = "DEBUG"
            case verbose = "VERBOSE"
            
            var color: Color {
                switch self {
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                case .debug: return .gray
                case .verbose: return .green
                }
            }
        }
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }
    
    func log(_ message: String, type: LogEntry.LogType = .info) {
        // Skip verbose logs if verbose logging is not enabled
        if type == .verbose && !isVerboseLoggingEnabled { return }
        
        // Skip all logs if logging is disabled
        guard isLoggingEnabled || type == .error else { return }
        
        let timestamp = Date()
        let logEntry = LogEntry(timestamp: timestamp, message: message, type: type)
        
        DispatchQueue.main.async {
            // Add to our observable array
            self.logEntries.append(logEntry)
            
            // Trim if it gets too large
            if self.logEntries.count > 1000 {
                self.logEntries.removeFirst(self.logEntries.count - 1000)
            }
        }
        
        // Write to log file
        let formattedLog = "[\(self.dateFormatter.string(from: timestamp))] [\(type.rawValue)] \(message)\n"
        appendToLogFile(formattedLog)
    }
    
    private func appendToLogFile(_ text: String) {
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                if let data = text.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try text.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
    
    func clearLog() {
        logEntries.removeAll()
        
        // Clear log file
        do {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to clear log file: \(error)")
        }
    }
    
    func exportLog() -> URL? {
        // We already have a log file, just return its URL
        return logFileURL
    }
    
    // Singleton
    static let shared = DebugLogger()
    
    private init() {
        // Set up date formatter for log files
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Get the application support directory
        let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = applicationSupportDirectory.appendingPathComponent("VoiceDictate")
        
        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create app directory: \(error)")
            }
        }
        
        // Create log file path
        logFileURL = appDirectory.appendingPathComponent("voice_dictate.log")
        
        // Load default settings
        isLoggingEnabled = Defaults[.debugLoggingEnabled]
        isVerboseLoggingEnabled = Defaults[.verboseLoggingEnabled]
        
        // Log application start
        log("Debug logger initialized", type: .info)
    }
}

struct PreferencesView: View {
    @Default(.selectedLanguage) private var selectedLanguage
    @Default(.shortcutEnabled) private var shortcutEnabled
    @Default(.showTranscriptionWindow) private var showTranscriptionWindow
    @Default(.selectedMicrophoneID) private var selectedMicrophoneID
    @Default(.debugLoggingEnabled) private var debugLoggingEnabled
    @Default(.verboseLoggingEnabled) private var verboseLoggingEnabled
    @Default(.customShortcut) private var customShortcut
    @Default(.speechBackend) private var speechBackend
    @Default(.geminiApiKey) private var geminiApiKey
    
    @StateObject private var microphoneMonitor = MicrophoneMonitor()
    @StateObject private var logger = DebugLogger.shared
    
    @State private var availableMicrophones: [InputDevice] = []
    @State private var isTestingMicrophone: Bool = false
    @State private var isAssigningShortcut: Bool = false
    @State private var temporaryShortcut: String = ""
    
    private let availableLanguages = [
        "en-US": "English (US)",
        "en-GB": "English (UK)",
        "es-ES": "Spanish",
        "fr-FR": "French",
        "de-DE": "German",
        "ja-JP": "Japanese"
    ]
    
    struct InputDevice: Identifiable, Hashable {
        let id: String
        let name: String
        
        static func == (lhs: InputDevice, rhs: InputDevice) -> Bool {
            return lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            microphoneTab
                .tabItem {
                    Label("Microphone", systemImage: "mic")
                }
            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            accessibilityTab
                .tabItem {
                    Label("Accessibility", systemImage: "person.circle")
                }
            debugTab
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            loadMicrophones()
            logger.isLoggingEnabled = debugLoggingEnabled
            logger.isVerboseLoggingEnabled = verboseLoggingEnabled
            logger.log("Preferences window opened", type: .info)
            temporaryShortcut = customShortcut
        }
        .onChange(of: debugLoggingEnabled) { newValue in
            logger.isLoggingEnabled = newValue
            logger.log("Logging \(newValue ? "enabled" : "disabled")", type: .info)
        }
        .onChange(of: verboseLoggingEnabled) { newValue in
            logger.isVerboseLoggingEnabled = newValue
            logger.log("Verbose logging \(newValue ? "enabled" : "disabled")", type: .info)
        }
    }
    
    private var generalTab: some View {
        Form {
            Picker("Speech Recognition Backend", selection: $speechBackend) {
                Text("Apple (Automatic)").tag("apple_auto")
                Text("Apple (On-Device Only)").tag("apple_ondevice")
                Text("Google Gemini").tag("google_gemini")
            }
            .help("Choose which speech recognition engine to use. On-Device avoids Apple API quotas. Google Gemini is experimental.")
            if speechBackend == "google_gemini" {
                HStack {
                    Text("Gemini API Key:")
                    SecureField("Enter your Gemini API key", text: $geminiApiKey)
                }
                .help("Get your Gemini API key from Google AI Studio.")
            }
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
    
    private var microphoneTab: some View {
        Form {
            Section(header: Text("Input Device")) {
                Picker("Select Microphone", selection: $selectedMicrophoneID) {
                    Text("Default System Microphone").tag("")
                    ForEach(availableMicrophones) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .onChange(of: selectedMicrophoneID) { newValue in
                    logger.log("Microphone changed to: \(newValue.isEmpty ? "Default" : newValue)", type: .info)
                }
                
                Button(isTestingMicrophone ? "Stop Testing" : "Test Microphone") {
                    if isTestingMicrophone {
                        microphoneMonitor.stopMonitoring()
                    } else {
                        microphoneMonitor.startMonitoring()
                    }
                    isTestingMicrophone.toggle()
                }
                .padding(.top, 5)
                
                if isTestingMicrophone {
                    HStack {
                        Text("Level:")
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .frame(width: geometry.size.width, height: 20)
                                    .opacity(0.3)
                                    .foregroundColor(.gray)
                                
                                Rectangle()
                                    .frame(width: min(CGFloat(self.microphoneMonitor.level) * geometry.size.width, geometry.size.width), height: 20)
                                    .foregroundColor(.green)
                            }
                            .cornerRadius(4.0)
                        }
                        .frame(height: 20)
                    }
                    .padding(.top, 5)
                }
                
                Text("Speak into your microphone to test the input level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
            
            Section(header: Text("Sound Input Tips")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("• Position your microphone 6-12 inches from your mouth")
                    Text("• Speak clearly and at a moderate pace")
                    Text("• Reduce background noise when possible")
                    Text("• For best results, use an external microphone")
                }
                .font(.callout)
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
                    
                    if isAssigningShortcut {
                        TextField("Type a shortcut", text: $temporaryShortcut)
                            .frame(width: 100)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                customShortcut = temporaryShortcut
                                isAssigningShortcut = false
                                logger.log("Shortcut changed to: \(customShortcut)", type: .info)
                            }
                        
                        Button("Save") {
                            customShortcut = temporaryShortcut
                            isAssigningShortcut = false
                            logger.log("Shortcut changed to: \(customShortcut)", type: .info)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("Cancel") {
                            temporaryShortcut = customShortcut
                            isAssigningShortcut = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        KeyboardShortcutView(shortcut: customShortcut)
                        
                        Button("Change") {
                            isAssigningShortcut = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Text("Note: Custom shortcuts need to be registered in System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
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
    
    private var debugTab: some View {
        VStack(spacing: 10) {
            HStack {
                Toggle("Enable Debug Logging", isOn: $debugLoggingEnabled)
                    .toggleStyle(SwitchToggleStyle())
                
                Toggle("Verbose Logging", isOn: $verboseLoggingEnabled)
                    .toggleStyle(SwitchToggleStyle())
                    .disabled(!debugLoggingEnabled)
                
                Spacer()
                
                Button("Clear Log") {
                    logger.clearLog()
                    logger.log("Log cleared", type: .info)
                }
                .disabled(logger.logEntries.isEmpty)
                
                Button("View Log File") {
                    if let logURL = logger.exportLog() {
                        logger.log("Opening log file: \(logURL.path)", type: .info)
                        NSWorkspace.shared.open(logURL)
                    }
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logger.logEntries.reversed()) { entry in
                        HStack(alignment: .top) {
                            Text("[\(entry.formattedTimestamp)]")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            Text("[\(entry.type.rawValue)]")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(entry.type.color)
                            
                            Text(entry.message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private func loadMicrophones() {
        availableMicrophones = []
        
        // Get available audio inputs using AVCaptureDevice
        // This is more reliable than using AVAudioEngine for device listing
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone],
            mediaType: .audio,
            position: .unspecified
        )
        
        for device in discoverySession.devices {
            availableMicrophones.append(InputDevice(id: device.uniqueID, name: device.localizedName))
            logger.log("Found microphone: \(device.localizedName) (ID: \(device.uniqueID))", type: .verbose)
        }
        
        logger.log("Loaded \(availableMicrophones.count) microphones", type: .debug)
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