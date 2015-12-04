//
//  Shaders.metal
//  MetalPaint
//
//  Created by Ryder Mackay on 2015-12-02.
//  Copyright © 2015 Ryder Mackay. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexInOut
{
    float4  position [[position]];
    float2  texCoords;
};

vertex VertexInOut passThroughVertex(uint vid [[ vertex_id ]],
                                     constant VertexInOut *vertices [[ buffer(0) ]])
{
    VertexInOut outVertex;
    
    outVertex.position  = vertices[vid].position;
    outVertex.texCoords = vertices[vid].texCoords;
    
    return outVertex;
};

fragment float4 passThroughFragment(VertexInOut vert [[stage_in]],
                                    sampler samplr [[sampler(0)]],
                                    texture2d<float, access::sample> texture [[texture(0)]])
{
    return texture.sample(samplr, vert.texCoords);
};
