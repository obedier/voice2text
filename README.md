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

- macOS 13.0 or later
- Swift 5.9 or later

## Development Environment Setup

This project can be built entirely using command-line tools, without requiring Xcode. Here's how to set up your development environment:

### 1. Install Swift via Homebrew

```bash
brew install swift
```

Add the Homebrew Swift to your PATH:

```bash
export PATH="/opt/homebrew/opt/swift/bin:$PATH"
```

Add the above line to your shell profile file (~/.zshrc or ~/.bash_profile) to make it permanent.

### 2. Install Required Dependencies

```bash
brew install swift-format # Optional but recommended for code formatting
```

### 3. Project Structure

The project follows a standard Swift Package Manager structure:

```
voice2text/
├── Package.swift                 # Swift Package Manager manifest
├── build_app.sh                  # Script to build macOS app bundle
├── src/
│   └── VoiceDictate/
│       ├── Sources/              # Application source code
│       │   ├── Info.plist        # App Info.plist file
│       │   ├── main.swift        # Application entry point
│       │   ├── AppDelegate.swift # Main app delegate
│       │   └── ...               # Other Swift source files
│       └── Tests/                # Test files
└── build/                        # Build output directory (created by build script)
    └── VoiceDictate.app          # Built macOS application
```

## Building the Project

### Command-Line Build

To build the project from the command line:

```bash
# Build in debug mode
swift build

# Build in release mode
swift build -c release
```

### Building a Full macOS App Bundle

The project includes a script to build a complete macOS .app bundle:

```bash
chmod +x build_app.sh
./build_app.sh
```

This script:
1. Builds the project in release mode
2. Creates a proper macOS .app bundle structure
3. Sets up the Info.plist and resources
4. Makes the app executable

### Build Issues and Solutions

If you encounter build issues, try these solutions:

#### Swift Version Mismatch
If you see an error about Swift version mismatch, ensure you're using Homebrew's Swift:
```bash
export PATH="/opt/homebrew/opt/swift/bin:$PATH"
swift --version  # Should match the version in Package.swift
```

#### Top-Level Code Error
If you see "`main` attribute cannot be used in a module that contains top-level code", check that:
- Your entry point is defined properly in main.swift
- You don't have multiple @main declarations

#### AVAudioSession Unavailable on macOS
AVAudioSession is not available on macOS. Use AVCaptureDevice for permission handling and AVAudioEngine for audio capture.

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/VoiceDictate.git
cd VoiceDictate
```

2. Build the application using the provided script:
```bash
chmod +x build_app.sh
./build_app.sh
```

3. Run the application:
```bash
open ./build/VoiceDictate.app
```

Alternatively, you can copy the app to your Applications folder:
```bash
cp -r ./build/VoiceDictate.app /Applications/
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

This project is licensed under the MIT License - see the LICENSE file for details. 