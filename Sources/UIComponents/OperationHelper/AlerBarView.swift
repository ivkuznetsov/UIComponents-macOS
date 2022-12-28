//
//  AlerBarView.swift
//

import AppKit

open class AlertBarView: NSView {
    
    @IBOutlet open var textLabel: NSTextField!
    @IBOutlet open var container: NSView!
    var dismissTime: TimeInterval = 5
    
    open func present(in view: NSView, message: String) {
        if view.superview == view, textLabel.stringValue == message { return }
        
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        view.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        
        self.textLabel.stringValue = message
        self.alphaValue = 0
        self.animator().alphaValue = 1
        
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + self.dismissTime) {
                self.hide()
            }
        }
    }
    
    open var message: String { textLabel.stringValue }
    
    open func hide() {
        NSAnimationContext.runAnimationGroup { _ in
            self.animator().alphaValue = 0.0
        } completionHandler: {
            self.removeFromSuperview()
        }
    }
}
