//
//  LoadingView.swift
//

import AppKit
import CommonUtils

open class LoadingView: NSView {
    
    @IBOutlet open var indicator: NSProgressIndicator?
    @IBOutlet open var background: NSBox?
    
    open var progress: CGFloat = 0 {
        didSet {
            if oldValue == progress { return }
            
            indicator?.isIndeterminate = false
            
            if oldValue < progress {
                indicator?.animator().doubleValue = progress
            } else {
                indicator?.doubleValue = progress
            }
        }
    }
    
    open func present(in view: NSView, animated: Bool) {
        indicator?.doubleValue = 0
        indicator?.isIndeterminate = true
        view.attach(self)
        
        if animated {
            view.alphaValue = 0
            view.animator().alphaValue = 1
        }
        performLazyLoading()
    }
    
    func performLazyLoading() {
        indicator?.isHidden = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let wSelf = self else { return }
            
            wSelf.addFadeTransition()
            if let wSelf = self, wSelf.indicator?.isHidden != false {
                wSelf.indicator?.isHidden = false
                wSelf.indicator?.startAnimation(nil)
            }
        }
    }
    
    open func hide(_ animated: Bool) {
        if indicator?.isIndeterminate == false {
            progress = 1
        }
        self.animator().removeFromSuperview()
    }
    
    override open func mouseDown(with event: NSEvent) { }
}

