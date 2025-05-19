import Cocoa
import ApplicationServices

class TextInsertionService {
    static let shared = TextInsertionService()
    
    private init() {
        checkAccessibilityPermissions()
    }
    
    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessibilityEnabled {
            print("Accessibility access is required for text insertion")
        }
    }
    
    func insertText(_ text: String) {
        guard let systemWideElement = AXUIElementCreateSystemWide() as AXUIElement? else {
            print("Failed to create system-wide accessibility element")
            return
        }
        
        var focusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard error == .success else {
            print("Failed to get focused element: \(error)")
            return
        }
        
        guard let focusedElement = focusedElement else {
            print("No focused element found")
            return
        }
        
        // First try to set the value directly
        let setValueError = AXUIElementSetAttributeValue(
            focusedElement as! AXUIElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )
        
        if setValueError != .success {
            // If direct value setting fails, simulate keyboard input
            simulateKeyboardInput(text)
        }
    }
    
    private func simulateKeyboardInput(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        for character in text {
            // Convert character to keycode and simulate keypress
            if let keyCode = character.keyCode {
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        }
    }
}

// Extension to help with character to keycode conversion
extension Character {
    var keyCode: CGKeyCode? {
        let keyMap: [Character: CGKeyCode] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03,
            "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
            "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
            "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
            "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
            "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C,
            "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20,
            "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25,
            "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
            "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D,
            "m": 0x2E, ".": 0x2F, "`": 0x32, " ": 0x31,
            "\n": 0x24
        ]
        
        return keyMap[self.lowercased().first ?? self]
    }
} 