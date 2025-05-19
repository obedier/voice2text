import Foundation
import CoreGraphics

enum VoiceCommand: String {
    case newLine = "new line"
    case period = "period"
    case comma = "comma"
    case questionMark = "question mark"
    case exclamationMark = "exclamation mark"
    case deleteLastWord = "delete last word"
    case selectAll = "select all"
    case copy = "copy"
    case paste = "paste"
    case undo = "undo"
    
    var textValue: String? {
        switch self {
        case .newLine: return "\n"
        case .period: return "."
        case .comma: return ","
        case .questionMark: return "?"
        case .exclamationMark: return "!"
        default: return nil
        }
    }
    
    var keyboardShortcut: (key: CGKeyCode, modifiers: CGEventFlags)? {
        switch self {
        case .selectAll: return (0x00, CGEventFlags.maskCommand) // Command + A
        case .copy: return (0x08, CGEventFlags.maskCommand) // Command + C
        case .paste: return (0x09, CGEventFlags.maskCommand) // Command + V
        case .undo: return (0x07, CGEventFlags.maskCommand) // Command + Z
        default: return nil
        }
    }
}

class VoiceCommandService {
    static let shared = VoiceCommandService()
    
    private init() {}
    
    func processCommand(_ text: String) -> (processedText: String, isCommand: Bool) {
        let lowercasedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let command = VoiceCommand(rawValue: lowercasedText) {
            handleCommand(command)
            return ("", true)
        }
        
        // Process text formatting commands
        if lowercasedText.contains("capitalize") {
            return (text.capitalized, true)
        }
        
        if lowercasedText.contains("uppercase") {
            return (text.uppercased(), true)
        }
        
        if lowercasedText.contains("lowercase") {
            return (text.lowercased(), true)
        }
        
        return (text, false)
    }
    
    private func handleCommand(_ command: VoiceCommand) {
        if let textValue = command.textValue {
            TextInsertionService.shared.insertText(textValue)
            return
        }
        
        if let shortcut = command.keyboardShortcut {
            simulateKeyboardShortcut(key: shortcut.key, modifiers: shortcut.modifiers)
        }
        
        switch command {
        case .deleteLastWord:
            // Simulate Option + Delete to delete last word
            simulateKeyboardShortcut(key: 0x33, modifiers: CGEventFlags.maskAlternate)
        default:
            break
        }
    }
    
    private func simulateKeyboardShortcut(key: CGKeyCode, modifiers: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return }
        
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
} 