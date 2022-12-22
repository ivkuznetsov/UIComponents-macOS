//
//  CollectionView.swift
//

import AppKit

open class CollectionView: NSCollectionView {
    
    private var registeredCells: Set<NSUserInterfaceItemIdentifier> = Set()
    
    func make<T: NSCollectionViewItem>(_ item: T.Type, at indexPath: IndexPath) -> T {
        let identifier = NSUserInterfaceItemIdentifier(rawValue: item.classNameWithoutModule())
        
        if !registeredCells.contains(identifier) {
            register(NSNib(nibNamed: identifier.rawValue, bundle: Bundle(for: item)), forItemWithIdentifier: identifier)
            registeredCells.insert(identifier)
        }
        
        return makeItem(withIdentifier: identifier, for: indexPath) as! T
    }
    
    open override var acceptsFirstResponder: Bool { false }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        (delegate as? Collection)?.visible = window != nil
    }
}
