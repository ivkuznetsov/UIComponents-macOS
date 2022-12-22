//
//  ReusableView.swift
//

import AppKit

open class ReusableView: NSView {
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        attach(NSView.loadFromNib(classNameWithoutModule(), owner: self))
    }
    
    public override required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    public static func make() -> Self {
        let selfView = Self.init(frame: .zero)
        let view = NSView.loadFromNib(classNameWithoutModule(), owner: selfView)
        selfView.frame = view.frame
        selfView.attach(view)
        return selfView
    }
}
