//
//  ColorPicker.swift
//  MetalPaint
//
//  Created by Ryder Mackay on 2015-12-03.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import UIKit


final class ColorPicker : UIControl {
    
    fileprivate var buttons: [UIButton] = []
    
    var stackView: UIStackView!
    lazy var visualEffectView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .light)
        let v = UIVisualEffectView(effect: effect)
        v.frame = self.bounds
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(v)
        return v
    }()
    
    var colors: [UIColor] = [] {
        didSet {
            if stackView != nil {
                stackView.removeFromSuperview()
            }
            
            buttons = colors.map {
                let b = UIButton(type: .custom)
                b.setImage(swatchImageForColor($0, forState: UIControlState()), for: UIControlState())
                b.addTarget(self, action: #selector(ColorPicker.selectColor(_:)), for: .touchUpInside)
                return b
            }
            stackView = UIStackView(arrangedSubviews: buttons)
            stackView.axis = .horizontal
            stackView.frame = visualEffectView.contentView.bounds
            stackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            stackView.distribution = .equalSpacing
            stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            stackView.isLayoutMarginsRelativeArrangement = true
            visualEffectView.contentView.addSubview(stackView)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let maskLayer = CAShapeLayer()
        maskLayer.frame = layer.bounds
        maskLayer.path = UIBezierPath(roundedRect: layer.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 10, height: 10)).cgPath
        layer.mask = maskLayer
    }
    
    override var intrinsicContentSize : CGSize {
        return CGSize(width: 20 + colors.count * (44 + 20) + 20, height: 44 + 40)
    }
    
    @IBAction func selectColor(_ sender: UIButton) {
        selectedIndex = buttons.index(of: sender)!
        sendActions(for: .valueChanged)
    }
    
    var selectedIndex: Int = 0 {
        didSet {
            for (index, button) in buttons.enumerated() {
                button.isSelected = index == selectedIndex
            }
        }
    }
    
    func swatchImageForColor(_ color: UIColor, forState state: UIControlState) -> UIImage {
        let length = 44
        let rect = CGRect(origin: .zero, size: CGSize(width: length, height: length))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        color.setFill()
        let oval = UIBezierPath(ovalIn: rect)
        oval.addClip()
        oval.fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}
