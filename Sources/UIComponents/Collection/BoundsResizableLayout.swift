//
//  BoundsResizableLayout.swift
//

import AppKit

class BoundsResizableLayout: NSCollectionViewFlowLayout {
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        if scrollDirection == .horizontal {
            return newBounds.height != collectionViewContentSize.height
        } else {
            return newBounds.width != collectionViewContentSize.width
        }
    }
    
    override func invalidationContext(forBoundsChange newBounds: NSRect) -> NSCollectionViewLayoutInvalidationContext {
        let context = NSCollectionViewFlowLayoutInvalidationContext()
        context.invalidateFlowLayoutAttributes = true
        context.invalidateFlowLayoutDelegateMetrics = true
        return context
    }
}
