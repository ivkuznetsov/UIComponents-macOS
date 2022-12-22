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
                switch state {
                case .stop:
                    indicatorView.stopAnimation(nil)
                    retryButton.isHidden = true
                case .loading:
                    indicatorView.startAnimation(nil)
                    retryButton.isHidden = true
                case .failed:
                    indicatorView.stopAnimation(nil)
                    retryButton.isHidden = false
                }
            }
        }
    }
    var retry: (()->())?
    
    @IBOutlet public var indicatorView: NSProgressIndicator!
    @IBOutlet public var retryButton: NSButton!
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        state = .stop
    }
    
    @IBAction private func retryAction(_ sender: Any?) {
        retry?()
    }
}
