// This file is intentionally left empty. The app entry point is in App.swift 

import Cocoa

// Traditional AppKit entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv) 