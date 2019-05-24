//
//  Metal.swift
//  MetalPaint
//
//  Created by Ryder Mackay on 2015-12-02.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

import Metal
import simd

final class QuadRenderer {
    
    var texturedQuad: TexturedQuad
    var blendRGBAndAlphaPipelineState: MTLRenderPipelineState!
    var blendRGBOnlyPipelineState: MTLRenderPipelineState!
    
    init(device: MTLDevice) {
        texturedQuad = TexturedQuad(device: device)
        
        let library = device.makeDefaultLibrary()!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "passThroughVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "passThroughFragment")
        
        // enable source over blending, e.g. r = (s * s.a) + d * (1 - s.a)
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        blendRGBOnlyPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        blendRGBAndAlphaPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    // set transforms etc.
    func updateUniforms() {
        
    }
    
    func renderTexture(texture: MTLTexture, inTexture colorAttachmentTexture: MTLTexture, commandBuffer: MTLCommandBuffer, shouldClear: Bool, textureIsPremultipled: Bool) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = shouldClear ? .clear : .load
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].texture = colorAttachmentTexture
        
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        renderCommandEncoder.setRenderPipelineState(textureIsPremultipled ? blendRGBOnlyPipelineState : blendRGBAndAlphaPipelineState)
        texturedQuad.encodeDrawCommands(encoder: renderCommandEncoder, texture: texture)
        renderCommandEncoder.endEncoding()
    }
}

struct Vertex {
    let position: float4
    let textureCoords: float2
    
    init(x: Float, y: Float, u: Float, v: Float) {
        position = float4(x, y, 1, 1)
        textureCoords = float2(u, v)
    }
}

final class TexturedQuad {
    
    static var vertices: [Vertex] {
        return [
            Vertex(x: -1, y: -1, u: 0, v: 1),
            Vertex(x:  1, y: -1, u: 1, v: 1),
            Vertex(x:  1, y:  1, u: 1, v: 0),
            Vertex(x:  1, y:  1, u: 1, v: 0),
            Vertex(x: -1, y:  1, u: 0, v: 0),
            Vertex(x: -1, y: -1, u: 0, v: 1),
        ]
    }
    
    private let device: MTLDevice
    private let vertexBuffer: MTLBuffer
    private let samplerState: MTLSamplerState
    
    init(device: MTLDevice) {
        self.device = device
        var vertices = TexturedQuad.vertices
        vertexBuffer = device.makeBuffer(bytes: &vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    var primitiveType: MTLPrimitiveType { return .triangle }
    var vertexCount: Int { return vertexBuffer.length / MemoryLayout<Vertex>.stride }
    
    func encodeDrawCommands(encoder: MTLRenderCommandEncoder, texture: MTLTexture) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: vertexCount)
    }
}
