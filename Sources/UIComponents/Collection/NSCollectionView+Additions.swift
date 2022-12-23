//
//  NSCollectionView+Additions.swift
//

import AppKit
import CommonUtils

extension NSCollectionView {
    
    func reload(animated: Bool,
                expandBottom: Bool,
                oldData: [AnyHashable],
                newData: [AnyHashable],
                updateObjects: ()->(),
                completion: @escaping ()->()) {
        
        let oldRect = enclosingScrollView?.documentVisibleRect ?? .zero
        let oldSize = collectionViewLayout?.collectionViewContentSize ?? .zero
        
        let updateScroll: (NSRect, NSSize)->() = { oldRect, oldSize in
            if let scrollView = self.enclosingScrollView, let layout = self.collectionViewLayout {
                let offset = scrollView.documentVisibleRect
                
                if offset.maxY > layout.collectionViewContentSize.height || (offset.origin.y < 0 && layout.collectionViewContentSize.height <= offset.size.height) {
                    let point = NSPoint(x: 0, y: max(0, layout.collectionViewContentSize.height - offset.height))
                    
                    scrollView.documentView?.scroll(point)
                } else if !expandBottom {
                    let point = NSPoint(x: 0, y: max(0, layout.collectionViewContentSize.height - (oldSize.height - oldRect.origin.y)))
                    scrollView.documentView?.scroll(point)
                }
            }
        }
        
        let diff = newData.diff(oldData: oldData)
        
        func update() -> () {
            updateObjects()
            deleteItems(at: diff.delete)
            insertItems(at: diff.add)
            diff.move.forEach { moveItem(at: $0, to: $1) }
        }
        
        if animated && window != nil && oldData.count > 0 && newData.count > 0 {
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                context.timingFunction = CAMediaTimingFunction.customEaseOut
                
                animator().performBatchUpdates {
                    update()
                } completionHandler: { [weak self] _ in
                    self?.layoutSubtreeIfNeeded()
                    completion()
                }
                updateScroll(oldRect, oldSize)
            }, completionHandler: nil)
        } else {
            performBatchUpdates { update() } completionHandler: { [weak self] _ in
                self?.layoutSubtreeIfNeeded()
                updateScroll(oldRect, oldSize)
                completion()
            }
        }
    }
}
