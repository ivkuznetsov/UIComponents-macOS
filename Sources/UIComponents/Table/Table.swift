//
//  Table.swift
//

import AppKit
import CommonUtils

public protocol TableDelegate: NSTableViewDelegate {
    
    //fade by default
    func animationForAdding(table: Table) -> NSTableView.AnimationOptions
    
    func animationForDeleting(table: Table) -> NSTableView.AnimationOptions
    
    //by default it becomes visible when objects array is empty
    func shouldShowNoData(objects: [AnyHashable], table: Table) -> Bool
    
    func action(object: AnyHashable, table: Table) -> Table.Result
    
    func doubleClickAction(object: AnyHashable, table: Table)
    
    func deselectedAll(table: Table)
    
    func createCell(object: AnyHashable, table: Table) -> Table.Cell?
    
    func cellHeight(object: AnyHashable, table: Table) -> CGFloat
    
    func menuItems(object: AnyHashable, table: Table) -> [NSMenuItem]
    
    func scrollViewDidScroll(table: Table)
}

public extension TableDelegate {
    
    func animationForAdding(table: Table) -> NSTableView.AnimationOptions { .effectFade }
    
    func animationForDeleting(table: Table) -> NSTableView.AnimationOptions { .effectFade }
    
    func shouldShowNoData(objects: [AnyHashable], table: Table) -> Bool { objects.isEmpty }
    
    func action(object: AnyHashable, table: Table) -> Table.Result { .deselectCell }
    
    func doubleClickAction(object: AnyHashable, table: Table) { }
    
    func deselectedAll(table: Table) { }
    
    func createCell(object: AnyHashable, table: Table) -> Table.Cell? { nil }
    
    func cellHeight(object: AnyHashable, table: Table) -> CGFloat { -1 }
    
    func menuItems(object: AnyHashable, table: Table) -> [NSMenuItem] { [] }
    
    func scrollViewDidScroll(table: Table) { }
}

public protocol CellSizeCachable {
    
    var cacheKey: String { get }
}

open class Table: StaticSetupObject {
    
    public enum Result: Int {
        case deselectCell
        case selectCell
    }
    
    public struct Cell {
        
        fileprivate let type: NSTableRowView.Type
        fileprivate let fill: (NSTableRowView)->()
        
        public init<T: BaseTableViewCell>(_ type: T.Type, _ fill: ((T)->())? = nil) {
            self.type = type
            self.fill = { fill?($0 as! T) }
        }
    }
    
    //options
    public var cacheCellHeights = false
    
    private var deferredUpdate: Bool = false
    open var visible: Bool = true { // defer reload when view is not visible
        didSet {
            if visible && (visible != oldValue) && deferredUpdate {
                set(objects, animated: false)
            }
        }
    }
    
    public let scrollView: NSScrollView
    public let table: NSTableView
    public private(set) var objects: [AnyHashable] = []
    
    open lazy var noObjectsView: NoObjectsView = NoObjectsView.loadFromNib()
    
    weak var delegate: TableDelegate?
    fileprivate var cachedHeights: [NSValue:CGFloat] = [:]
    
    public init(table: NSTableView, delegate: TableDelegate) {
        self.table = table
        self.scrollView = table.enclosingScrollView!
        self.delegate = delegate
        super.init()
        setup()
    }
    
    public init(view: NSView, delegate: TableDelegate) {
        scrollView = NSScrollView()
        table = CustomTableView(frame: .zero)
        self.delegate = delegate
        super.init()
        setupTableView()
        view.attach(scrollView)
        setup()
    }
    
    public init(customAdd: (NSScrollView)->(), delegate: TableDelegate) {
        scrollView = NSScrollView()
        table = CustomTableView(frame: .zero)
        self.delegate = delegate
        super.init()
        setupTableView()
        customAdd(scrollView)
        setup()
    }
    
    private func setupTableView() {
        scrollView.documentView = table
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        table.backgroundColor = .clear
        table.intercellSpacing = .zero
        table.gridStyleMask = .solidHorizontalGridLineMask
        table.headerView = nil
    }
    
    private var scrollObserver: Any?
    
    func setup() {
        table.delegate = self
        table.dataSource = self
        table.menu = NSMenu()
        table.menu?.delegate = self
        table.target = self
        table.wantsLayer = true
        table.doubleAction = #selector(doubleClickAction(_:))
        table.usesAutomaticRowHeights = true
        
        scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: table.enclosingScrollView?.contentView, queue: nil) { [weak self] _ in
            if let wSelf = self {
                wSelf.delegate?.scrollViewDidScroll(table: wSelf)
            }
        }
    }
    
    open func set(_ objects: [AnyHashable], animated: Bool) {
        let oldObjects = self.objects
        
        if !visible {
            self.objects = objects
            deferredUpdate = true
            return
        }
        
        guard let delegate = delegate else { return }
        
        // remove missed estimated heights
        var set = Set(cachedHeights.keys)
        objects.forEach { set.remove(cachedHeightKeyFor(object: $0)) }
        set.forEach { cachedHeights[$0] = nil }
        
        let preserver = FirstResponderPreserver(window: table.window)
        
        if !deferredUpdate && oldObjects.count > 0 && objects.count > 0 && animated {
            table.reload(oldData: oldObjects,
                         newData: objects, deferred: { [weak self] in
                self?.reloadVisibleCells()
            }, updateObjects: { [weak self] in
                self?.objects = objects
            }, addAnimation: delegate.animationForAdding(table: self),
                         deleteAnimation: delegate.animationForDeleting(table: self))
        } else {
            self.objects = objects
            table.reloadData()
            table.layoutSubtreeIfNeeded()
            deferredUpdate = false
        }
        preserver.commit()
        
        if delegate.shouldShowNoData(objects: objects, table: self) {
            table.attach(noObjectsView)
        } else {
            noObjectsView.removeFromSuperview()
        }
        delegate.scrollViewDidScroll(table: self)
    }
    
    public func reloadVisibleCells() {
        let rect = table.visibleRect
        let rows = table.rows(in: rect)
        
        for i in rows.location..<(rows.location + rows.length) {
            if let view = table.rowView(atRow: i, makeIfNecessary: false) as? NSTableRowView & ObjectHolder,
               let object = view.object {
                delegate?.createCell(object: object, table: self)?.fill(view)
            }
        }
    }
    
    public func setNeedUpdateHeights() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateHeights), object: nil)
        perform(#selector(updateHeights), with: nil, afterDelay: 0)
    }
    
    @objc private func updateHeights() {
        if visible {
            if delegate != nil {
                table.beginUpdates()
                table.endUpdates()
            }
        } else {
            deferredUpdate = true
        }
    }
    
    fileprivate func cachedHeightKeyFor(object: AnyHashable) -> NSValue {
        if let object = object as? CellSizeCachable {
            return NSNumber(integerLiteral: object.cacheKey.hash)
        }
        return NSValue(nonretainedObject: object)
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        if !super.responds(to: aSelector) {
            return delegate?.responds(to: aSelector) ?? false
        }
        return true
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if !super.responds(to: aSelector) {
            return delegate
        }
        return self
    }
    
    public var defaultWidth: CGFloat {
        let contentInsets = scrollView.contentInsets
        return scrollView.width - contentInsets.left - contentInsets.right - (scrollView.verticalScroller?.width ?? 0)
    }
    
    @objc public func doubleClickAction(_ sender: Any) {
        let clicked = table.clickedRow
        if clicked >= 0 && clicked < objects.count {
            delegate?.doubleClickAction(object: objects[clicked], table: self)
        }
    }
    
    public func select(index: Int) {
        let preserver = FirstResponderPreserver(window: table.window)
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        preserver.commit()
    }
    
    public var selectedItem: AnyHashable? {
        let row = table.selectedRow
        if row >= 0 && row < objects.count {
            return objects[row]
        }
        return nil
    }
    
    deinit {
        table.delegate = nil
        table.dataSource = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateHeights), object: nil)
        NotificationCenter.default.removeObserver(self)
    }
}

extension Table: NSTableViewDataSource, NSTableViewDelegate {
    
    public func numberOfRows(in tableView: NSTableView) -> Int { objects.count }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { nil }
    
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let object = objects[row]
        
        if let view = object as? NSView {
            
            let id = NSUserInterfaceItemIdentifier(rawValue: "\(view.hash)")
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) ?? ContainerTableCell(frame: .zero)) as! ContainerTableCell
            cell.identifier = id
            cell.attach(viewToAttach: view)
            return cell
            
        } else if let createCell = delegate?.createCell(object: object, table: self) {
            
            let id = NSUserInterfaceItemIdentifier(rawValue: createCell.type.classNameWithoutModule())
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) ?? createCell.type.loadFromNib()) as! NSTableRowView
            createCell.fill(cell)
            (cell as? ObjectHolder)?.object = object
            return cell
        }
        return nil
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        var height: CGFloat?
        let object = objects[row]
        
        height = cachedHeights[cachedHeightKeyFor(object: object)]
        if height == nil {
            height = delegate?.cellHeight(object: object, table: self)
            cachedHeights[cachedHeightKeyFor(object: object)] = height
        }
        return height ?? -1
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selected = table.selectedRowIndexes
        
        if selected.count == 0 {
            delegate?.deselectedAll(table: self)
            return
        }
        
        selected.forEach {
            let object = objects[$0]
            
            let result = delegate?.action(object: object, table: self)
            
            if result == nil || result! == .deselectCell {
                table.deselectRow($0)
            }
        }
    }
    
    public func tableViewColumnDidResize(_ notification: Notification) {
        cachedHeights.removeAll()
    }
}

extension Table: NSMenuDelegate {
    
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clicked = table.clickedRow
        if clicked >= 0 && clicked < objects.count {
            delegate?.menuItems(object: objects[clicked], table: self).forEach { menu.addItem($0) }
        }
    }
}
