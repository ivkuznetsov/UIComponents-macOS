//
//  UICollectionView+Additions.swift
//

import AppKit

extension NSCollectionView {
    
    private func printDuplicates(_ array: [AnyHashable]) {
        var allSet = Set<AnyHashable>()
        
        array.forEach {
            if allSet.contains($0) {
                print("found duplicate object %@", $0.description)
            } else {
                allSet.insert($0)
            }
        }
    }
    
    func reload(animated: Bool, diffable: Bool, expandBottom: Bool, oldData: [AnyHashable], newData: [AnyHashable], completion: (()->())? = nil, updateObjects: (()->())? = nil) -> [IndexPath] {
        
        let oldRect = self.enclosingScrollView?.documentVisibleRect ?? .zero
        let oldSize = self.collectionViewLayout?.collectionViewContentSize ?? .zero
        
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
        
        if (!animated && !diffable) || oldData.isEmpty || window == nil {
            updateObjects?()
            reloadData()
            layoutSubtreeIfNeeded()
            updateScroll(oldRect, oldSize)
            completion?()
            return []
        }
        
        var toAdd = Set<IndexPath>()
        var toDelete = Set<IndexPath>()
        var toReload: [IndexPath] = []
        
        let oldDataSet = Set(oldData)
        let newDataSet = Set(newData)
        
        if oldDataSet.count != oldData.count {
            printDuplicates(oldData)
        }
        if newDataSet.count != newData.count {
            printDuplicates(newData)
        }
        
        let currentSet = NSMutableOrderedSet(array: oldData)
        for (index, object) in oldData.enumerated() {
            if !newDataSet.contains(object) {
                toDelete.insert(IndexPath(item: index, section: 0))
                currentSet.remove(object)
            }
        }
        for (index, object) in newData.enumerated() {
            if !oldDataSet.contains(object) {
                toAdd.insert(IndexPath(item: index, section: 0))
                currentSet.insert(object, at: index)
            } else {
                toReload.append(IndexPath(item: index, section: 0))
            }
        }
        
        var itemsToMove: [(from: IndexPath, to: IndexPath)] = []
        for (index, object) in newData.enumerated() {
            let oldDataIndex = currentSet.index(of: object)
            if index != oldDataIndex, let oldIndex = oldData.firstIndex(of: object) {
                itemsToMove.append((from: IndexPath(item: oldIndex, section: 0), to: IndexPath(item: index, section: 0)))
            }
        }
        
        if toDelete.count > 0 || toAdd.count > 0 || itemsToMove.count > 0 || toReload.count > 0 {
            
            if animated {
                NSAnimationContext.runAnimationGroup({ context in
                    context.allowsImplicitAnimation = true
                    context.timingFunction = CAMediaTimingFunction.customEaseOut
                    
                    animator().performBatchUpdates {
                        updateObjects?()
                        
                        deleteItems(at: toDelete)
                        insertItems(at: toAdd)
                        
                        itemsToMove.forEach { moveItem(at: $0, to: $1) }
                    } completionHandler: { _ in
                        self.layoutSubtreeIfNeeded()
                        completion?()
                    }
                    updateScroll(oldRect, oldSize)
                }, completionHandler: nil)
            } else {
                performBatchUpdates {
                    updateObjects?()
                    
                    deleteItems(at: toDelete)
                    insertItems(at: toAdd)
                    
                    itemsToMove.forEach { moveItem(at: $0, to: $1) }
                } completionHandler: { _ in
                    self.layoutSubtreeIfNeeded()
                    updateScroll(oldRect, oldSize)
                    completion?()
                }
            }
        } else {
            updateObjects?()
            self.layoutSubtreeIfNeeded()
            completion?()
        }
        return toReload
    }
}
