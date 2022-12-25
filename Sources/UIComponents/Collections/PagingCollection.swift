//
//  PagingCollectionHelper.swift
//

import AppKit

open class PagingCollection: Collection {
    
    public let loader: PagingLoader
    public var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(collection: CollectionView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.loader = pagingDelegate.pagingLoader().init(scrollView: collection.enclosingScrollView!, delegate: pagingDelegate)
        super.init(collection: collection, delegate: pagingDelegate)
    }
    
    public convenience init(view: NSView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.init(collection: type(of: self).createCollection(view: view), pagingDelegate: pagingDelegate)
    }
    
    func insertFooter(_ objects: [AnyHashable]) -> [AnyHashable] {
        var result = objects
        if let visibleFooter = loader.visibleFooter, !result.contains(visibleFooter) {
            result.append(visibleFooter)
        }
        return result
    }
    
    public override func set(_ objects: [AnyHashable], animated: Bool, completion: (()->())? = nil) {
        super.set(insertFooter(objects), animated: animated, completion: completion)
    }
}

open class ReversePagingCollection: PagingCollection {
    
    override public func insertFooter(_ objects: [AnyHashable]) -> [AnyHashable] {
        var result = objects
        if let visibleFooter = loader.visibleFooter, !result.contains(visibleFooter) {
            result.insert(visibleFooter, at: 0)
        }
        return result
    }
}
