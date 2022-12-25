//
//  PagingTable.swift
//

import AppKit

public class PagingTable: Table {
    
    public let loader: PagingLoader
    public var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(table: NSTableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.loader = pagingDelegate.pagingLoader().init(scrollView: table.enclosingScrollView!, delegate: pagingDelegate)
        super.init(table: table, delegate: pagingDelegate)
    }
    
    public convenience init(view: NSView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.init(table: type(of: self).createTable(view: view), pagingDelegate: pagingDelegate)
    }
    
    open override func set(_ objects: [AnyHashable], animated: Bool) {
        var result = objects
        if let visibleFooter = loader.visibleFooter {
            result.append(visibleFooter)
        }
        super.set(result, animated: animated)
    }
}
