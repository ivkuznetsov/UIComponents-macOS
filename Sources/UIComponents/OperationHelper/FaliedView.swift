//
//  FailedView.swift
//

import AppKit

open class FailedView: NSBox {
    
    @IBOutlet open var image: NSImageView?
    @IBOutlet open var textLabel: NSTextField?
    @IBOutlet open var retryButton: NSButton?
    
    private var retry: (()->())? {
        didSet { retryButton?.isHidden = retry == nil }
    }
    
    open func present(in view: NSView, text: String, retry: (()->())?) {
        textLabel?.stringValue = text
        self.retry = retry
        view.attach(self)
        configure()
    }
    
    open func configure() { }
    
    @IBAction open func retryAction(_ sender: NSButton) {
        retry?()
    }
}
