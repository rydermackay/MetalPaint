//
//  ColorPicker.swift
//  MetalPaint
//
//  Created by Ryder Mackay on 2015-12-03.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import UIKit


final class ColorPicker : UIControl {
    
    private var buttons: [UIButton] = []
    
    var stackView: UIStackView!
    lazy var visualEffectView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .Light)
        let v = UIVisualEffectView(effect: effect)
        v.frame = self.bounds
        v.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.addSubview(v)
        return v
    }()
    
    var colors: [UIColor] = [] {
        didSet {
            if stackView != nil {
                stackView.removeFromSuperview()
            }
            
            buttons = colors.map {
                let b = UIButton(type: .Custom)
                b.setImage(swatchImageForColor($0, forState: .Normal), forState: .Normal)
                b.addTarget(self, action: "selectColor:", forControlEvents: .TouchUpInside)
                return b
            }
            stackView = UIStackView(arrangedSubviews: buttons)
            stackView.axis = .Horizontal
            stackView.frame = visualEffectView.contentView.bounds
            stackView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            stackView.distribution = .EqualSpacing
            stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            stackView.layoutMarginsRelativeArrangement = true
            visualEffectView.contentView.addSubview(stackView)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let maskLayer = CAShapeLayer()
        maskLayer.frame = layer.bounds
        maskLayer.path = UIBezierPath(roundedRect: layer.bounds, byRoundingCorners: [.TopLeft, .TopRight], cornerRadii: CGSize(width: 10, height: 10)).CGPath
        layer.mask = maskLayer
    }
    
    override func intrinsicContentSize() -> CGSize {
        return CGSize(width: 20 + colors.count * (44 + 20) + 20, height: 44 + 40)
    }
    
    @IBAction func selectColor(sender: UIButton) {
        selectedIndex = buttons.indexOf(sender)!
        sendActionsForControlEvents(.ValueChanged)
    }
    
    var selectedIndex: Int = 0 {
        didSet {
            for (index, button) in buttons.enumerate() {
                button.selected = index == selectedIndex
            }
        }
    }
    
    func swatchImageForColor(color: UIColor, forState state: UIControlState) -> UIImage {
        let length = 44
        let rect = CGRect(origin: .zero, size: CGSize(width: length, height: length))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        color.setFill()
        let oval = UIBezierPath(ovalInRect: rect)
        oval.addClip()
        oval.fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
