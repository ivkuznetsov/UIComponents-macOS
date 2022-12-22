//
//  NSWindow+Addditions.swift
//

import AppKit

public extension NSWindow {
    
    static func loadFromNib() -> Self {
        let nibName = classNameWithoutModule()
        
        let nib = NSNib(nibNamed: nibName, bundle: .main)
        
        var topLevelObjects: NSArray?
        nib?.instantiate(withOwner: nil, topLevelObjects: &topLevelObjects)
        
        if let array = topLevelObjects {
            for object in array {
                if let object = object as? Self {
                    return object
                }
            }
        }
        fatalError("Could not load view from nib named \(nibName)")
    }
    
    func presentAboveCurrentWindow() {
        let window = NSApplication.shared.keyWindow
        makeKeyAndOrderFront(nil)
        level = .modalPanel
        
        if let window = window {
            setFrameOrigin(NSPoint(x: window.frame.origin.x + window.frame.size.width / 2 - frame.size.width / 2, y: window.frame.origin.y + window.frame.size.height / 2 - frame.size.height / 2))
        }
    }
}

