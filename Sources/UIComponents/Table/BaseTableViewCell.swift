//
//  BaseTableViewCell.swift
//

import AppKit

public protocol ObjectHolder: AnyObject {
    
    var object: AnyHashable? { get set }
}

open class BaseTableViewCell: NSTableRowView, ObjectHolder {
    
    public var object: AnyHashable?
    
    open override func drawSeparator(in dirtyRect: NSRect) {
        if !isSelected && !isNextRowSelected {
            super.drawSeparator(in: dirtyRect)
        }
    }

    open override var isNextRowSelected: Bool {
        get { super.isNextRowSelected }
        set {
            super.isNextRowSelected = newValue
            self.needsDisplay = true
        }
    }
}
