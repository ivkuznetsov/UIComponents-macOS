//
//  ContainerCollectionCell.swift
//

import AppKit

class ContainerCollectionItem: NSCollectionViewItem {
    
    var attachedView: NSView? { view.subviews.last }
    
    func attach(_ viewToAttach: NSView) {
        if viewToAttach == attachedView { return }
        
        attachedView?.removeFromSuperview()
        
        viewToAttach.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewToAttach)
        view.leftAnchor.constraint(equalTo: viewToAttach.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: viewToAttach.rightAnchor).isActive = true
        view.topAnchor.constraint(equalTo: viewToAttach.topAnchor).isActive = true
        
        let bottom = view.bottomAnchor.constraint(equalTo: viewToAttach.bottomAnchor)
        bottom.priority = .init(500)
        bottom.isActive = true
    }
    
    override func loadView() {
        view = NSView()
    }
}
