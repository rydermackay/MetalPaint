//
//  ViewController.swift
//  MetalPaint
//
//  Created by Ryder Mackay on 2015-12-02.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import UIKit
import MetalKit
import Metal
import simd

struct Size {
    let width, height: Int
}

final class Line {
    func drawInLayer(layer: Layer) {
        
    }
}

final class Layer {
    let buffer: MTLBuffer
    let texture: MTLTexture
    let width: Int
    let height: Int
    var size: CGSize { return CGSize(width: width, height: height) }
    
    // creates a texture in device to render into
    init(size: CGSize, device: MTLDevice) {
        let width = Int(floor(size.width))
        let height = Int(floor(size.height))
        self.width = width
        self.height = height
        let bytesPerRow = width * 4
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: width, height: height, mipmapped: false)
        buffer = device.newBufferWithLength(bytesPerRow * height, options: .StorageModeShared)
        texture = buffer.newTextureWithDescriptor(descriptor, offset: 0, bytesPerRow: bytesPerRow)
    }
    
    func drawInLayer(layer: Layer) {
        
    }
    
    func drawInView(view: MTKView) {
        
    }
    
    func drawInTexture(texture: MTLTexture) {
        
    }
}














extension ViewController: MTKViewDelegate {
    func drawInMTKView(view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        let commandBuffer = commandQueue.commandBuffer()
        
        renderer.renderTexture(frozenLayer.texture, inTexture: drawable.texture, commandBuffer: commandBuffer, shouldClear: true, textureIsPremultipled: true)
        
        if let texture = activeLayer?.texture {
            renderer.renderTexture(texture, inTexture: drawable.texture, commandBuffer: commandBuffer, shouldClear: false, textureIsPremultipled: true)
            renderer.renderTexture(predictiveLayer!.texture, inTexture: drawable.texture, commandBuffer: commandBuffer, shouldClear: false, textureIsPremultipled: true)
        }
        
        commandBuffer.presentDrawable(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        // update uniforms, temporary buffers etc
    }
}


class ViewController: UIViewController {

    lazy var renderer: QuadRenderer = { return QuadRenderer(device: self.device) }()
    lazy var commandQueue: MTLCommandQueue = { return self.device.newCommandQueue() }()
    
    var metalView: MTKView!
    
    var device: MTLDevice!
    
    var brushTexture: MTLTexture!
    
    override func loadView() {
        super.loadView()
        
        metalView = self.view as! MTKView
        
        let view = UIView(frame: metalView.bounds)
        metalView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        metalView.frame = view.bounds
        view.addSubview(metalView)
        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let device = MTLCreateSystemDefaultDevice() {
            
            self.device = device
            
            metalView.device = device
            metalView.enableSetNeedsDisplay = true
            metalView.delegate = self
            
            let length = 22
            let rect = CGRect(origin: .zero, size: CGSize(width: length, height: length))
            UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
            UIColor.blackColor().setFill()
            UIBezierPath(ovalInRect: rect).fill()
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            brushTexture = try! MTKTextureLoader(device: device).newTextureWithCGImage(image.CGImage!, options: nil)
        }
        
        let doubleTap = UITapGestureRecognizer(target: self, action: "clear:")
        doubleTap.numberOfTapsRequired = 1
        doubleTap.numberOfTouchesRequired = 2
        doubleTap.allowedTouchTypes = [NSNumber(integer: UITouchType.Direct.rawValue)]
        view.addGestureRecognizer(doubleTap)
        
        
        colorPicker = ColorPicker()
        colorPicker.colors = [.blackColor(), .redColor(), .orangeColor(), .yellowColor(), .greenColor(), .blueColor(), .purpleColor()]
        colorPicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(colorPicker)
        view.leftAnchor.constraintLessThanOrEqualToAnchor(colorPicker.leftAnchor).active = true
        view.rightAnchor.constraintGreaterThanOrEqualToAnchor(colorPicker.rightAnchor).active = true
        view.centerXAnchor.constraintEqualToAnchor(colorPicker.centerXAnchor).active = true
        view.bottomAnchor.constraintEqualToAnchor(colorPicker.bottomAnchor).active = true
        colorPicker.addTarget(self, action: "pickedColor:", forControlEvents: .ValueChanged)
    }
    
    var colorPicker: ColorPicker!
    var selectedColor = UIColor.blackColor()
    
    @IBAction func pickedColor(sender: ColorPicker) {
        selectedColor = sender.colors[sender.selectedIndex]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func clear(sender: AnyObject?) {
        for layer in [frozenLayer, activeLayer!, predictiveLayer!] {
            clearLayer(layer)
        }
        metalView.setNeedsDisplay()
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    var activeLayer: Layer?
    var predictiveLayer: Layer?
    lazy var frozenLayer: Layer! = { return Layer(size: self.metalView.drawableSize, device: self.device) }()
    
    // need event b/c it has coalesced + predicted touches
    func drawTouches(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if activeLayer == nil {
            activeLayer = Layer(size: frozenLayer.size, device: device)
        }
        
        if predictiveLayer == nil {
            predictiveLayer = Layer(size: activeLayer!.size, device: device)
        }
        
        for touch in touches {
            
            // get or create active line for touch via map table
            
            // remove predicted touches and mark area as needing redraw
            clearLayer(predictiveLayer!)
            
            // add touch methods should return dirty rect
            
            if let coalescedTouches = event?.coalescedTouchesForTouch(touch) {
                addPointsToLineForTouches(coalescedTouches, type: .Coalesced)
            } else {
                addPointsToLineForTouches([touch], type: .Main)
            }
            if let predictedTouches = event?.predictedTouchesForTouch(touch) {
                addPointsToLineForTouches(predictedTouches, type: .Predicted)
            }
        }
        
        metalView.setNeedsDisplay()
    }
    
    func clearLayer(layer: Layer) {
        let commandBuffer = commandQueue.commandBuffer()
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[0].loadAction = .Clear
        descriptor.colorAttachments[0].texture = layer.texture
        descriptor.colorAttachments[0].storeAction = .Store
        let renderCommandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(descriptor)
        renderCommandEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    enum TouchType {
        case Main
        case Coalesced
        case Predicted
    }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()!
    
    lazy var ciContext: CIContext = {
        return CIContext(MTLDevice: self.device, options: [
            kCIContextOutputColorSpace: self.colorSpace,
            kCIContextWorkingColorSpace: self.colorSpace
        ])
    }()
    
    var coreImageRenderDestinationTexture: MTLTexture!
    
    var lastCommandBuffer: MTLCommandBuffer!
    
    /// CIColorControls inputBiasVector value. Note alpha is zero.
    var selectedColorVector: CIVector {
        let color = CIColor(color: selectedColor)
        return CIVector(x: color.red, y: color.green, z: color.blue, w: 0)
    }
    
    func addPointsToLineForTouches(touches: [UITouch], type: TouchType) {
        
        let texture = type == .Predicted ? predictiveLayer!.texture : activeLayer!.texture
        let sourceImage = CIImage(MTLTexture: texture, options: [kCIImageColorSpace: colorSpace])
        
        let brushSize = MTLSize(width: brushTexture.width, height: brushTexture.height, depth: 1)
        
        if coreImageRenderDestinationTexture == nil {
            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: brushSize.width, height: brushSize.height, mipmapped: false)
            descriptor.usage = [.RenderTarget, .ShaderRead, .ShaderWrite]
            coreImageRenderDestinationTexture = device.newTextureWithDescriptor(descriptor)
        }
        
        let commandBuffer = commandQueue.commandBuffer()
        
        for touch in touches {
            
            var point = touch.preciseLocationInView(view)
            point.x = metalView.drawableSize.width * point.x / metalView.bounds.width
            point.y = metalView.drawableSize.height * point.y / metalView.bounds.height
            let size = CGSize(width: brushTexture.width, height: brushTexture.height)
            let translation = CGAffineTransformMakeTranslation(floor(point.x - size.width / 2), floor(point.y - size.height / 2))
            var brushImage = CIImage(MTLTexture: brushTexture, options: [kCIImageColorSpace: colorSpace]).imageByApplyingTransform(translation)
            brushImage = brushImage.imageByApplyingFilter("CIColorMatrix", withInputParameters: ["inputBiasVector": selectedColorVector]).imageByCroppingToRect(brushImage.extent)
            
            if touch.type == .Stylus || touch.force > 0 {
                let alpha = max(touch.force / touch.maximumPossibleForce, 0.025)
                brushImage = brushImage.imageWithAlpha(alpha)
            }
            
            let renderImage = brushImage.imageByCompositingOverImage(sourceImage).imageByCroppingToRect(brushImage.extent).imageByCroppingToRect(sourceImage.extent) // should slice off edges
            if renderImage.extent.isNull {
                continue
            }
            
            let extent = renderImage.extent
            let region = MTLRegionMake2D(Int(extent.minX), Int(extent.minY), Int(extent.width), Int(extent.height))
            
            // CoreImage will give you premultiplied color values so if you blend RGB w/ sourceAlpha you'll just darken the image to nothing
            // treat the content of this buffer (and all active line buffers) as premultiplied
            ciContext.render(renderImage, toMTLTexture: coreImageRenderDestinationTexture, commandBuffer: commandBuffer, bounds: renderImage.extent, colorSpace: colorSpace)
            
            let blit = commandBuffer.blitCommandEncoder()
            blit.copyFromTexture(coreImageRenderDestinationTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: Int(extent.width), height: Int(extent.height), depth: 1), toTexture: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: region.origin)
            blit.endEncoding()
        }
        
        commandBuffer.commit()
    }
    
    var shouldUseCoalescedTouches = true
    
    func endTouches(touches: Set<UITouch>, cancel: Bool) {
        if !cancel {
            // snapshot + put on undo stack
            activeLayer?.drawInLayer(frozenLayer)
            
            
            let commandBuffer = commandQueue.commandBuffer()
            renderer.renderTexture(activeLayer!.texture, inTexture: frozenLayer.texture, commandBuffer: commandBuffer, shouldClear: false, textureIsPremultipled: true)
            commandBuffer.commit()
        }
        
        clearLayer(activeLayer!)
        clearLayer(predictiveLayer!)
        
        // cancel? discard layer
        // otherwise snapshot frozen layer under layer's rect, then source-over composite it into frozen layer
        
        metalView.setNeedsDisplay()
    }
    
    func updateEstimatedPropertiesForTouches(touches: Set<NSObject>) {
        guard let touches = touches as? Set<UITouch> else { return } // swift overlay bug?
    }
    
    
    func hitTestColorPickerWithTouches(touches: Set<UITouch>, withEvent event: UIEvent?, shouldHide: Bool) {
        for touch in touches {
            if (colorPicker.hitTest(touch.locationInView(colorPicker), withEvent: event) != nil) {
                // hide color picker
                UIView.animateWithDuration(0.2) {
                    self.colorPicker.alpha = 0
                }
            }
        }
    }
    
    func showColorPicker() {
        UIView.animateWithDuration(0.2) {
            self.colorPicker.alpha = 1
        }
    }
}

extension CIImage {
    func imageWithAlpha(alpha: CGFloat) -> CIImage {
        return imageByApplyingFilter("CIColorMatrix", withInputParameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
    }
}

// MARK: Touch handling

extension ViewController {
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        drawTouches(touches, withEvent: event)
        hitTestColorPickerWithTouches(touches, withEvent: event, shouldHide: true)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        drawTouches(touches, withEvent: event)
        hitTestColorPickerWithTouches(touches, withEvent: event, shouldHide: true)
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        // when is this called w/ nil touches?
        endTouches(touches ?? [], cancel: true)
        showColorPicker()
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        drawTouches(touches, withEvent: event)
        endTouches(touches, cancel: false)
        showColorPicker()
    }
    
    override func touchesEstimatedPropertiesUpdated(touches: Set<NSObject>) {
        updateEstimatedPropertiesForTouches(touches)
    }
}

