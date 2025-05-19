# VoiceDictate

A powerful, privacy-focused voice dictation application for macOS that enables system-wide voice input into any text field.

## Features

- System-wide voice dictation that works in any application
- Clean, non-intrusive menu bar interface
- Real-time transcription with visual feedback
- Support for multiple languages
- Privacy-focused with local processing
- Voice commands for punctuation and text formatting
- Global keyboard shortcut support
- Light/Dark mode support

## Requirements

- macOS 12.0 or later
- Swift 5.5 or later

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/VoiceDictate.git
cd VoiceDictate
```

2. Build the application:
```bash
swift build -c release
```

3. Copy the built application to your Applications folder:
```bash
cp -r .build/release/VoiceDictate.app /Applications/
```

## Usage

### First Launch

1. Launch VoiceDictate from your Applications folder
2. Grant necessary permissions when prompted:
   - Accessibility access (for text insertion)
   - Microphone access (for voice input)
   - Speech Recognition access (for dictation)

### Basic Usage

1. Click the microphone icon in the menu bar to start/stop dictation
2. Use the keyboard shortcut (default: ⌘D) to toggle dictation
3. Speak naturally - your words will be inserted at the cursor position

### Voice Commands

- "New Line" - Start a new line
- "Period" - Add a period
- "Comma" - Add a comma
- "Question Mark" - Add a question mark
- "Exclamation Mark" - Add an exclamation mark
- "Delete Last Word" - Remove the last word
- "Select All" - Select all text
- "Copy" - Copy selected text
- "Paste" - Paste text
- "Undo" - Undo last action

### Text Formatting Commands

- "Capitalize [text]" - Capitalize the specified text
- "Uppercase [text]" - Convert text to uppercase
- "Lowercase [text]" - Convert text to lowercase

## Preferences

Access preferences through:
- Menu bar icon → Preferences
- Keyboard shortcut: ⌘,

### Settings Available

- Language selection
- Keyboard shortcuts
- Transcription window visibility
- Voice command customization

## Privacy

VoiceDictate prioritizes your privacy:
- All speech processing is done locally on your device
- No audio data is sent to external servers
- No usage data is collected

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. # voice2text
