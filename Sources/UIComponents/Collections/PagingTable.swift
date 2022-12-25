//
//  PagingTable.swift
//

import AppKit

public class PagingTable: Table {
    
    public let loader: PagingLoader
    public var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(list: NSTableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.loader = pagingDelegate.pagingLoader().init(scrollView: list.enclosingScrollView!, delegate: pagingDelegate)
        super.init(list: list, delegate: pagingDelegate)
    }
    
    public convenience init(view: NSView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.init(list: type(of: self).createList(in: view), pagingDelegate: pagingDelegate)
    }
    
    open override func set(_ objects: [AnyHashable], animated: Bool = false, completion: (()->())? = nil) {
        var result = objects
        if let visibleFooter = loader.visibleFooter {
            result.append(visibleFooter)
        }
        super.set(result, animated: animated, completion: completion)
    }
}
