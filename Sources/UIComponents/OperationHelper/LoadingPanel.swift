//
//  LoadingPanel.swift
//

import AppKit

open class LoadingPanel: NSPanel {
    
    @IBOutlet private var indicator: NSProgressIndicator!
    @IBOutlet private var label: NSTextField!
    @IBOutlet private var button: NSButton!
    
    open var cancel: (()->())? {
        didSet {
            button.isHidden = cancel == nil
        }
    }
    
    open var progress: CGFloat = 0 {
        didSet {
            indicator?.doubleValue = progress
        }
    }
    
    public static func present(in window: NSWindow?, label: String, cancel: (()->())?) -> LoadingPanel {
        let panel = self.loadFromNib()
        panel.label.stringValue = label
        panel.cancel = cancel
        panel.indicator.doubleValue = 0
        panel.indicator.usesThreadedAnimation = false
        if let window = window {
            window.beginSheet(panel, completionHandler: nil)
        } else {
            panel.presentAboveCurrentWindow()
        }
        return panel
    }
    
    open func hide() {
        if let parent = sheetParent {
            parent.endSheet(self)
        } else {
            close()
        }
    }
    
    @IBAction private func cancelAction(_ sender: Any?) {
        cancel?()
    }
}
