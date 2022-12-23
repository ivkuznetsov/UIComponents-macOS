//
//  NSWindow+Addditions.swift
//

import AppKit

public extension NSWindow {
    
    func presentAboveCurrentWindow() {
        let window = NSApplication.shared.keyWindow
        makeKeyAndOrderFront(nil)
        level = .modalPanel
        
        if let window = window {
            setFrameOrigin(NSPoint(x: window.frame.origin.x + window.frame.size.width / 2 - frame.size.width / 2, y: window.frame.origin.y + window.frame.size.height / 2 - frame.size.height / 2))
        }
    }
}

