//
//  BaseList+Additions.swift
//  
//
//  Created by Ilya Kuznetsov on 02/01/2023.
//

import CommonUtils
import Foundation

public extension BaseList {
    
    convenience init(list: List? = nil) {
        self.init(list: list, emptyStateView: NoObjectsView.loadFromNib(bundle: Bundle.module))
    }
}
