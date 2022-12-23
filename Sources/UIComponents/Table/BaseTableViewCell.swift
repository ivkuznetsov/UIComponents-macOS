//
//  BaseTableViewCell.swift
//

import AppKit

open class BaseTableViewCell: NSTableRowView {
    
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
