//
//  NoObjectsView.swift
//

import Foundation
import AppKit

open class NoObjectsView: NSBox {
    
    @IBOutlet public var image: NSImageView!
    @IBOutlet public var header: NSTextField!
    @IBOutlet public var details: NSTextField!
    @IBOutlet public var actionButton: NSButton!
    
    public var actionClosure: (()->())? {
        didSet {
            actionButton.isHidden = actionClosure == nil
        }
    }
    
    @IBAction public func action(_ sender: NSButton) {
        actionClosure?()
    }
}
