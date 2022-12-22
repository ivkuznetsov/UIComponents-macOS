//
//  FirstResponderPreserver.swift
//

import AppKit

public class FirstResponderPreserver {
    private weak var textField: NSTextField?
    private var selection: NSRange?
    
    public init(window: NSWindow?) {
        if let firstResponder = window?.firstResponder as? NSTextView {
            var view: NSView? = firstResponder
            while view != nil && !(view is NSTextField) {
                view = view!.superview
            }
            textField = view as? NSTextField
            selection = firstResponder.selectedRange()
        }
    }
    
    func commit() {
        if let textField = textField, let selection = selection {
            if let window = textField.window {
                window.makeFirstResponder(textField)
                textField.currentEditor()?.selectedRange = selection
            } else {
                DispatchQueue.main.async {
                    if let window = textField.window {
                        window.makeFirstResponder(textField)
                        textField.currentEditor()?.selectedRange = selection
                    }
                }
            }
        }
        textField = nil
        selection = nil
    }
    
    deinit {
        commit()
    }
}
