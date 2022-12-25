//
//  Table.swift
//

import AppKit
import CommonUtils

public class NoEmptyCellsTableView: NSTableView {
    
    override public func drawGrid(inClipRect clipRect: NSRect) { }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        (delegate as? Table)?.visible = window != nil
    }
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

public class Table: BaseList<NSTableView, TableDelegate, CGFloat, ContainerTableCell> {
    
    public typealias Result = SelectionResult
    
    public override class func createList(in view: NSView) -> NSTableView {
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
    
    public override init(list: NSTableView, delegate: TableDelegate) {
        super.init(list: list, delegate: delegate)
        
        noObjectsView = NoObjectsView.loadFromNib(bundle: Bundle.module)
        list.menu = NSMenu()
        list.menu?.delegate = self
        list.wantsLayer = true
        list.delegate = self
        list.dataSource = self
        list.target = self
        list.doubleAction = #selector(doubleClickAction(_:))
        list.usesAutomaticRowHeights = true
        
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: list.enclosingScrollView!.contentView, queue: nil) { [weak self] _ in
            if let wSelf = self {
                wSelf.delegate?.scrollViewDidScroll(table: wSelf)
            }
        }.retained(by: self)
    }
    
    public override func updateList(_ objects: [AnyHashable], animated: Bool, updateObjects: (Set<Int>) -> (), completion: @escaping () -> ()) {
        guard let delegate = delegate else { return }
        
        FirstResponderPreserver.performWith(list.window) {
            list.reload(oldData: self.objects,
                        newData: objects,
                        updateObjects: updateObjects,
                        addAnimation: delegate.animationForAdding(table: self),
                        deleteAnimation: delegate.animationForDeleting(table: self),
                        animated: animated)
        }
        delegate.scrollViewDidScroll(table: self)
        completion()
    }
    
    public override func reloadVisibleCells(excepting: Set<Int> = Set()) {
        let rows = list.rows(in: list.visibleRect)
        
        for i in rows.location..<(rows.location + rows.length) {
            if !excepting.contains(i),
                let view = list.rowView(atRow: i, makeIfNecessary: false),
                let object = objects[safe: i] {
                if object as? NSView == nil {
                    delegate?.createCell(object: object, table: self)?.fill(view)
                }
            }
        }
    }
    
    @objc private func doubleClickAction(_ sender: Any) {
        if let object = objects[safe: list.clickedRow] {
            delegate?.doubleClickAction(object: object, table: self)
        }
    }
    
    public var selectedItem: AnyHashable? {
        set {
            if let object = newValue, let index = objects.firstIndex(of: object) {
                FirstResponderPreserver.performWith(list.window) {
                    list.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                }
            } else {
                list.deselectAll(nil)
            }
        }
        get { objects[safe: list.selectedRow] }
    }
    
    public override func shouldShowNoData(_ objects: [AnyHashable]) -> Bool {
        delegate?.shouldShowNoData(objects: objects, table: self) == true
    }
    
    deinit {
        list.delegate = nil
        list.dataSource = nil
    }
}

extension Table: NSTableViewDataSource, NSTableViewDelegate {
    
    public func numberOfRows(in tableView: NSTableView) -> Int { objects.count }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { nil }
    
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let object = objects[row]
        
        if let view = object as? NSView {
            let cell = list.createCell(for: ContainerTableCell.self, identifier: "\(view.hash)", source: .code)
            cell.attach(viewToAttach: view, type: .constraints)
            setupViewContainer?(cell)
            return cell
        } else if let createCell = delegate?.createCell(object: object, table: self) {
            let cell = list.createCell(for: createCell.type, source: .nib)
            createCell.fill(cell)
            return cell
        }
        return nil
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let object = objects[row]
        var height = cachedSize(for: object)
        
        if height == nil {
            height = delegate?.cellHeight(object: object, table: self)
            cache(size: height, for: object)
        }
        return height ?? -1
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selected = list.selectedRowIndexes
        
        if selected.isEmpty {
            delegate?.deselectedAll(table: self)
        } else {
            selected.forEach {
                if delegate?.action(object: objects[$0], table: self) == .deselect {
                    list.deselectRow($0)
                }
            }
        }
    }
}

extension Table: NSMenuDelegate {
    
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let object = objects[safe: list.clickedRow] {
            delegate?.menuItems(object: object, table: self).forEach { menu.addItem($0) }
        }
    }
}
