//
//  BoundsResizableLayout.swift
//

import AppKit

class BoundsResizableLayout: NSCollectionViewFlowLayout {
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        return needsRelayout(size: newBounds.size, oldSize: collectionViewContentSize)
    }

    private func needsRelayout(size: NSSize, oldSize: NSSize) -> Bool {
        if scrollDirection == .horizontal {
            return size.height != oldSize.height
        }
        return size.width != oldSize.width
    }
    
    
    override func invalidationContext(forBoundsChange newBounds: NSRect) -> NSCollectionViewLayoutInvalidationContext {
        let context = NSCollectionViewFlowLayoutInvalidationContext()
        context.invalidateFlowLayoutAttributes = true
        context.invalidateFlowLayoutDelegateMetrics = true
        return context
    }
}
