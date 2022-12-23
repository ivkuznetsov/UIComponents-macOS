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
    
    func createCell(object: AnyHashable, table: Table) -> NSTableView.Cell?
    
    func cellHeight(object: AnyHashable, table: Table) -> CGFloat
    
    func menuItems(object: AnyHashable, table: Table) -> [NSMenuItem]
    
    func scrollViewDidScroll(table: Table)
}

public extension TableDelegate {
    
    func animationForAdding(table: Table) -> NSTableView.AnimationOptions { .effectFade }
    
    func animationForDeleting(table: Table) -> NSTableView.AnimationOptions { .effectFade }
    
    func shouldShowNoData(objects: [AnyHashable], table: Table) -> Bool { objects.isEmpty }
    
    func action(object: AnyHashable, table: Table) -> Table.Result { .deselect }
    
    func doubleClickAction(object: AnyHashable, table: Table) { }
    
    func deselectedAll(table: Table) { }
    
    func createCell(object: AnyHashable, table: Table) -> NSTableView.Cell? { nil }
    
    func cellHeight(object: AnyHashable, table: Table) -> CGFloat { -1 }
    
    func menuItems(object: AnyHashable, table: Table) -> [NSMenuItem] { [] }
    
    func scrollViewDidScroll(table: Table) { }
}

public class Table: StaticSetupObject {
    
    public typealias Result = SelectionResult
    
    public let scrollView: NSScrollView
    public let table: NSTableView
    weak var delegate: TableDelegate?
    public private(set) var objects: [AnyHashable] = []
    
    private var deferredReload = false
    public var visible: Bool = true {
        didSet {
            if visible && (visible != oldValue) && deferredReload {
                reloadVisibleCells()
            }
        }
    }
    
    private var cachedHeights: [NSValue:CGFloat] = [:]
    
    public convenience init(view: NSView, delegate: TableDelegate) {
        self.init(table: type(of: self).createTable(view: view), delegate: delegate)
    }
    
    static func createTable(view: NSView) -> NSTableView {
        let scrollView = NSScrollView()
        let table = NoEmptyCellsTableView(frame: .zero)
        
        scrollView.documentView = table
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        table.backgroundColor = .clear
        table.intercellSpacing = .zero
        table.gridStyleMask = .solidHorizontalGridLineMask
        table.headerView = nil
        view.attach(scrollView)
        return table
    }
    
    public init(table: NSTableView, delegate: TableDelegate) {
        self.table = table
        self.scrollView = table.enclosingScrollView!
        self.delegate = delegate
        super.init()
        setup()
    }
    
    open lazy var noObjectsView: NoObjectsView = NoObjectsView.loadFromNib()
    
    private var scrollObserver: Any?
    
    func setup() {
        table.menu = NSMenu()
        table.menu?.delegate = self
        table.wantsLayer = true
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(doubleClickAction(_:))
        table.usesAutomaticRowHeights = true
        
        scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: nil) { [weak self] _ in
            if let wSelf = self {
                wSelf.delegate?.scrollViewDidScroll(table: wSelf)
            }
        }
    }
    
    open func set(_ objects: [AnyHashable], animated: Bool) {
        guard let delegate = delegate else { return }
        
        // remove missed estimated heights
        var set = Set(cachedHeights.keys)
        objects.forEach { set.remove($0.cachedHeightKey) }
        set.forEach { cachedHeights[$0] = nil }
        
        let preserver = FirstResponderPreserver(window: table.window)
        
        table.reload(oldData: self.objects,
                     newData: objects,
                     deferred: { reloadVisibleCells() },
                     updateObjects: { self.objects = objects },
                     addAnimation: delegate.animationForAdding(table: self),
                     deleteAnimation: delegate.animationForDeleting(table: self),
                     animated: animated)
        
        preserver.commit()
        
        if delegate.shouldShowNoData(objects: objects, table: self) {
            table.attach(noObjectsView)
        } else {
            noObjectsView.removeFromSuperview()
        }
        delegate.scrollViewDidScroll(table: self)
    }
    
    public func reloadVisibleCells() {
        if visible {
            deferredReload = false
            
            let rows = table.rows(in: table.visibleRect)
            
            for i in rows.location..<(rows.location + rows.length) {
                if let view = table.rowView(atRow: i, makeIfNecessary: false) {
                    let object = objects[i]
                    
                    if object as? NSView == nil {
                        delegate?.createCell(object: object, table: self)?.fill(view)
                    }
                }
            }
        } else {
            deferredReload = true
        }
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) ? true : (delegate?.responds(to: aSelector) ?? false)
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        super.responds(to: aSelector) ? self : delegate
    }
    
    public func setNeedUpdateHeights() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateHeights), object: nil)
        perform(#selector(updateHeights), with: nil, afterDelay: 0)
    }
    
    @objc private func updateHeights() {
        if delegate == nil { return }
        
        table.beginUpdates()
        table.endUpdates()
    }
    
    public var defaultWidth: CGFloat {
        let contentInsets = scrollView.contentInsets
        return scrollView.width - contentInsets.left - contentInsets.right - (scrollView.verticalScroller?.width ?? 0)
    }
    
    @objc private func doubleClickAction(_ sender: Any) {
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
            cell.identifier = id
            createCell.fill(cell)
            return cell
        }
        return nil
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        var height: CGFloat?
        let object = objects[row]
        
        height = cachedHeights[object.cachedHeightKey]
        if height == nil {
            height = delegate?.cellHeight(object: object, table: self)
            cachedHeights[object.cachedHeightKey] = height
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
            
            if result == nil || result! == .deselect {
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
