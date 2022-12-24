//
//  PagingCollectionHelper.swift
//

import AppKit

open class PagingCollection: Collection {
    
    private(set) var loader: PagingLoader!
    private var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    override func setup() {
        super.setup()
        
        let loaderType = pagingDelegate?.pagingLoader() ?? PagingLoader.self
        
        self.loader = loaderType.init(scrollView: scrollView, delegate: pagingDelegate!)
    }
    
    public init(collection: CollectionView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
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
