//
//  PagingTable.swift
//

import AppKit

open class PagingTable: Table {
    
    private(set) var loader: PagingLoader!
    private weak var pagingDelegate: PagingLoaderDelegate?
    
    override func setup() {
        super.setup()
        
        let loaderType = pagingDelegate?.pagingLoader() ?? PagingLoader.self
        
        self.loader = loaderType.init(scrollView: scrollView, delegate: pagingDelegate!)
    }
    
    public init(table: NSTableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(table: table, delegate: pagingDelegate)
    }
    
    public init(view: NSView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(view: view, delegate: pagingDelegate)
    }
    
    public init(customAdd: (NSScrollView)->(), pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(customAdd: customAdd, delegate: pagingDelegate)
    }
    
    open override func set(_ objects: [AnyHashable], animated: Bool) {
        var result = objects
        if let visibleFooter = loader.visibleFooter {
            result.append(visibleFooter)
        }
        super.set(result, animated: animated)
    }
}
