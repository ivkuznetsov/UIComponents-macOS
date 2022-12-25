//
//  PagingTable.swift
//

import AppKit
import CommonUtils

public class PagingTable: Table {
    
    public let loader: PagingLoader
    public var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(list: NSTableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        loader = pagingDelegate.pagingLoader().init(scrollView: list.enclosingScrollView!,
                                                    delegate: pagingDelegate,
                                                    setFooterVisible: { [weak pagingDelegate] visible, footer in
            pagingDelegate?.reloadView(true)
        })
        loader.footerLoadingView = FooterLoadingView.loadFromNib(bundle: Bundle.module)
        super.init(list: list, delegate: pagingDelegate)
    }
    
    public convenience init(view: NSView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.init(list: type(of: self).createList(in: view), pagingDelegate: pagingDelegate)
    }
    
    open override func set(_ objects: [AnyHashable], animated: Bool = false, completion: (()->())? = nil) {
        var result = objects
        if loader.footerVisible, !result.contains(loader.footerLoadingView) {
            result.append(loader.footerLoadingView)
        }
        super.set(result, animated: animated, completion: completion)
    }
}
