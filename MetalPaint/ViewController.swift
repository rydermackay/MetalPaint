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
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage.insert(.renderTarget)
        texture = device.makeTexture(descriptor: descriptor)!
    }
    
    func drawInLayer(layer: Layer) {
        
    }
    
    func drawInView(view: MTKView) {
        
    }
    
    func drawInTexture(texture: MTLTexture) {
        
    }
}














extension ViewController: MTKViewDelegate {
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        renderer.renderTexture(texture: frozenLayer.texture, inTexture: drawable.texture, commandBuffer: commandBuffer, shouldClear: true, textureIsPremultipled: true)
        
        if let texture = activeLayer?.texture {
            renderer.renderTexture(texture: texture, inTexture: drawable.texture, commandBuffer: commandBuffer, shouldClear: false, textureIsPremultipled: true)
            renderer.renderTexture(texture: predictiveLayer!.texture, inTexture: drawable.texture, commandBuffer: commandBuffer, shouldClear: false, textureIsPremultipled: true)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // update uniforms, temporary buffers etc
    }
}


class ViewController: UIViewController {

    lazy var renderer: QuadRenderer = { return QuadRenderer(device: self.device) }()
    lazy var commandQueue = device.makeCommandQueue()!
    
    @IBOutlet var metalView: MTKView!
    
    var device: MTLDevice!
    
    var brushTexture: MTLTexture!

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
            UIColor.black.setFill()
            UIBezierPath(ovalIn: rect).fill()
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            brushTexture = try! MTKTextureLoader(device: device).newTexture(cgImage: image.cgImage!, options: nil)
        }
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(clear(_:)))
        doubleTap.numberOfTapsRequired = 1
        doubleTap.numberOfTouchesRequired = 2
        doubleTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        view.addGestureRecognizer(doubleTap)
        
        
        colorPicker = ColorPicker()
        colorPicker.colors = [.black, .red, .orange, .yellow, .green, .blue, .purple]
        colorPicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(colorPicker)
        view.leftAnchor.constraint(lessThanOrEqualTo: colorPicker.leftAnchor).isActive = true
        view.rightAnchor.constraint(greaterThanOrEqualTo: colorPicker.rightAnchor).isActive = true
        view.centerXAnchor.constraint(equalTo: colorPicker.centerXAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: colorPicker.bottomAnchor).isActive = true
        colorPicker.addTarget(self, action: #selector(pickedColor(_:)), for: .valueChanged)
    }
    
    var colorPicker: ColorPicker!
    var selectedColor = UIColor.black
    
    @IBAction func pickedColor(_ sender: ColorPicker) {
        selectedColor = sender.colors[sender.selectedIndex]
    }
    
    @IBAction func clear(_ sender: AnyObject?) {
        for layer in ([frozenLayer, activeLayer!, predictiveLayer!] as! [Layer]) {
            clearLayer(layer: layer)
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
            clearLayer(layer: predictiveLayer!)
            
            // add touch methods should return dirty rect
            
            if let coalescedTouches = event?.coalescedTouches(for: touch) {
                addPointsToLineForTouches(touches: coalescedTouches, type: .Coalesced)
            } else {
                addPointsToLineForTouches(touches: [touch], type: .Main)
            }
            if let predictedTouches = event?.predictedTouches(for: touch) {
                addPointsToLineForTouches(touches: predictedTouches, type: .Predicted)
            }
        }
        
        metalView.setNeedsDisplay()
    }
    
    func clearLayer(layer: Layer) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].texture = layer.texture
        descriptor.colorAttachments[0].storeAction = .store
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        renderCommandEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    enum TouchType {
        case Main
        case Coalesced
        case Predicted
    }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    lazy var ciContext: CIContext = {
        return CIContext(mtlDevice: self.device, options: [
            CIContextOption.outputColorSpace: self.colorSpace,
            CIContextOption.workingColorSpace: self.colorSpace
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
        let sourceImage = CIImage(mtlTexture: texture, options: [CIImageOption.colorSpace: colorSpace])
        
        let brushSize = MTLSize(width: brushTexture.width, height: brushTexture.height, depth: 1)
        
        if coreImageRenderDestinationTexture == nil {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: brushSize.width, height: brushSize.height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            coreImageRenderDestinationTexture = device.makeTexture(descriptor: descriptor)
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        for touch in touches {
            
            var point = touch.preciseLocation(in: view)
            point.x = metalView.drawableSize.width * point.x / metalView.bounds.width
            point.y = metalView.drawableSize.height * point.y / metalView.bounds.height
            let size = CGSize(width: brushTexture.width, height: brushTexture.height)
            let translation = CGAffineTransform(translationX: floor(point.x - size.width / 2), y: floor(point.y - size.height / 2))
            var brushImage = CIImage(mtlTexture: brushTexture, options: [CIImageOption.colorSpace: colorSpace])!.transformed(by: translation)
            brushImage = brushImage.applyingFilter("CIColorMatrix", parameters: ["inputBiasVector": selectedColorVector]).cropped(to: brushImage.extent)
            
            if touch.type == .stylus || touch.force > 0 {
                let alpha = max(touch.force / touch.maximumPossibleForce, 0.025)
                brushImage = brushImage.image(withAlpha: alpha)
            }
            
            let renderImage = brushImage.composited(over: sourceImage!).cropped(to: brushImage.extent).cropped(to: sourceImage!.extent) // should slice off edges
            if renderImage.extent.isNull {
                continue
            }
            
            let extent = renderImage.extent
            let region = MTLRegionMake2D(Int(extent.minX), Int(extent.minY), Int(extent.width), Int(extent.height))
            
            // CoreImage will give you premultiplied color values so if you blend RGB w/ sourceAlpha you'll just darken the image to nothing
            // treat the content of this buffer (and all active line buffers) as premultiplied
            ciContext.render(renderImage, to: coreImageRenderDestinationTexture, commandBuffer: commandBuffer, bounds: renderImage.extent, colorSpace: colorSpace)
            
            let blit = commandBuffer.makeBlitCommandEncoder()!
            blit.copy(from: coreImageRenderDestinationTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: Int(extent.width), height: Int(extent.height), depth: 1), to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: region.origin)
            blit.endEncoding()
        }
        
        commandBuffer.commit()
    }
    
    var shouldUseCoalescedTouches = true
    
    func endTouches(touches: Set<UITouch>, cancel: Bool) {
        if !cancel {
            // snapshot + put on undo stack
            activeLayer?.drawInLayer(layer: frozenLayer)
            
            
            let commandBuffer = commandQueue.makeCommandBuffer()!
            renderer.renderTexture(texture: activeLayer!.texture, inTexture: frozenLayer.texture, commandBuffer: commandBuffer, shouldClear: false, textureIsPremultipled: true)
            commandBuffer.commit()
        }
        
        clearLayer(layer: activeLayer!)
        clearLayer(layer: predictiveLayer!)
        
        // cancel? discard layer
        // otherwise snapshot frozen layer under layer's rect, then source-over composite it into frozen layer
        
        metalView.setNeedsDisplay()
    }
    
    
    func hitTestColorPicker(with touches: Set<UITouch>, event: UIEvent?, shouldHide: Bool) {
        for touch in touches {
            if colorPicker.hitTest(touch.location(in: colorPicker), with: event) != nil {
                // hide color picker
                UIView.animate(withDuration: 0.2) {
                    self.colorPicker.alpha = 0
                }
            }
        }
    }
    
    func showColorPicker() {
        UIView.animate(withDuration: 0.2) {
            self.colorPicker.alpha = 1
        }
    }
}

extension CIImage {
    func image(withAlpha alpha: CGFloat) -> CIImage {
        return applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
    }
}

// MARK: Touch handling

extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawTouches(touches: touches, withEvent: event)
        hitTestColorPicker(with: touches, event: event, shouldHide: true)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawTouches(touches: touches, withEvent: event)
        hitTestColorPicker(with: touches, event: event, shouldHide: true)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches: touches, cancel: true)
        showColorPicker()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawTouches(touches: touches, withEvent: event)
        endTouches(touches: touches, cancel: false)
        showColorPicker()
    }
    
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        // update force or pencil tilt
    }
}

