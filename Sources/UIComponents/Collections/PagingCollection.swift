//
//  PagingCollectionHelper.swift
//

import AppKit
import CommonUtils

open class PagingCollection: Collection {
    
    public let loader: PagingLoader
    public var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(list: CollectionView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        loader = pagingDelegate.pagingLoader().init(scrollView: list.enclosingScrollView!,
                                                    delegate: pagingDelegate,
                                                    setFooterVisible: { [weak pagingDelegate] visible, footer in
            pagingDelegate?.reloadView(true)
        })
        loader.footerLoadingView = FooterLoadingView.loadFromNib(bundle: Bundle.module)
        super.init(list: list, delegate: pagingDelegate)
    }
    
    public convenience init(view: NSView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.init(list: type(of: self).createList(in: view), pagingDelegate: pagingDelegate)
    }
    
    fileprivate func insertFooter(_ objects: [AnyHashable]) -> [AnyHashable] {
        var result = objects
        if loader.footerVisible, !result.contains(loader.footerLoadingView) {
            result.append(loader.footerLoadingView)
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
        if loader.footerVisible, !result.contains(loader.footerLoadingView) {
            result.insert(loader.footerLoadingView, at: 0)
        }
        return result
    }
}
