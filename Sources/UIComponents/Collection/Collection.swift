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

open class Collection: StaticSetupObject {
    
    public typealias Result = SelectionResult
    
    public let scrollView: NSScrollView
    public let collection: CollectionView
    
    weak var delegate: CollectionDelegate?
    
    public private(set) var objects: [AnyHashable] = []
    
    public var visible = true {
        didSet {
            if visible && visible != oldValue && !updatingData && deferredReload {
                reloadVisibleCells()
            }
        }
    }
    
    // when new items appears scroll aligns to the top
    public var expandsBottom: Bool = true
    
    // empty state
    public lazy var noObjectsView = NoObjectsView.loadFromNib(bundle: Bundle.module)
    
    private var updatingData = false
    private var deferredReload = false
    
    public init(collection: CollectionView, delegate: CollectionDelegate) {
        self.collection = collection
        self.scrollView = collection.enclosingScrollView!
        self.delegate = delegate
        super.init()
        setup()
    }
    
    public convenience init(view: NSView, delegate: CollectionDelegate) {
        self.init(collection: type(of: self).createCollection(view: view), delegate: delegate)
    }
    
    static func createCollection(view: NSView) -> CollectionView {
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
    
    func setup() {
        collection.isSelectable = true
        collection.delegate = self
        collection.dataSource = self
        collection.register(ContainerCollectionItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: ContainerCollectionItem.classNameWithoutModule()))
        
        if delegate?.doubleClick != nil {
            let recognizer = NSClickGestureRecognizer(target: self, action: #selector(doubleClickAction(_:)))
            recognizer.numberOfClicksRequired = 2
            recognizer.delaysPrimaryMouseButtonEvents = false
            collection.addGestureRecognizer(recognizer)
        }
    }
    
    @objc private func doubleClickAction(_ sender: NSClickGestureRecognizer) {
        let location = sender.location(in: collection)
        if let indexPath = collection.indexPathForItem(at: location) {
            delegate?.doubleClick(object: objects[indexPath.item], collection: self)
        }
    }
    
    private var updateCompletion: (()->())?
    
    public func reloadVisibleCells() {
        if visible {
            collection.visibleItems().forEach { item in
                if let indexPath = collection.indexPath(for: item) {
                    let object = objects[indexPath.item]
                    
                    if object as? NSView == nil {
                        delegate?.createCell(object: object, collection: self)?.fill(item)
                    }
                }
            }
        } else {
            deferredReload = true
        }
    }
    
    private var lazyObjects: [AnyHashable]?
    public func set(_ objects: [AnyHashable], animated: Bool, completion: (()->())? = nil) {
        let resultCompletion = { [weak self] in
            guard let wSelf = self else { return }
            
            let completion = wSelf.updateCompletion
            wSelf.updateCompletion = nil
            wSelf.updatingData = false
            
            if wSelf.delegate?.shouldShowNoData(objects, collection: wSelf) == true {
                wSelf.collection.attach(wSelf.noObjectsView)
            } else {
                wSelf.noObjectsView.removeFromSuperview()
            }
            completion?()
        }
        updateCompletion = completion
    
        if updatingData {
            lazyObjects = objects
        } else {
            updatingData = true
            
            internalSet(objects, animated: animated) { [weak self] in
                guard let wSelf = self else { return }
                
                if let objects = wSelf.lazyObjects {
                    wSelf.lazyObjects = nil
                    wSelf.internalSet(objects, animated: false, completion: resultCompletion)
                } else {
                    resultCompletion()
                }
            }
        }
    }
    
    private func internalSet(_ objects: [AnyHashable], animated: Bool, completion: @escaping ()->()) {
        collection.reload(animated: animated,
                          expandBottom: expandsBottom,
                          oldData: self.objects,
                          newData: objects,
                          updateObjects: {
                            reloadVisibleCells()
                            self.objects = objects
                          },
                          completion: completion)
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) ? true : (delegate?.responds(to: aSelector) ?? false)
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        super.responds(to: aSelector) ? self : delegate
    }
    
    deinit {
        collection.delegate = nil
        collection.dataSource = nil
    }
}

extension Collection: NSCollectionViewDataSource {
    
    public func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    
    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { objects.count }
    
    public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if indexPath.item >= objects.count { return NSCollectionViewItem() }
        
        let object = objects[indexPath.item]
        
        if let view = object as? NSView {
            let item = collection.createCell(for: ContainerCollectionItem.self, source: .code, at: indexPath)
            item.attach(view)
            return item
        }
        
        let createItem = delegate!.createCell(object: object, collection: self)
        
        let item = collection.createCell(for: createItem.type, at: indexPath)
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
            
            let defaultWidth = collection.defaultWidth
            
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
            return delegate?.cellSizeFor(object: object, collection: self) ?? .zero
        }
    }
}
