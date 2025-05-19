import SwiftUI
import AVFoundation

class TranscriptionWindowController: NSWindowController {
    convenience init(text: Binding<String>, audioLevel: Binding<Float>) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Voice Dictation"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("TranscriptionWindow")
        
        let contentView = TranscriptionView(text: text, audioLevel: audioLevel)
        window.contentView = NSHostingView(rootView: contentView)
        
        self.init(window: window)
    }
}

struct AudioLevelMeter: View {
    let level: Float
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: geometry.size.width, height: 6)
                    .cornerRadius(3)
                
                // Animated level bar
                Rectangle()
                    .fill(levelColor)
                    .frame(width: max(CGFloat(level) * geometry.size.width, 6), height: 6)
                    .cornerRadius(3)
                    .shadow(color: levelColor.opacity(0.3), radius: 2)
                    .animation(.easeOut(duration: 0.1), value: level)
                
                // Pulsing dot for active recording
                Circle()
                    .fill(levelColor)
                    .frame(width: 8, height: 8)
                    .offset(x: max((CGFloat(level) * geometry.size.width) - 4, 2))
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
            }
        }
        .frame(height: 6)
        .onAppear {
            isAnimating = true
        }
    }
    
    private var levelColor: Color {
        if level < 0.3 {
            return .green
        } else if level < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct TranscriptionView: View {
    @Binding var text: String
    @Binding var audioLevel: Float
    @Environment(\.colorScheme) var colorScheme
    @State private var isRecognizingSpeech = false
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(text.isEmpty ? "Listening..." : text)
                .font(.system(size: 16))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
            
            AudioLevelMeter(level: audioLevel)
                .padding(.horizontal)
            
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .scaleEffect(isRecognizingSpeech ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecognizingSpeech)
                
                Text(isRecognizingSpeech ? "Recognizing Speech..." : "Recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Add a visual indicator for speech recognition confidence
                if isRecognizingSpeech {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
        .onChange(of: text) { _ in
            // Briefly show the recognition indicator when text changes
            isRecognizingSpeech = true
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isRecognizingSpeech = false
                isAnimating = false
            }
        }
    }
}

class TranscriptionWindowManager {
    static let shared = TranscriptionWindowManager()
    private var windowController: TranscriptionWindowController?
    @Published private var transcriptionText: String = ""
    @Published private var audioLevel: Float = 0.0
    private var audioLevelTimer: Timer?
    
    private init() {}
    
    func showWindow() {
        if windowController == nil {
            windowController = TranscriptionWindowController(
                text: Binding(
                    get: { self.transcriptionText },
                    set: { self.transcriptionText = $0 }
                ),
                audioLevel: Binding(
                    get: { self.audioLevel },
                    set: { self.audioLevel = $0 }
                )
            )
        }
        windowController?.showWindow(nil)
        windowController?.window?.level = .floating
    }
    
    func hideWindow() {
        windowController?.close()
        windowController = nil
        transcriptionText = ""
        audioLevel = 0.0
        stopAudioLevelMonitoring()
    }
    
    func updateTranscription(_ text: String) {
        transcriptionText = text
    }
    
    func startAudioLevelMonitoring(audioEngine: AVAudioEngine) {
        audioLevelTimer?.invalidate()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            let inputNode = audioEngine.inputNode
            let level = inputNode.volume
            self?.audioLevel = level
        }
    }
    
    func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
} 