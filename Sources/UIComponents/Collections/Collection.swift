//
//  Collection.swift
//

import AppKit
import CommonUtils

open class CollectionView: NSCollectionView {
    
    open override var acceptsFirstResponder: Bool { false }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        (delegate as? Collection)?.visible = window != nil
    }
}

public protocol CollectionDelegate: NSCollectionViewDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool
    
    func viewSizeFor(view: NSView, defaultSize: CGSize, collection: Collection) -> CGSize
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result
    
    func createCell(object: AnyHashable, collection: Collection) -> NSCollectionView.Cell
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize
    
    func doubleClick(object: AnyHashable, collection: Collection)
}

public extension CollectionDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool { objects.isEmpty }
    
    func viewSizeFor(view: NSView, defaultSize: CGSize, collection: Collection) -> CGSize { defaultSize }
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result { .deselect }
    
    func createCell(object: AnyHashable, collection: Collection) -> NSCollectionView.Cell? { nil }
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize { .zero }
    
    func doubleClick(object: AnyHashable, collection: Collection) { }
}

open class Collection: BaseList<CollectionView, CollectionDelegate, CGSize> {
    
    public typealias Result = SelectionResult
    
    // when new items appears scroll aligns to the top
    public var expandsBottom: Bool = true
    
    public override init(list: CollectionView, delegate: CollectionDelegate) {
        super.init(list: list, delegate: delegate)
        
        noObjectsView = NoObjectsView.loadFromNib(bundle: Bundle.module)
        list.isSelectable = true
        list.delegate = self
        list.dataSource = self
        
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(doubleClickAction(_:)))
        recognizer.numberOfClicksRequired = 2
        recognizer.delaysPrimaryMouseButtonEvents = false
        list.addGestureRecognizer(recognizer)
    }
    
    open override class func createList(in view: NSView) -> CollectionView {
        let scrollView = NSScrollView()
        let collection = CollectionView(frame: .zero)
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.canDrawConcurrently = true
        
        let layout = VerticalLeftAlignedLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collection.collectionViewLayout = layout
        scrollView.documentView = collection
        scrollView.drawsBackground = true
        collection.backgroundColors = [.clear]
        view.attach(scrollView)
        return collection
    }
    
    open override func reloadVisibleCells(excepting: Set<Int> = Set()) {
        list.visibleItems().forEach { item in
            if let indexPath = list.indexPath(for: item), !excepting.contains(indexPath.item) {
                let object = objects[indexPath.item]
                
                if object as? NSView == nil {
                    delegate?.createCell(object: object, collection: self)?.fill(item)
                }
            }
        }
    }
    
    @objc private func doubleClickAction(_ sender: NSClickGestureRecognizer) {
        let location = sender.location(in: list)
        if let indexPath = list.indexPathForItem(at: location) {
            delegate?.doubleClick(object: objects[indexPath.item], collection: self)
        }
    }
    
    open override func updateList(_ objects: [AnyHashable], animated: Bool, updateObjects: (Set<Int>) -> (), completion: @escaping () -> ()) {
        list.reload(animated: animated,
                    expandBottom: expandsBottom,
                    oldData: self.objects,
                    newData: objects,
                    updateObjects: updateObjects,
                    completion: completion)
    }
    
    public override func shouldShowNoData(_ objects: [AnyHashable]) -> Bool {
        delegate?.shouldShowNoData(objects, collection: self) == true
    }
    
    deinit {
        list.delegate = nil
        list.dataSource = nil
    }
}

extension Collection: NSCollectionViewDataSource {
    
    public func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    
    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { objects.count }
    
    public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if indexPath.item >= objects.count { return NSCollectionViewItem() }
        
        let object = objects[indexPath.item]
        
        if let view = object as? NSView {
            let item = list.createCell(for: ContainerCollectionItem.self, source: .code, at: indexPath)
            item.attach(view)
            return item
        }
        
        let createItem = delegate!.createCell(object: object, collection: self)
        
        let item = list.createCell(for: createItem.type, at: indexPath)
        _ = item.view
        createItem.fill(item)
        return item
    }
}

extension Collection: NSCollectionViewDelegate {
    
    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        indexPaths.forEach {
            let object = objects[$0.item]
            
            let result = delegate?.action(object: object, collection: self)
            
            if result == nil || result! == .deselect {
                collectionView.deselectAll(nil)
            }
        }
    }
}

extension Collection: NSCollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        if indexPath.item >= objects.count { return .zero }
        
        let object = objects[indexPath.item]
        
        if let view = object as? NSView {
            
            let defaultWidth = list.defaultWidth
            
            var resultSize: NSSize = .zero
            
            if view.superview != nil {
                view.superview?.width = defaultWidth
                resultSize = view.fittingSize
            } else {
                let widthConstraint = view.widthAnchor.constraint(equalToConstant: defaultWidth)
                widthConstraint.isActive = true
                view.layoutSubtreeIfNeeded()
                resultSize = view.fittingSize
                widthConstraint.isActive = false
            }
            resultSize.width = defaultWidth
            
            if let size = delegate?.viewSizeFor(view: view, defaultSize: resultSize, collection: self) {
                resultSize = size
            }
            return NSSize(width: floor(resultSize.width), height: ceil(resultSize.height))
        } else {
            var size = cachedSize(for: object)
            if size == nil {
                size = delegate?.cellSizeFor(object: object, collection: self)
                cache(size: size, for: object)
            }
            return size ?? .zero
        }
    }
}
