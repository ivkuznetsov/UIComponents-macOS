//
//  PagingCollectionHelper.swift
//

import AppKit

open class PagingCollection: Collection {
    
    private(set) var loader: PagingLoader!
    private weak var pagingDelegate: PagingLoaderDelegate?
    
    override func setup() {
        super.setup()
        
        let loaderType = pagingDelegate?.pagingLoader() ?? PagingLoader.self
        
        self.loader = loaderType.init(scrollView: scrollView, delegate: pagingDelegate!)
    }
    
    public init(collection: CollectionView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(collection: collection, delegate: pagingDelegate)
    }
    
    public init(view: NSView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(view: view, delegate: pagingDelegate)
    }
    
    public init(customAdd: (NSScrollView)->(), pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(customAdd: customAdd, delegate: pagingDelegate)
    }
    
    func insertFooter(_ objects: [AnyHashable]) -> [AnyHashable] {
        var result = objects
        if let visibleFooter = loader.visibleFooter, !result.contains(visibleFooter) {
            result.append(visibleFooter)
        }
        return result
    }
    
    public override func set(_ objects: [AnyHashable], animated: Bool, diffable: Bool = false, completion: (()->())? = nil) {
        super.set(insertFooter(objects), animated: animated, diffable: diffable, completion: completion)
    }
}
