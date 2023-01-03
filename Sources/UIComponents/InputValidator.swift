//
//  InputValidator.swift
//

import Foundation
import AppKit
import CommonUtils
import SharedUIComponents

public protocol InputValidatorDelegate: AnyObject {
    
    func isValid(input: NSView) -> InputValidator.Result?
}

public class InputValidator: StaticSetupObject, NSTextFieldDelegate {
    
    public weak var delegate: InputValidatorDelegate?
    public var actionButton: NSButton?
    public var showFail: ((String, NSView)->NSPopover?)?

    public enum Result {
        case valid
        case invalid(String?)
    }
    
    private var observers: [Any] = []
    private weak var presentedFail: NSPopover? {
        didSet { oldValue?.close() }
    }
    
    public var inputs: [NSView] = [] {
        didSet {
            observers.removeAll()
            inputs.forEach {
                if let field = $0 as? NSTextField {
                    
                    observers.append(field.observe(\.stringValue) { [weak self] _, _ in
                        self?.validate(showsFail: false)
                    })
                    observers.append(NotificationCenter.default.addObserver(forName: NSControl.textDidChangeNotification, object: field, queue: nil) { [weak self] _ in
                        self?.validate(showsFail: false)
                    })
                }
            }
            validate(showsFail: false)
        }
    }
    
    @discardableResult
    public func validate(showsFail: Bool = true) -> Bool {
        presentedFail = nil
        var failShowed = false
        var valid = true
        var buttonEnabled = true
        
        inputs.forEach {
            let result = delegate?.isValid(input: $0)
            
            if let result = result {
                switch result {
                case .invalid(let message):
                    
                    if let message = message {
                        if !failShowed && showsFail {
                            failShowed = true
                            presentedFail = showFail?(message, $0)
                        }
                    } else {
                        buttonEnabled = false
                    }
                    valid = false
                case .valid: break
                }
            } else {
                if let field = $0 as? NSTextField {
                    if !field.stringValue.isValid {
                        valid = false
                        
                        if showsFail {
                            field.addShake()
                        }
                        buttonEnabled = false
                    }
                }
            }
        }
        actionButton?.isEnabled = buttonEnabled
        return valid
    }
}
