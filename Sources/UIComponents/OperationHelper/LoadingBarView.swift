//
//  LoadingBarView.swift
//

import AppKit

open class LoadingBarView: NSView {
    
    open var fillColor = NSColor(white: 0.5, alpha: 0.1) {
        didSet { fillLayer.strokeColor = fillColor.cgColor }
    }
    
    open var clipColor = NSColor(white: 0.5, alpha: 0.2) {
        didSet { clipLayer.strokeColor = clipColor.cgColor }
    }
    
    private lazy var fillLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = fillColor.cgColor
        layer.lineCap = CAShapeLayerLineCap.round
        layer.fillColor = NSColor.clear.cgColor
        self.layer!.addSublayer(layer)
        return layer
    }()
    
    private lazy var clipLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = clipColor.cgColor
        layer.lineCap = CAShapeLayerLineCap.round
        layer.fillColor = NSColor.clear.cgColor
        self.fillLayer.addSublayer(layer)
        return layer
    }()
    
    open var progress: CGFloat = 0 {
        didSet {
            infinite = false
            fillLayer.strokeEnd = progress
            if progress <= oldValue {
                fillLayer.removeAnimation(forKey: "strokeEnd")
            }
        }
    }
    
    open var infinite: Bool = true {
        didSet {
            clipLayer.isHidden = !infinite
            if infinite {
                startAnimation()
            } else {
                clipLayer.removeAllAnimations()
            }
        }
    }
    
    required public override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        wantsLayer = true
    }
    
    public func present(in view: NSView, animated: Bool = true) {
        frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: 2)
        
        view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        view.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        heightAnchor.constraint(equalToConstant: 2).isActive = true
        
        if animated {
            alphaValue = 0
            animator().alphaValue = 1
        }
    }
    
    func hide() {
        self.removeFromSuperview()
    }
    
    open override func layout() {
        super.layout()
        
        fillLayer.frame = bounds
        clipLayer.frame = fillLayer.bounds
        
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.size.height / 2.0))
        path.line(to: CGPoint(x: bounds.size.width, y: bounds.size.height / 2.0))
        fillLayer.path = path.cgPath
        fillLayer.lineWidth = bounds.size.height
        clipLayer.lineWidth = bounds.size.height
        
        clipLayer.path = startPath()
    }
    
    private func startPath() -> CGPath {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.size.height / 2.0))
        
        var offset: CGFloat = -16.0
        
        while offset < bounds.size.width {
            path.move(to: CGPoint(x: offset, y: bounds.size.height / 2.0))
            path.line(to: CGPoint(x: offset + 6, y: bounds.size.height / 2.0))
            offset += 16
        }
        return path.cgPath
    }
    
    private func toPath() -> CGPath {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.size.height / 2.0))
        
        var offset: CGFloat = 0
        
        while offset < bounds.size.width + 16 {
            path.move(to: CGPoint(x: offset, y: bounds.size.height / 2.0))
            path.line(to: CGPoint(x: offset + 6, y: bounds.size.height / 2.0))
            offset += 16
        }
        return path.cgPath
    }
    
    private func startAnimation() {
        if clipLayer.animation(forKey: "animation") != nil { return }
        
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = startPath()
        animation.toValue = toPath()
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.repeatCount = HUGE
        clipLayer.add(animation, forKey: "animation")
    }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if self.superview != nil && infinite {
            startAnimation()
        } else {
            clipLayer.removeAllAnimations()
        }
    }
}
