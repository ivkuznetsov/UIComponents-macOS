//
//  BaseList+Additions.swift
//  
//
//  Created by Ilya Kuznetsov on 02/01/2023.
//

import Foundation
import SharedUIComponents

public extension BaseList {
    
    convenience init(listView: View? = nil) {
        self.init(listView: listView, emptyStateView: NoObjectsView.loadFromNib(bundle: Bundle.module))
    }
    
    var noObjecsView: NoObjectsView? { emptyStateView as? NoObjectsView }
}
