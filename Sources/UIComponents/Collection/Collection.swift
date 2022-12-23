//
//  Collection.swift
//

import AppKit
import CommonUtils

public protocol CollectionDelegate: NSCollectionViewDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool
    
    func viewSizeFor(view: NSView, defaultSize: CGSize, collection: Collection) -> CGSize
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result
    
    func createCell(object: AnyHashable, collection: Collection) -> Collection.Cell
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize
    
    func doubleClick(object: AnyHashable, collection: Collection)
}

public extension CollectionDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool { objects.isEmpty }
    
    func viewSizeFor(view: NSView, defaultSize: CGSize, collection: Collection) -> CGSize { defaultSize }
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result { .deselectCell }
    
    func createCell(object: AnyHashable, collection: Collection) -> Collection.Cell? { nil }
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize { .zero }
    
    func doubleClick(object: AnyHashable, collection: Collection) { }
}

open class Collection: StaticSetupObject {
    
    public enum Result: Int {
        case deselectCell
        case selectCell
    }
    
    public struct Cell {
        
        fileprivate let type: NSCollectionViewItem.Type
        fileprivate let fill: (NSCollectionViewItem)->()
        
        public init<T: NSCollectionViewItem>(_ type: T.Type, _ fill: ((T)->())? = nil) {
            self.type = type
            self.fill = { fill?($0 as! T) }
        }
    }
    
    public let scrollView: NSScrollView
    public let collection: CollectionView
    
    weak var delegate: CollectionDelegate?
    
    public private(set) var objects: [AnyHashable] = []
    
    public var layout: NSCollectionViewFlowLayout? { collection.collectionViewLayout as? NSCollectionViewFlowLayout }
    
    // defer reload when view is not visible
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
    public lazy var noObjectsView = NoObjectsView.loadFromNib()
    
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
        guard let delegate = delegate else { return }
        
        if !visible {
            deferredReload = true
            return
        }
        
        deferredReload = false
        collection.visibleItems().forEach { item in
            if let indexPath = collection.indexPath(for: item) {
                delegate.createCell(object: objects[indexPath.item], collection: self)?.fill(item)
            }
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
        if !super.responds(to: aSelector) {
            if let delegate = delegate {
                return delegate.responds(to: aSelector)
            }
            return false
        }
        return true
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        super.responds(to: aSelector) ? self : delegate
    }
    
    public var defaultWidth: CGFloat {
        let contentInsets = scrollView.contentInsets
        let sectionInsets = layout?.sectionInset ?? NSEdgeInsets()
        var verticalScrollerWidth: CGFloat {
            guard let scroller = scrollView.verticalScroller else { return 0.0 }
            guard scroller.scrollerStyle != .overlay else { return 0.0 }
            return NSScroller.scrollerWidth(for: scroller.controlSize, scrollerStyle: scroller.scrollerStyle)
        }
        return scrollView.width - sectionInsets.left - sectionInsets.right - contentInsets.left - contentInsets.right - verticalScrollerWidth
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
            let identifier = NSUserInterfaceItemIdentifier(rawValue: ContainerCollectionItem.classNameWithoutModule())
            let item = collection.makeItem(withIdentifier: identifier, for: indexPath) as! ContainerCollectionItem
            item.attach(view)
            return item
        }
        
        let createItem = delegate!.createCell(object: object, collection: self)
        
        let item = collection.make(createItem.type, at: indexPath)
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
            
            if result == nil || result! == .deselectCell {
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
            
            let defaultWidth = self.defaultWidth
            
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
