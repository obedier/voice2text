import Cocoa
import SwiftUI
import AVFoundation
import Speech
import Defaults
import AVKit

class AppDelegate: NSObject, NSApplicationDelegate, SFSpeechRecognizerDelegate {
    private var statusItem: NSStatusItem!
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var speechRecognizer: SFSpeechRecognizer!
    private var isListening = false
    private var iconUpdateTimer: Timer?
    private var currentIconState = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 VoiceDictate is launching...")
        setupMenuBar()
        setupSpeechRecognition()
        registerGlobalShortcut()
        
        // Request necessary permissions
        requestPermissions()
        print("✅ Application setup complete")
    }
    
    private func requestPermissions() {
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    self.showPermissionAlert(
                        title: "Speech Recognition Access Required",
                        message: "Please enable Speech Recognition in System Settings > Privacy & Security > Speech Recognition"
                    )
                case .restricted, .notDetermined:
                    print("Speech recognition status: \(status)")
                @unknown default:
                    break
                }
            }
        }
        
        // Request microphone authorization using AVCaptureDevice
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.showPermissionAlert(
                        title: "Microphone Access Required",
                        message: "Please enable Microphone access in System Settings > Privacy & Security > Microphone"
                    )
                }
            }
        }
    }
    
    private func showPermissionAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microphone")
            button.target = self
            button.action = #selector(toggleDictation)
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func setupSpeechRecognition() {
        print("🎤 Setting up speech recognition...")
        let locale = Locale(identifier: Defaults[.selectedLanguage])
        print("🌍 Using locale: \(locale.identifier)")
        
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer.delegate = self
        
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("🎵 Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            print("📊 Audio buffer received: \(buffer.frameLength) frames")
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            
            self.recognitionTask = self.speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    print("❌ Recognition error: \(error)")
                    return
                }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    print("🗣️ Recognized text: \(text)")
                    self.handleRecognizedText(text)
                }
            }
        }
        print("✅ Speech recognition setup complete")
    }
    
    private func handleRecognizedText(_ text: String) {
        // Update transcription window
        if Defaults[.showTranscriptionWindow] {
            TranscriptionWindowManager.shared.updateTranscription(text)
            print("📝 Updated transcription: \(text)")
        }
        
        // Process for commands
        let (processedText, isCommand) = VoiceCommandService.shared.processCommand(text)
        
        if isCommand {
            print("🎯 Voice command detected: \(text)")
        } else if !processedText.isEmpty {
            print("⌨️ Inserting text: \(processedText)")
            TextInsertionService.shared.insertText(processedText)
        }
    }
    
    private func registerGlobalShortcut() {
        // TODO: Implement global shortcut registration using Carbon Hot Key API
    }
    
    @objc func toggleDictation() {
        if isListening {
            stopDictation()
        } else {
            startDictation()
        }
    }
    
    private func startDictation() {
        guard !isListening else { 
            print("⚠️ Already listening, ignoring start request")
            return 
        }
        
        print("🎙️ Starting dictation...")
        do {
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            updateMenuBarIcon()
            
            if Defaults[.showTranscriptionWindow] {
                TranscriptionWindowManager.shared.showWindow()
                print("📝 Transcription window opened")
            }
            print("✅ Dictation started successfully")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
        }
    }
    
    private func stopDictation() {
        print("🛑 Stopping dictation...")
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        updateMenuBarIcon()
        
        if Defaults[.showTranscriptionWindow] {
            TranscriptionWindowManager.shared.hideWindow()
            print("📝 Transcription window closed")
        }
        print("✅ Dictation stopped successfully")
    }
    
    private func updateMenuBarIcon() {
        if isListening {
            // Start the icon animation timer if not already running
            if iconUpdateTimer == nil {
                iconUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.animateMenuBarIcon()
                }
            }
        } else {
            // Stop the animation timer and reset icon
            iconUpdateTimer?.invalidate()
            iconUpdateTimer = nil
            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microphone")
            }
        }
    }
    
    private func animateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        
        // Cycle through different microphone icons to show activity
        let icons = ["mic.fill", "mic.circle.fill", "mic.slash.circle.fill"]
        currentIconState = (currentIconState + 1) % icons.count
        
        button.image = NSImage(
            systemSymbolName: icons[currentIconState],
            accessibilityDescription: "Voice Dictate Recording"
        )
        
        // Update the icon color based on audio level
        if let level = audioEngine?.inputNode.volume {
            let color: NSColor
            if level < 0.3 {
                color = .systemGreen
            } else if level < 0.7 {
                color = .systemYellow
            } else {
                color = .systemRed
            }
            button.image?.isTemplate = false
            button.image = button.image?.tinting(with: color)
        }
    }
    
    @objc func showPreferences() {
        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        preferencesWindow.contentView = NSHostingView(rootView: PreferencesView())
        preferencesWindow.center()
        preferencesWindow.makeKeyAndOrderFront(nil)
    }
}

// Extension to help with image tinting
extension NSImage {
    func tinting(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        
        image.unlockFocus()
        return image
    }
} 