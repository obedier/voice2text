import Cocoa
import SwiftUI
import AVFoundation
import Speech
import Defaults
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, SFSpeechRecognizerDelegate {
    private var statusItem: NSStatusItem!
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var speechRecognizer: SFSpeechRecognizer!
    private var isListening = false
    private var preferencesWindow: NSWindow?
    private var statusWindow: NSWindow?
    private var dictationStartTime: Date?
    private var dictationTimer: Timer?
    private var geminiAudioFile: AVAudioFile?
    private var geminiAudioURL: URL?
    
    private var logger: DebugLogger {
        return DebugLogger.shared
    }
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.log("Application started", type: .info)
        setupMenuBar()
        setupSpeechRecognition()
        registerGlobalShortcut()
        
        // Request necessary permissions
        requestPermissions()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.log("Application terminating", type: .info)
        if isListening {
            stopDictation()
        }
    }
    
    // MARK: - Permissions
    
    private func requestPermissions() {
        logger.log("Requesting permissions for speech recognition and microphone", type: .debug)
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.logger.log("Speech recognition authorization status: \(status)", type: .debug)
                switch status {
                case .authorized:
                    self.logger.log("Speech recognition authorized", type: .info)
                case .denied:
                    self.logger.log("Speech recognition denied", type: .error)
                    self.showPermissionAlert(
                        title: "Speech Recognition Access Required",
                        message: "Please enable Speech Recognition in System Settings > Privacy & Security > Speech Recognition"
                    )
                case .restricted, .notDetermined:
                    self.logger.log("Speech recognition status: \(status)", type: .warning)
                @unknown default:
                    self.logger.log("Speech recognition unknown status: \(status)", type: .error)
                }
            }
        }
        // Check AVCaptureDevice authorization to access the microphone
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.logger.log("Microphone access granted: \(granted)", type: .debug)
                if granted {
                    self.logger.log("Microphone access granted", type: .info)
                } else {
                    self.logger.log("Microphone access denied", type: .error)
                    self.showPermissionAlert(
                        title: "Microphone Access Required",
                        message: "Please enable Microphone access in System Settings > Privacy & Security > Microphone"
                    )
                }
            }
        }
        // Accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        logger.log("Accessibility permissions enabled: \(accessibilityEnabled)", type: .debug)
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
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice Dictate")
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        logger.log("Menu bar setup complete", type: .debug)
    }
    
    @objc private func statusItemClicked(sender: NSStatusBarButton) {
        // Check if right-clicked
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu()
        } else {
            // Left-click toggles dictation
            toggleDictation()
        }
    }
    
    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: isListening ? "Stop Dictation" : "Start Dictation", action: #selector(toggleDictation), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }
    
    private func updateMenuBarIcon() {
        if let button = statusItem.button {
            if isListening {
                button.image = NSImage(
                    systemSymbolName: "mic.fill",
                    accessibilityDescription: "Voice Dictate (Recording)"
                )
                // Add red tint to indicate active recording
                button.contentTintColor = NSColor.systemRed
            } else {
                button.image = NSImage(
                    systemSymbolName: "mic",
                    accessibilityDescription: "Voice Dictate"
                )
                // Reset tint color
                button.contentTintColor = nil
            }
        }
    }
    
    // MARK: - Speech Recognition
    
    private func setupSpeechRecognition() {
        let locale = Locale(identifier: Defaults[.selectedLanguage])
        logger.log("Initializing SFSpeechRecognizer with locale: \(locale.identifier)", type: .debug)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer.delegate = self
        logger.log("AVAudioEngine initialized", type: .debug)
        // Log on-device support
        logger.log("Speech recognizer supports on-device recognition: \(speechRecognizer.supportsOnDeviceRecognition)", type: .info)
        // Backend selection logic
        let backend = Defaults[.speechBackend]
        logger.log("Speech backend selected: \(backend)", type: .info)
        if backend == "google_gemini" {
            logger.log("Google Gemini backend selected. (Not yet implemented)", type: .warning)
            // Placeholder: actual Gemini API integration would go here
        } else if backend == "apple_ondevice" {
            if speechRecognizer.supportsOnDeviceRecognition {
                logger.log("Configuring for on-device recognition only.", type: .info)
            } else {
                logger.log("On-device recognition not supported for this locale/device.", type: .error)
            }
        }
        audioEngine = AVAudioEngine()
        // Configure audio input
        configureAudioInput()
        logger.log("Speech recognition setup complete with locale: \(locale.identifier)", type: .debug)
    }
    
    private func configureAudioInput() {
        inputNode = audioEngine.inputNode
        logger.log("Configuring audio input node", type: .debug)
        // Check if a specific microphone is selected
        let selectedMicID = Defaults[.selectedMicrophoneID]
        if !selectedMicID.isEmpty {
            logger.log("Attempting to use selected microphone: \(selectedMicID)", type: .verbose)
            // In a real implementation, you would use the Audio Unit API to select the specific device
        } else {
            logger.log("Using default system microphone", type: .verbose)
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        logger.log("Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels", type: .verbose)
    }
    
    // MARK: - Dictation Control
    
    private func startDictation() {
        guard !isListening else { logger.log("startDictation called but already listening", type: .warning); return }
        logger.log("Starting dictation...", type: .info)
        logger.log("AudioEngine running: \(audioEngine.isRunning)", type: .debug)
        logger.log("Recognizer locale: \(speechRecognizer.locale.identifier)", type: .debug)
        let backend = Defaults[.speechBackend]
        let locale = Defaults[.selectedLanguage]
        if backend == "apple_ondevice" && !speechRecognizer.supportsOnDeviceRecognition {
            logger.log("On-device recognition is not supported for locale: \(locale)", type: .error)
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "On-Device Recognition Not Available"
                alert.informativeText = "On-device speech recognition is not supported for the selected language (\(locale)) or your macOS version. Falling back to Apple Cloud recognition."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            // Fallback to cloud recognition
            logger.log("Falling back to Apple Cloud recognition.", type: .warning)
        }
        do {
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            if backend == "google_gemini" {
                // Prepare WAV file for Gemini
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent("gemini_input.wav")
                geminiAudioURL = fileURL
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                geminiAudioFile = try AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                    guard let self = self else { return }
                    do {
                        try self.geminiAudioFile?.write(from: buffer)
                        self.logger.log("Wrote audio buffer to Gemini WAV file", type: .verbose)
                    } catch {
                        self.logger.log("Failed to write audio buffer to file: \(error)", type: .error)
                    }
                }
            } else {
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
                    guard let self = self else { return }
                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.shouldReportPartialResults = true
                    // If on-device only is selected, set the property
                    if backend == "apple_ondevice" && self.speechRecognizer.supportsOnDeviceRecognition {
                        request.requiresOnDeviceRecognition = true
                        self.logger.log("Using Apple On-Device recognition.", type: .info)
                    } else if backend == "apple_ondevice" && !self.speechRecognizer.supportsOnDeviceRecognition {
                        request.requiresOnDeviceRecognition = false
                        self.logger.log("Falling back to Apple Cloud recognition (on-device not supported).", type: .warning)
                    }
                    self.logger.log("Audio buffer received for recognition", type: .verbose)
                    self.recognitionTask = self.speechRecognizer.recognitionTask(with: request) { result, error in
                        if let error = error {
                            self.logger.log("Recognition error: \(error.localizedDescription)", type: .error)
                            return
                        }
                        if let result = result {
                            let text = result.bestTranscription.formattedString
                            self.logger.log("Transcription: \(text)", type: .verbose)
                            self.handleRecognizedText(text)
                        }
                    }
                }
            }
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            dictationStartTime = Date()
            dictationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateStatusWindow()
            }
            updateMenuBarIcon()
            if Defaults[.showTranscriptionWindow] {
                logger.log("Showing transcription window (status window will be hidden)", type: .info)
                hideStatusWindow()
                TranscriptionWindowManager.shared.showWindow()
            } else {
                logger.log("Showing status window (transcription window will be hidden)", type: .info)
                TranscriptionWindowManager.shared.hideWindow()
                showStatusWindow()
            }
            showNotification(title: "Dictation Started", body: "Voice dictation is now active")
            logger.log("Dictation started successfully", type: .info)
        } catch {
            logger.log("Failed to start audio engine: \(error.localizedDescription)", type: .error)
            print("Audio engine failed to start: \(error)")
        }
    }
    
    private func stopDictation() {
        logger.log("Stopping dictation...", type: .info)
        let backend = Defaults[.speechBackend]
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        dictationStartTime = nil
        dictationTimer?.invalidate()
        dictationTimer = nil
        updateMenuBarIcon()
        logger.log("Hiding status and transcription windows", type: .debug)
        hideStatusWindow()
        TranscriptionWindowManager.shared.hideWindow()
        if backend == "google_gemini" {
            logger.log("Sending audio file to Gemini API", type: .info)
            sendAudioToGemini()
        }
        showNotification(title: "Dictation Stopped", body: "Voice dictation has been deactivated")
        logger.log("Dictation stopped", type: .info)
    }
    
    private func sendAudioToGemini() {
        guard let fileURL = geminiAudioURL else {
            logger.log("No audio file URL for Gemini", type: .error)
            return
        }
        let apiKey = Defaults[.geminiApiKey]
        guard !apiKey.isEmpty else {
            logger.log("No Gemini API key set in preferences", type: .error)
            return
        }
        do {
            let audioData = try Data(contentsOf: fileURL)
            let base64Audio = audioData.base64EncodedString()
            let requestBody: [String: Any] = [
                "contents": [
                    [
                        "role": "user",
                        "parts": [
                            [
                                "inline_data": [
                                    "mime_type": "audio/wav",
                                    "data": base64Audio
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=\(apiKey)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            logger.log("Sending request to Gemini API...", type: .info)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    self.logger.log("Gemini API request failed: \(error)", type: .error)
                    return
                }
                guard let data = data else {
                    self.logger.log("No data received from Gemini API", type: .error)
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let content = candidates.first?["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let text = parts.first?["text"] as? String {
                        self.logger.log("Gemini transcription: \(text)", type: .info)
                        DispatchQueue.main.async {
                            TranscriptionWindowManager.shared.updateTranscription(text)
                            self.handleRecognizedText(text)
                        }
                    } else {
                        self.logger.log("Unexpected Gemini API response: \(String(data: data, encoding: .utf8) ?? "<nil>")", type: .error)
                    }
                } catch {
                    self.logger.log("Failed to parse Gemini API response: \(error)", type: .error)
                }
            }
            task.resume()
        } catch {
            logger.log("Failed to read audio file for Gemini: \(error)", type: .error)
        }
    }
    
    @objc private func toggleDictation() {
        if isListening {
            stopDictation()
        } else {
            startDictation()
        }
    }
    
    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Status Window
    
    private func showStatusWindow() {
        logger.log("Showing status window", type: .debug)
        if statusWindow == nil {
            statusWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
                styleMask: [.titled, .closable, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            statusWindow?.title = "Voice Dictation Active"
            statusWindow?.isMovableByWindowBackground = true
            statusWindow?.backgroundColor = NSColor.controlBackgroundColor
            statusWindow?.hasShadow = true
            statusWindow?.level = .floating
            let customView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
            let statusLabel = NSTextField(labelWithString: "Recording... 0:00")
            statusLabel.frame = NSRect(x: 50, y: 20, width: 200, height: 20)
            statusLabel.alignment = .center
            statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            statusLabel.tag = 100 // Set tag for later reference
            let imageView = NSImageView(frame: NSRect(x: 15, y: 18, width: 24, height: 24))
            imageView.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Microphone")
            imageView.contentTintColor = NSColor.systemRed
            customView.addSubview(statusLabel)
            customView.addSubview(imageView)
            statusWindow?.contentView = customView
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let windowRect = statusWindow!.frame
                let newOrigin = NSPoint(
                    x: screenRect.maxX - windowRect.width - 20,
                    y: screenRect.minY + 20
                )
                statusWindow?.setFrameOrigin(newOrigin)
            }
        }
        statusWindow?.makeKeyAndOrderFront(nil)
        updateStatusWindow()
    }
    
    private func hideStatusWindow() {
        logger.log("Hiding status window", type: .debug)
        statusWindow?.orderOut(nil)
    }
    
    private func updateStatusWindow() {
        guard let window = statusWindow, let startTime = dictationStartTime else { return }
        
        // Calculate duration
        let duration = Int(Date().timeIntervalSince(startTime))
        let minutes = duration / 60
        let seconds = duration % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)
        
        // Update label
        if let contentView = window.contentView, let label = contentView.viewWithTag(100) as? NSTextField {
            label.stringValue = "Recording... \(timeString)"
        }
    }
    
    // MARK: - Global Shortcut
    
    private func registerGlobalShortcut() {
        // Although we can't implement global shortcuts without additional frameworks,
        // we can log that this feature would require a Carbon or third-party implementation
        logger.log("Global shortcut would use key: \(Defaults[.customShortcut])", type: .info)
        logger.log("Note: Global shortcut registration requires Carbon Hot Key API or third-party framework", type: .warning)
    }
    
    // MARK: - Text Handling
    
    private func handleRecognizedText(_ text: String) {
        // Update transcription window
        if Defaults[.showTranscriptionWindow] {
            TranscriptionWindowManager.shared.updateTranscription(text)
        }
        
        // Process for commands
        let (processedText, isCommand) = VoiceCommandService.shared.processCommand(text)
        
        if isCommand {
            logger.log("Detected command in text: '\(text)'", type: .debug)
        }
        
        if !isCommand && !processedText.isEmpty {
            logger.log("Inserting text: '\(processedText)'", type: .verbose)
            TextInsertionService.shared.insertText(processedText)
        }
    }
    
    // MARK: - Preferences
    
    @objc private func openPreferences() {
        logger.log("Opening preferences window", type: .info)
        
        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
            let hostingController = NSHostingController(rootView: preferencesView)
            
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            preferencesWindow?.center()
            preferencesWindow?.setFrameAutosaveName("Preferences")
            preferencesWindow?.title = "VoiceDictate Preferences"
            preferencesWindow?.contentView = hostingController.view
            
            // Close button handler
            preferencesWindow?.standardWindowButton(.closeButton)?.target = self
            preferencesWindow?.standardWindowButton(.closeButton)?.action = #selector(closePreferences)
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func closePreferences() {
        logger.log("Closing preferences window", type: .info)
        preferencesWindow?.orderOut(nil)
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            logger.log("Speech recognition became available", type: .info)
        } else {
            logger.log("Speech recognition became unavailable", type: .warning)
        }
    }
} 