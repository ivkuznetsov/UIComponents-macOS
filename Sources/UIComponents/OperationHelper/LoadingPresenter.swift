//
//  OperationHelper.swift
//

import AppKit
import SharedUIComponents
import CommonUtils

public class LoadingPresenter: StaticSetupObject {
    
    public let helper = LoadingHelper()
    public let view: NSView
    
    public var shouldSupplyRetry: (Error)->Bool = { $0 as? RunError == nil }
    
    public var processModalError: (NSView, Error, _ retry: (()->())?)->() = { (view, error, retry) in
        let cancelTitle = retry != nil ? "Cancel" : "OK"
        var otherActions: [(String, (()->())?)] = []
        if let retry = retry {
            otherActions.append(("Retry", { retry() }))
        }
        NSAlert.show("Failed",
                     details: error.localizedDescription,
                     alertStyle: .warning,
                     canCancel: true,
                     buttons: otherActions, window: view.window)
    }
    
    public lazy var loadingView = LoadingView.loadFromNib(bundle: Bundle.module)
    public lazy var loadingBarView = LoadingBarView()
    public lazy var failedView = FailedView.loadFromNib(bundle: Bundle.module)
    public lazy var failedBarView = AlertBarView.loadFromNib(bundle: Bundle.module)
    public weak var modalLoadingPanel: LoadingPanel?
    
    var observe: Any?
    
    public init(view: NSView) {
        self.view = view
        super.init()
        
        helper.$processing.sink { [weak self] in
            self?.reloadView($0)
        }.retained(by: self)
        
        helper.didFail.sink { [weak self] fail in
            guard let wSelf = self else { return }
            
            let retry = wSelf.shouldSupplyRetry(fail.error) ? fail.retry : nil
            
            switch fail.presentation {
            case .opaque:
                wSelf.failedView.present(in: wSelf.view,
                                         text: fail.error.localizedDescription,
                                         retry: retry)
            case .modal(_, _), .alertOnFail:
                wSelf.processModalError(wSelf.view, fail.error, retry)
            case .nonblocking:
                wSelf.failedBarView.present(in: wSelf.view, message: fail.error.localizedDescription)
            case .none: break
            }
        }.retained(by: self)
    }
    
    private var progress: AnyObject?
    private var modalProgress: AnyObject?
    private var nonBlockingProgress: AnyObject?
    
    private func reloadView(_ processing: [WorkBase:(progress: WorkProgress?, presentation: LoadingHelper.Presentation)]) {
        var opaque = false
        var modal = false
        var nonblocking = false
        
        processing.forEach { work, item in
            switch item.presentation {
            case .opaque:
                opaque = true
                failedView.removeFromSuperview()
                
                if loadingView.superview == nil {
                    loadingView.present(in: view, animated: false)
                    progress = item.progress?.$absoluteValue.sink { [weak loadingView] in
                        loadingView?.progress = $0
                    }
                }
            case .modal(let details, let cancellable):
                modal = true
                
                if modalLoadingPanel == nil, let window = view.window {
                    modalLoadingPanel = LoadingPanel.present(in: window, label: details, cancel: cancellable ? { work.cancel() } : nil)
                    modalProgress = item.progress?.$absoluteValue.sink { [weak modalLoadingPanel] in
                        modalLoadingPanel?.progress = $0
                    }
                }
            case .nonblocking:
                nonblocking = true
                
                if loadingBarView.superview == nil {
                    loadingBarView.present(in: view)
                }
            default: break
            }
        }
        
        if !opaque {
            loadingView.hide(true)
        }
        if !modal {
            modalLoadingPanel?.hide()
        }
        if !nonblocking {
            loadingBarView.hide()
        }
    }
}
