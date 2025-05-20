import SwiftUI

class TranscriptionWindowController: NSWindowController {
    convenience init(text: Binding<String>) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Voice Dictation"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("TranscriptionWindow")
        
        let contentView = TranscriptionView(text: text)
        window.contentView = NSHostingView(rootView: contentView)
        
        self.init(window: window)
    }
}

struct TranscriptionView: View {
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            Text(text.isEmpty ? "Listening..." : text)
                .font(.system(size: 16))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
            
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                Text("Recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
    }
}

class TranscriptionWindowManager {
    static let shared = TranscriptionWindowManager()
    private var windowController: TranscriptionWindowController?
    @Published private var transcriptionText: String = ""
    
    private init() {}
    
    func showWindow() {
        DebugLogger.shared.log("Transcription window shown", type: .debug)
        if windowController == nil {
            windowController = TranscriptionWindowController(
                text: Binding(
                    get: { self.transcriptionText },
                    set: { self.transcriptionText = $0 }
                )
            )
        }
        windowController?.showWindow(nil)
        windowController?.window?.level = .floating
    }
    
    func hideWindow() {
        DebugLogger.shared.log("Transcription window hidden", type: .debug)
        windowController?.close()
        windowController = nil
        transcriptionText = ""
    }
    
    func updateTranscription(_ text: String) {
        transcriptionText = text
    }
} 