//
//  PagingLoader.swift
//

import AppKit
import CommonUtils

public protocol PagingLoaderDelegate: AnyObject {
    
    func shouldLoadMore() -> Bool
    
    func pagingLoader() -> PagingLoader.Type
    
    func reloadView(_ animated: Bool)
    
    func load(offset: Any?, showLoading: Bool, completion: @escaping ([AnyHashable]?, Error?, _ offset: Any?)->())
}

public extension PagingLoaderDelegate {
    
    func shouldLoadMore() -> Bool { true }
    
    func pagingLoader() -> PagingLoader.Type { PagingLoader.self }
}

public protocol PagingCachable: AnyObject {
 
    func saveFirstPageInCache(objects: [AnyHashable])
    
    func loadFirstPageFromCache() -> [AnyHashable]
}

open class PagingLoader: StaticSetupObject {
    
    public var footerLoadingInset = CGSize(width: 0, height: 0)
    
    public lazy var footerLoadingView: FooterLoadingView = {
        let view = FooterLoadingView.loadFromNib()
        view.retry = { [unowned self] in
            self.loadMore()
        }
        return view
    }()
    
    public private(set) var isLoading = false
    public private(set) weak var scrollView: NSScrollView?
    public private(set) weak var delegate: PagingLoaderDelegate?
    
    public var fetchedItems: [AnyHashable] = []
    public var offset: Any?
    
    private var currentOperationId: UUID?
    var visibleFooter: NSView? {
        didSet {
            if oldValue != visibleFooter {
                delegate?.reloadView(true)
            }
        }
    }
    
    private var scrollObserver: Any?
    
    public required init(scrollView: NSScrollView, delegate: PagingLoaderDelegate) {
        self.scrollView = scrollView
        self.delegate = delegate
        super.init()
        self.fetchedItems = (delegate as? PagingCachable)?.loadFirstPageFromCache() ?? []
        
        scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: nil) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.loadModeIfNeeded()
            }
        }
    }
    
    func set(fetchedItems: [AnyHashable], offset: Any?) {
        self.fetchedItems = fetchedItems
        self.offset = offset
        visibleFooter = offset == nil ? nil : footerLoadingView
    }
    
    func loadMore() {
        load(offset: offset, showLoading: false) { [weak self] objects, newOffset in
            self?.offset = newOffset
            self?.append(items: objects)
        }
    }
    
    func refresh(showLoading: Bool) {
        load(offset: nil, showLoading: showLoading) { [weak self] objects, newOffset in
            guard let wSelf = self else { return }
            
            if let currentFirst = wSelf.fetchedItems.first, objects.reversed().contains(currentFirst) {
                wSelf.append(items: objects, fromBeginning: true)
            } else {
                wSelf.offset = newOffset
                wSelf.fetchedItems = []
                wSelf.append(items: objects)
            }
            (wSelf.delegate as? PagingCachable)?.saveFirstPageInCache(objects: objects)
        }
    }
    
    private func load(offset: Any?, showLoading: Bool, success: @escaping ([AnyHashable], _ newOffset: Any?)->()) {
        isLoading = true
        footerLoadingView.state = .loading
        
        let operationId = UUID()
        currentOperationId = operationId
        
        delegate?.load(offset: offset, showLoading: showLoading, completion: { [weak self] (objects, error, newOffset) in
            guard let wSelf = self, wSelf.delegate != nil, wSelf.currentOperationId == operationId else { return }
            
            wSelf.isLoading = false
            if let error = error {
                wSelf.footerLoadingView.state = ((error as? RunError) == .cancelled || (error as NSError).code == NSURLErrorCancelled) ? .stop : .failed
            } else {
                success(objects ?? [], newOffset)
                
                wSelf.visibleFooter = wSelf.offset != nil ? wSelf.footerLoadingView : nil
                wSelf.footerLoadingView.state = .stop
                
                if wSelf.offset != nil {
                    DispatchQueue.main.async {
                        self?.loadModeIfNeeded()
                    }
                }
            }
        })
    }
    
    open func append(items: [AnyHashable], fromBeginning: Bool = false) {
        guard let delegate = delegate else { return }
        
        var array = fetchedItems
        var set = Set(array)
        
        let itemsToAdd = fromBeginning ? items.reversed() : items
        
        itemsToAdd.forEach {
            if !set.contains($0) {
                set.insert($0)
                
                if fromBeginning {
                    array.insert($0, at: 0)
                } else {
                    array.append($0)
                }
            }
        }
        fetchedItems = array
        
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0
            delegate.reloadView(true)
        }
    }
    
    func filterFetchedItems(_ closure: (AnyHashable)->Bool) {
        let oldCount = fetchedItems.count
        fetchedItems = fetchedItems.compactMap { closure($0) ? $0 : nil }
        if oldCount != fetchedItems.count {
            delegate?.reloadView(false)
        }
    }
    
    private func loadModeIfNeeded() {
        if let delegate = delegate, delegate.shouldLoadMore() {
            
            let footerVisisble = isFooterVisible()
            
            if footerLoadingView.state == .failed && !footerVisisble {
                footerLoadingView.state = .stop
            }
            
            if footerLoadingView.state == .stop &&
                !isLoading &&
                footerVisisble &&
                fetchedItems.count != 0 {
                
                loadMore()
            }
        }
    }
    
    private func isFooterVisible() -> Bool {
        if let scrollView = scrollView,
            let visibleFooter = visibleFooter {
            let frame = scrollView.convert(visibleFooter.bounds, from: visibleFooter).insetBy(dx: -footerLoadingInset.width, dy: -footerLoadingInset.height)
            return visibleFooter.isDescendant(of: scrollView) && scrollView.bounds.intersects(frame)
        }
        return false
    }
}
