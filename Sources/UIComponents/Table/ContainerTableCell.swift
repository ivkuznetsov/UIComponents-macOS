//
//  ContainerTableCell.swift
//

import AppKit

public class ContainerTableCell: BaseTableViewCell {
    
    fileprivate var attachedView: NSView? { subviews.last }
    
    func attach(viewToAttach: NSView) {
        if viewToAttach == attachedView { return }
        
        attachedView?.removeFromSuperview()
        attach(viewToAttach)
    }
}
