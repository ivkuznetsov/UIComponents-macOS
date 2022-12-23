//
//  FooterLoadingView.swift
//

import AppKit

public class FooterLoadingView: NSView {

    public enum State {
        case stop
        case loading
        case failed
    }
    
    open var state: State = .stop {
        didSet {
            if state != oldValue {
                retryButton.isHidden = state != .failed
                if state == .loading {
                    indicatorView.startAnimation(nil)
                } else {
                    indicatorView.stopAnimation(nil)
                }
            }
        }
    }
    var retry: (()->())?
    
    @IBOutlet public var indicatorView: NSProgressIndicator!
    @IBOutlet public var retryButton: NSButton!
    
    @IBAction private func retryAction(_ sender: Any?) {
        retry?()
    }
}
