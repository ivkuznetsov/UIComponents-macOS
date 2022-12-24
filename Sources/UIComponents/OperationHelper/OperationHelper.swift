//
//  OperationHelper.swift
//

import AppKit
import CommonUtils

public class OperationHelper {

    public typealias Progress = (Double)->()
    public typealias Completion = (Error?)->()
    
    public enum Loading {
        // fullscreen opaque overlay loading with fullscreen opaque error
        case opaque
        
        // doesn't show loading, error is shown in alert (look for ErrorsPresenter)
        case alertOnFail
        
        // shows loading bar at the top of the screen without blocking the content, error is shown as label at the top for couple of seconds
        case nonblocking
        
        // modal panel with loading indicator, error is shown in alert (look for ErrorsPresenter)
        case modal(details: String, cancellable: Bool)
        
        case custom(loading: (Bool)->(), progress: ((Double)->())?, failing: (Error?, _ retry: (()->())?)->())
        
        case none
    }
    
    private class Token: Hashable {
        let id = UUID()
        let completion: Completion
        var operation: Cancellable?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func ==(lhs: Token, rhs: Token) -> Bool { lhs.hashValue == rhs.hashValue }
        
        init(completion: @escaping Completion) {
            self.completion = completion
        }
    }
    
    ///process error for .translucent loading type, by default shows NSAlert
    public var processTranslucentError: ((NSView, Error, _ retry: (()->())?)->())!
    
    ///by default retry appears in all operations
    public var shouldSupplyRetry: ((Error)->Bool)?
    
    public lazy var loadingView = LoadingView.loadFromNib(bundle: Bundle.module)
    public lazy var failedView = FailedView.loadFromNib(bundle: Bundle.module)
    private var loadingBarView: LoadingBarView?
    private var loadingPanel: LoadingPanel?
    
    weak private(set) var view: NSView?
    
    private weak var failedBarView: AlertBarView?
    private var keyedOperations: [String:Token] = [:]
    
    private var processing = Set<Token>()
    
    private var loadingCounter = 0
    private var nonblockingLoadingCounter = 0
    private var modalLoadingCounter = 0
    
    init(view: NSView) {
        self.view = view
        
        shouldSupplyRetry = {
            let codes = [400, 401, 403, 404]
            
            return !codes.contains(($0 as NSError).code)
        }
    }
    
    private func cancel(_ token: Token) {
        token.operation?.cancel()
        
        DispatchQueue.onMain { [weak self] in
            token.completion(RunError.cancelled)
            self?.processing.remove(token)
        }
    }
    
    // progress indicator becomes visible on first Progress block performing
    // 'key' is needed to cancel previous operation with the same key, you can pass nil if you don't need such functional
    func run(_ closure: @escaping (@escaping Completion, @escaping Progress)->Cancellable?, loading: Loading, key: String? = nil) {
        
        let newToken = Token(completion: { [weak self] (error) in
            guard let wSelf = self else { return }
            
            wSelf.decrement(loading: loading)
            
            if let key = key {
                wSelf.keyedOperations[key] = nil
            }
            
            if let error = error {
                var retry: (()->())?
                
                if wSelf.shouldSupplyRetry?(error) ?? true {
                    retry = { self?.run(closure, loading: loading, key: key) }
                }
                wSelf.process(error: error, retry: retry, loading: loading, key: key)
            }
        })
        
        if let key = key, let currentFailure = showedFailures[key] {
            resetFailure(loading: currentFailure)
        }
        resetFailure(loading: loading)
        
        increment(loading: loading, token: newToken)
        if let key = key, let token = keyedOperations[key]  {
            cancel(token)
        }
        
        processing.insert(newToken)
        if let key = key {
            keyedOperations[key] = newToken
        }
        
        let completion: Completion = { [weak self] error in
            DispatchQueue.onMain {
                guard let self = self, self.processing.contains(newToken) else { return }
                
                self.processing.remove(newToken)
                newToken.completion(error)
            }
        }
        let progress: Progress = { [weak self] (progress) in
            DispatchQueue.onMain {
                guard let self = self, self.processing.contains(newToken) else { return }
                self.process(progress: progress, loading: loading)
            }
        }
        newToken.operation = closure(completion, progress)
    }
    
    func run(_ closure: @escaping (@escaping Completion)->Cancellable?, loading: Loading, key: String? = nil) {
        run({ (completion, _) in
            closure(completion)
        }, loading: loading, key: key)
    }
    
    private var showedFailures: [String:Loading] = [:]
    
    private func removeFailure(_ key: String) {
        if let existingFailure = showedFailures[key] {
            showedFailures[key] = nil
            resetFailure(loading: existingFailure)
        }
    }
    
    private func resetFailure(loading: Loading) {
        if case .opaque = loading {
            failedView.removeFromSuperview()
        } else if case .custom(_, _, let failing) = loading {
            failing(nil, nil)
        }
    }
    
    private func process(error: Error, retry: (()->())?, loading: Loading, reusing: Bool = false, key: String?) {
        guard let view = view, (error as NSError).code != NSURLErrorCancelled && error as? RunError != RunError.cancelled else { return }
        
        if let key = key {
            showedFailures[key] = loading
        }
        switch loading {
        case .opaque:
            failedView.present(in: view, text: error.localizedDescription, retry: retry)
        case .modal(details: _), .alertOnFail:
            if !reusing {
                processTranslucentError(view, error, retry)
            }
        case .nonblocking:
            if failedBarView?.message ?? "" != error.localizedDescription {
                failedBarView = AlertBarView.present(in: view, message: error.localizedDescription)
            }
        case .custom(_, _, let fail):
            fail(error, retry)
        case .none:
            break
        }
    }
    
    private func process(progress: Double, loading: Loading) {
        if case .opaque = loading {
            loadingView.progress = CGFloat(progress)
        } else if case .modal = loading {
            loadingPanel?.progress = CGFloat(progress)
        } else if case .custom(_, let prog, _) = loading {
            prog?(progress)
        }
    }
    
    private func increment(loading: Loading, token: Token?) {
        guard let view = view else { return }
        
        if case .opaque = loading {
            if loadingCounter == 0 {
                loadingView.present(in: view, animated: false)
                loadingView.performLazyLoading()
            }
            loadingCounter += 1
            
        } else if case .modal(let label, let cancellable) = loading {
            
            var cancel: (()->())?
            
            if cancellable {
                cancel = { [weak self, weak token] in
                    if let token = token {
                        self?.cancel(token)
                    }
                }
            }
            
            if modalLoadingCounter == 0 {
                if let window = view.window {
                    loadingPanel = LoadingPanel.present(in: window, label: label, cancel: cancel)
                }
            } else {
                loadingPanel?.cancel = cancel
            }
            modalLoadingCounter += 1
            
        } else if case .nonblocking = loading {
            if nonblockingLoadingCounter == 0 {
                loadingBarView = LoadingBarView.present(in: view, animated: true)
            }
            nonblockingLoadingCounter += 1
        } else if case .custom(let loading, _, _) = loading {
            loading(true)
        }
    }
    
    private func decrement(loading: Loading) {
        if case .opaque = loading {
            loadingCounter -= 1
            if loadingCounter == 0 {
                loadingView.hide(true)
            }
            
        } else if case .nonblocking = loading {
            nonblockingLoadingCounter -= 1
            if nonblockingLoadingCounter == 0 {
                loadingBarView?.hide()
            }
        } else if case .modal(_, _) = loading {
            modalLoadingCounter -= 1
            if modalLoadingCounter == 0 {
                loadingPanel?.hide()
            }
        } else if case .custom(let loading, _, _) = loading {
            loading(false)
        }
    }
    
    func cancelAll() {
        showedFailures.keys.forEach { removeFailure($0) }
        processing.forEach { cancel($0) }
    }
    
    func cancel(_ key: String) {
        if let token = keyedOperations[key] {
            cancel(token)
        }
    }
    
    func isLoading(_ key: String) -> Bool {
        keyedOperations[key] != nil
    }
    
    deinit {
        cancelAll()
    }
}

extension OperationHelper {
    
    static func runModal(_ closure: (@escaping Completion, @escaping Progress)->(Cancellable?), label: String, window: NSWindow? = nil) {
        var op: Cancellable?
        let loadingPanel = LoadingPanel.present(in: window, label: label, cancel: { op?.cancel() })
        
        op = closure({ error in
            if let error = error, (error as? RunError) != .cancelled {
                NSAlert.show(error, title: "Error Occurred")
            }
            if error == nil {
                loadingPanel.progress = 1
            }
            loadingPanel.hide()
        }, { loadingPanel.progress = $0 })
    }
}
