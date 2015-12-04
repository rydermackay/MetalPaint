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
        
        let library = device.newDefaultLibrary()!
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        renderPipelineDescriptor.vertexFunction = library.newFunctionWithName("passThroughVertex")
        renderPipelineDescriptor.fragmentFunction = library.newFunctionWithName("passThroughFragment")
        
        // enable source over blending, e.g. r = (s * s.a) + d * (1 - s.a)
        renderPipelineDescriptor.colorAttachments[0].blendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .Add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .Add
        
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .One
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .One
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .OneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .OneMinusSourceAlpha
        
        blendRGBOnlyPipelineState = try! device.newRenderPipelineStateWithDescriptor(renderPipelineDescriptor)
        
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .SourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .SourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .OneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .OneMinusSourceAlpha
        
        blendRGBAndAlphaPipelineState = try! device.newRenderPipelineStateWithDescriptor(renderPipelineDescriptor)
    }
    
    // set transforms etc.
    func updateUniforms() {
        
    }
    
    func renderTexture(texture: MTLTexture, inTexture colorAttachmentTexture: MTLTexture, commandBuffer: MTLCommandBuffer, shouldClear: Bool, textureIsPremultipled: Bool) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = shouldClear ? .Clear : .Load
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        descriptor.colorAttachments[0].storeAction = .Store
        descriptor.colorAttachments[0].texture = colorAttachmentTexture
        
        let renderCommandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(descriptor)
        renderCommandEncoder.setRenderPipelineState(textureIsPremultipled ? blendRGBOnlyPipelineState : blendRGBAndAlphaPipelineState)
        texturedQuad.encodeDrawCommands(renderCommandEncoder, texture: texture)
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
        vertexBuffer = device.newBufferWithBytes(&vertices, length: vertices.count * strideof(Vertex), options: [])
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .ClampToEdge
        samplerDescriptor.tAddressMode = .ClampToEdge
        samplerDescriptor.minFilter = .Linear
        samplerDescriptor.magFilter = .Linear
        
        samplerState = device.newSamplerStateWithDescriptor(samplerDescriptor)
    }
    
    var primitiveType: MTLPrimitiveType { return .Triangle }
    var vertexCount: Int { return vertexBuffer.length / strideof(Vertex) }
    
    func encodeDrawCommands(encoder: MTLRenderCommandEncoder, texture: MTLTexture) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        encoder.setFragmentTexture(texture, atIndex: 0)
        encoder.setFragmentSamplerState(samplerState, atIndex: 0)
        encoder.drawPrimitives(primitiveType, vertexStart: 0, vertexCount: vertexCount)
    }
}
