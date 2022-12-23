//
//  ReversePagingTableViewHelper.swift
//

import Foundation

public class ReversePagingCollectionViewHelper: PagingCollection {
    
    override public func insertFooter(_ objects: [AnyHashable]) -> [AnyHashable] {
        var result = objects
        if let visibleFooter = loader.visibleFooter, !result.contains(visibleFooter) {
            result.insert(visibleFooter, at: 0)
        }
        return result
    }
}
