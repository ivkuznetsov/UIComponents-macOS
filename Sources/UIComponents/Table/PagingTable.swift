//
//  PagingTable.swift
//

import AppKit

public class PagingTable: Table {
    
    private(set) var loader: PagingLoader!
    private var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    override func setup() {
        super.setup()
        
        let loaderType = pagingDelegate?.pagingLoader() ?? PagingLoader.self
        
        self.loader = loaderType.init(scrollView: scrollView, delegate: pagingDelegate!)
    }
    
    public init(table: NSTableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
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
