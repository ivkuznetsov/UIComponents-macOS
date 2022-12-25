//
//  Table.swift
//

import AppKit
import CommonUtils

public class NoEmptyCellsTableView: NSTableView {
    
    override public func drawGrid(inClipRect clipRect: NSRect) { }
}

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
        self.delegate = delegate
        super.init()
        
        table.menu = NSMenu()
        table.menu?.delegate = self
        table.wantsLayer = true
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(doubleClickAction(_:))
        table.usesAutomaticRowHeights = true
        
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: table.enclosingScrollView!.contentView, queue: nil) { [weak self] _ in
            if let wSelf = self {
                wSelf.delegate?.scrollViewDidScroll(table: wSelf)
            }
        }.retained(by: self)
    }
    
    open lazy var noObjectsView = NoObjectsView.loadFromNib(bundle: Bundle.module)
    
    open func set(_ objects: [AnyHashable], animated: Bool) {
        guard let delegate = delegate else { return }
        
        // remove missed estimated heights
        var set = Set(cachedHeights.keys)
        objects.forEach { set.remove($0.cachedHeightKey) }
        set.forEach { cachedHeights[$0] = nil }
        
        let preserver = FirstResponderPreserver(window: table.window)
        
        table.reload(oldData: self.objects,
                     newData: objects,
                     updateObjects: {
            reloadVisibleCells(exceping: $0)
            self.objects = objects
        },
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
    
    public func reloadVisibleCells(exceping: Set<Int> = Set()) {
        if visible {
            deferredReload = false
            let rows = table.rows(in: table.visibleRect)
            
            for i in rows.location..<(rows.location + rows.length) {
                if !exceping.contains(i), let view = table.rowView(atRow: i, makeIfNecessary: false) {
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
    
    @objc private func doubleClickAction(_ sender: Any) {
        let clicked = table.clickedRow
        
        if clicked >= 0 && clicked < objects.count {
            delegate?.doubleClickAction(object: objects[clicked], table: self)
        }
    }
    
    public var selectedItem: AnyHashable? {
        set {
            if let object = newValue, let index = objects.firstIndex(of: object) {
                FirstResponderPreserver.performWith(table.window) {
                    table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                }
            } else {
                table.deselectAll(nil)
            }
        }
        get { objects[safe: table.selectedRow] }
    }
    
    deinit {
        table.delegate = nil
        table.dataSource = nil
    }
}

extension Table: NSTableViewDataSource, NSTableViewDelegate {
    
    public func numberOfRows(in tableView: NSTableView) -> Int { objects.count }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { nil }
    
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let object = objects[row]
        
        if let view = object as? NSView {
            let cell = table.createCell(for: ContainerTableCell.self, identifier: "\(view.hash)", source: .code)
            cell.attach(viewToAttach: view, type: .constraints)
            return cell
        } else if let createCell = delegate?.createCell(object: object, table: self) {
            let cell = table.createCell(for: createCell.type, source: .nib)
            createCell.fill(cell)
            return cell
        }
        return nil
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        var height: CGFloat?
        let object = objects[row]
        let key = object.cachedHeightKey
        
        height = cachedHeights[key]
        if height == nil {
            height = delegate?.cellHeight(object: object, table: self)
            cachedHeights[key] = height
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
            if delegate?.action(object: objects[$0], table: self) == .deselect {
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
        if let object = objects[safe: table.clickedRow] {
            delegate?.menuItems(object: object, table: self).forEach { menu.addItem($0) }
        }
    }
}