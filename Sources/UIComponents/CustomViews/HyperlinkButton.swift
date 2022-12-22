//
//  HyperlinkButton.swift
//

import AppKit

public class HyperlinkButton: NSButton {
    
    @IBInspectable public var linkColor: NSColor = {
        if #available(OSX 10.14, *) {
            return .linkColor
        } else {
            return NSColor(calibratedRed: 0.0/255.0, green: 104.0/255.0, blue: 218.0/255.0, alpha: 1.0)
        }
    }()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isBordered = false
        refusesFirstResponder = true
        
        if #available(OSX 10.14, *) {
            contentTintColor = linkColor
        } else {
            attributedTitle = {
                let attr = NSMutableAttributedString(attributedString: attributedTitle)
                let wholeLength = NSRange(location: 0, length: attr.length)
                attr.addAttribute(.foregroundColor, value: linkColor, range: wholeLength)
                return attr
            }()
        }
    }
    
    override public func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
}
