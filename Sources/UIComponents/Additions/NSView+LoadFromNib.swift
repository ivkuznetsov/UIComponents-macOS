//
//  UIView+LoadFromNib.swift
//

import CommonUtils
import AppKit

public extension NSView {
    
    static func loadFromNib(_ nib: String? = nil, owner: Any? = nil) -> Self {
        loadFrom(nib: nib ?? String(describing: self), owner: owner, type: self)
    }
    
    static func loadFrom<T: NSView>(nib: String, owner: Any?, type: T.Type) -> T  {
        var bundle = Bundle.main
        if bundle.path(forResource: nib, ofType: "nib") == nil {
            bundle = Bundle(for: type)
        }
        if bundle.path(forResource: nib, ofType: "nib") == nil {
            bundle = Bundle.module
        }
        
        var array: NSArray? = nil
        bundle.loadNibNamed(nib, owner: self, topLevelObjects: &array)
        
        return (array as! [Any]).first(where: { $0 is T }) as! T // crash if didn't find
    }
}
