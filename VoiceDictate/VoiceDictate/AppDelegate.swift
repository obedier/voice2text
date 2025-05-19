import Cocoa
import Speech
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var isRecording = false
    private var isAuthorized = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application launching...")
        
        // Check macOS version
        if #available(macOS 10.15, *) {
            print("Running on macOS 10.15 or later")
            setupSpeechRecognition()
        } else {
            print("Running on macOS 10.14 or earlier")
            showUnsupportedVersionAlert()
        }
        
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        print("Setting up status bar...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarIcon")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        print("Status bar setup complete")
    }
    
    @available(macOS 10.15, *)
    private func setupSpeechRecognition() {
        print("Setting up speech recognition...")
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            print("Speech recognition authorization status: \(status.rawValue)")
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    print("Speech recognition authorized")
                case .denied:
                    self?.showAuthorizationAlert(message: "Speech recognition permission was denied")
                case .restricted:
                    self?.showAuthorizationAlert(message: "Speech recognition is restricted on this device")
                case .notDetermined:
                    self?.showAuthorizationAlert(message: "Speech recognition permission not determined")
                @unknown default:
                    self?.showAuthorizationAlert(message: "Unknown authorization status")
                }
            }
        }
    }
    
    @objc private func toggleRecording() {
        print("Toggle recording called, isRecording: \(isRecording)")
        
        if #available(macOS 10.15, *) {
            if !isAuthorized {
                print("Speech recognition not authorized")
                showAuthorizationAlert(message: "Please grant speech recognition permission in System Preferences")
                return
            }
            
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } else {
            showUnsupportedVersionAlert()
        }
    }
    
    @available(macOS 10.15, *)
    private func startRecording() {
        print("Starting recording...")
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Failed to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                print("Recognition result: \(result.bestTranscription.formattedString)")
                // Handle the recognized text
                self.handleRecognizedText(result.bestTranscription.formattedString)
            }
            
            if error != nil {
                print("Recognition error: \(error?.localizedDescription ?? "Unknown error")")
                self.stopRecording()
            }
        }
        
        // Configure audio engine
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine?.inputNode
        
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        do {
            try audioEngine?.start()
            isRecording = true
            print("Recording started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
            stopRecording()
        }
    }
    
    @available(macOS 10.15, *)
    private func stopRecording() {
        print("Stopping recording...")
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isRecording = false
        print("Recording stopped")
    }
    
    private func handleRecognizedText(_ text: String) {
        print("Handling recognized text: \(text)")
        // TODO: Implement text handling logic
    }
    
    private func showAuthorizationAlert(message: String) {
        print("Showing authorization alert: \(message)")
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showUnsupportedVersionAlert() {
        print("Showing unsupported version alert")
        let alert = NSAlert()
        alert.messageText = "Unsupported macOS Version"
        alert.informativeText = "This application requires macOS 10.15 (Catalina) or later."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("Application terminating...")
        if #available(macOS 10.15, *) {
            stopRecording()
        }
    }
} 