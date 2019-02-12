//
//  ContentGeneratorGradientPIX.metal
//  Pixels Shaders
//
//  Created by Hexagons on 2017-11-16.
//  Copyright © 2017 Hexagons. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// Hardcoded at 13
// Defined as uniformArrayMaxLimit in source
__constant int ARRMAX = 13;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float type;
    float scale;
    float offset;
    float px;
    float py;
    float extend;
    float premultiply;
    float aspect;
};

struct ArrayUniforms {
    float fraction;
    float cr;
    float cg;
    float cb;
    float ca;
};

struct ColorStop {
    bool enabled;
    float position;
    float4 color;
};

fragment float4 contentGeneratorGradientPIX(VertexOut out [[stage_in]],
                                            const device Uniforms& in [[ buffer(0) ]],
                                            const device array<ArrayUniforms, ARRMAX>& inArr [[ buffer(1) ]],
                                            const device array<bool, ARRMAX>& inArrActive [[ buffer(2) ]],
                                            sampler s [[ sampler(0) ]]) {

    float u = out.texCoord[0];
    float v = out.texCoord[1];
    v = 1 - v; // Content Flip Fix

    u -= in.px / in.aspect;
    v -= in.py;

    float pi = 3.14159265359;

//    float4 ac = float4(in.ar, in.ag, in.ab, in.aa);
//    float4 bc = float4(in.br, in.bg, in.bb, in.ba);

    float fraction = 0;
    if (in.type == 0) {
        // Horizontal
        fraction = (u - in.offset) / in.scale;
    } else if (in.type == 1) {
        // Vertical
        fraction = (v - in.offset) / in.scale;
    } else if (in.type == 2) {
        // Radial
        fraction = (sqrt(pow((u - 0.5) * in.aspect, 2) + pow(v - 0.5, 2)) * 2 - in.offset) / in.scale;
    } else if (in.type == 3) {
        // Angle
        fraction = (atan2(v - 0.5, (-u + 0.5) * in.aspect) / (pi * 2) + 0.5 - in.offset) / in.scale;
    }

    bool zero = false;
    switch (int(in.extend)) {
        case 0: // Hold
            if (fraction < 0) {
                fraction = 0.0;
            } else if (fraction > 1) {
                fraction = 1.0;
            }
            break;
        case 1: // Zero
            if (fraction < 0) {
                zero = true;
            } else if (fraction > 1) {
                zero = true;
            }
            break;
        case 2: // Repeat
            fraction = fraction - floor(fraction);
            break;
        case 3: // Mirror
            bool mirror = false;
            if (fraction > 0 ? int(fraction) % 2 == 1 : int(fraction) % 2 == 0) {
                mirror = true;
            }
            fraction = fraction - floor(fraction);
            if (mirror) {
                fraction = 1.0 - fraction;
            }
            break;
    }

    float4 c = 0;
    if (!zero) {

        array<ColorStop, ARRMAX> color_stops;
        for (int i = 0; i < ARRMAX; ++i) {
            ColorStop color_stop = ColorStop();
            color_stop.enabled = inArrActive[i];
            color_stop.position = inArr[i].fraction;
            color_stop.color = float4(inArr[i].cr, inArr[i].cg, inArr[i].cb, inArr[i].ca);
            color_stops[i] = color_stop;
        }
//        color_stops[0].enabled = true;
//        color_stops[0].position = 0.0;
//        color_stops[0].color = ac;
//        color_stops[1].enabled = in.eae;
//        color_stops[1].position = in.eap;
//        color_stops[1].color = float4(in.ear, in.eag, in.eab, in.eaa);
//        color_stops[2].enabled = in.ebe;
//        color_stops[2].position = in.ebp;
//        color_stops[2].color = float4(in.ebr, in.ebg, in.ebb, in.eba);
//        color_stops[3].enabled = in.ece;
//        color_stops[3].position = in.ecp;
//        color_stops[3].color = float4(in.ecr, in.ecg, in.ecb, in.eca);
//        color_stops[4].enabled = in.ede;
//        color_stops[4].position = in.edp;
//        color_stops[4].color = float4(in.edr, in.edg, in.edb, in.eda);
//        color_stops[5].enabled = true;
//        color_stops[5].position = 1.0;
//        color_stops[5].color = bc;

        ColorStop low_color_stop;
        bool low_color_stop_set = false;
        ColorStop high_color_stop;
        bool high_color_stop_set = false;
        for (int i = 0; i < ARRMAX; ++i) {
            if (color_stops[i].enabled && color_stops[i].position <= fraction && (!low_color_stop_set || color_stops[i].position > low_color_stop.position)) {
                low_color_stop = color_stops[i];
                low_color_stop_set = true;
            }
            if (color_stops[i].enabled && color_stops[i].position >= fraction && (!high_color_stop_set || color_stops[i].position < high_color_stop.position)) {
                high_color_stop = color_stops[i];
                high_color_stop_set = true;
            }
        }

        float stop_fraction = (fraction - low_color_stop.position) / (high_color_stop.position - low_color_stop.position);

        if (stop_fraction < 0) {
            stop_fraction = 0.0;
        } else if (stop_fraction > 1) {
            stop_fraction = 1.0;
        }

        c = mix(low_color_stop.color, high_color_stop.color, stop_fraction);

    }
//    else if (!zero) {
//
//        c = mix(ac, bc, fraction);
//
//    }

    if (!zero && in.premultiply) {
        c = float4(c.r * c.a, c.g * c.a, c.b * c.a, c.a);
    }

    return c;
    return float4(inArrActive[0], inArrActive[1], inArrActive[2], 1);
}
