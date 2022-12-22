//
//  AlerBarView.swift
//

import AppKit

open class AlertBarView: NSView {
    
    @IBOutlet open var textLabel: NSTextField!
    @IBOutlet open var container: NSView!
    var dismissTime: TimeInterval = 5
    
    open class func present(in view: NSView, message: String) -> Self {
        let barView = loadFromNib()
        barView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(barView)
        view.leftAnchor.constraint(equalTo: barView.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: barView.rightAnchor).isActive = true
        view.topAnchor.constraint(equalTo: barView.topAnchor).isActive = true
        
        barView.textLabel.stringValue = message
        barView.alphaValue = 0
        barView.animator().alphaValue = 1
        
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + barView.dismissTime) {
                barView.hide()
            }
        }
        return barView
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
