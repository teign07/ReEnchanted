#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Noise lives in paper coordinates, never in the clock. Fibres do not swim
// across the leaf; only the amount of pigment travelling through them changes.
static float pigmentHash(float2 p, float seed) {
    return fract(sin(dot(p, float2(127.1, 311.7)) + seed * 73.19) * 43758.5453);
}

static float pigmentNoise(float2 p, float seed) {
    float2 cell = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(pigmentHash(cell, seed), pigmentHash(cell + float2(1, 0), seed), f.x),
               mix(pigmentHash(cell + float2(0, 1), seed), pigmentHash(cell + 1, seed), f.x), f.y);
}

static half4 pigmentPool(SwiftUI::Layer layer, float2 p, float radius) {
    half4 pool = layer.sample(p) * half(0.20);
    constexpr float2 ring[] = {float2(1, 0), float2(-1, 0), float2(0, 1), float2(0, -1),
                             float2(.71, .71), float2(-.71, .71), float2(.71, -.71), float2(-.71, -.71)};
    for (int i = 0; i < 8; ++i) {
        pool += layer.sample(p + ring[i] * radius) * half(0.10);
    }
    return pool;
}

// Every colour sample comes from the actual rendered marks, including the
// accent word and coloured artwork. No rectangular fade or replacement ink.
[[ stitchable ]] half4 bookPigment(float2 position, SwiftUI::Layer layer,
                                  float4 bounds, float progress, float sinking,
                                  float seed, float regionDelaySpan, float regionDuration, float objectDelay,
                                  texture2d<half> sentenceClock) {
    if (progress <= 0) return sinking > .5 ? layer.sample(position) : half4(0);
    if (progress >= 1) return sinking > .5 ? half4(0) : layer.sample(position);

    constexpr sampler mapSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float2 uv = (position - bounds.xy - 12) / max(bounds.zw - 24, float2(1));
    float3 clockBits = step(float3(.5), float3(sentenceClock.sample(mapSampler, uv).rgb));
    float sentenceDelay = dot(clockBits, float3(1, 2, 4)) / 7 * regionDelaySpan;
    float cloud = pigmentNoise(position / 19.0, seed);
    float delay = sinking > .5 ? 0 : objectDelay + sentenceDelay + .02 * cloud;
    // Later sentences keep their full wet phase and finish later. Compressing
    // by (1 - delay) made every sentence dry together on the old leaf clock.
    float p = saturate((progress - delay) / (sinking > .5 ? 1 : regionDuration));
    // The final blend already returns the exact source at p == 1. A region
    // that has dried needs none of the two nine-sample pigment pools, even
    // while later sentences on the same leaf are still gathering.
    if (sinking <= .5 && p >= 1) return layer.sample(position);

    float grain = pigmentHash(floor(position * 1.7), seed + 4);
    float fibre = .5 + .5 * sin(position.y * 2.6 + pigmentNoise(position / 7.0, seed + 2) * 8.0);
    float2 wander = float2(pigmentNoise(position / 11.0, seed + 7),
                          pigmentNoise(position / 9.0, seed + 13)) * 2 - 1;

    if (sinking > .5) {
        // Wet first, then loosen the strokes into fibres; submerged residue
        // survives the last recognisable letter, and the endpoint is empty.
        float wet = smoothstep(0.0, .16, p) * (1 - smoothstep(.32, .76, p));
        float dissolve = smoothstep(.14, .86, p);
        float spread = .3 + 5.0 * dissolve;
        float2 drift = wander * (4.0 * dissolve) + float2(fibre * dissolve * 2, 0);
        half4 stroke = layer.sample(position + drift);
        stroke.rgb *= half(1 - .24 * wet);
        float cohesion = 1 - smoothstep(.12 + .18 * cloud, .62 + .18 * grain, p);
        half4 feather = pigmentPool(layer, position + drift, spread);
        float residue = smoothstep(.10, .40, p) * (1 - smoothstep(.50, 1.0, p));
        half4 result = stroke * half(cohesion) + feather * half(residue * (.28 + .25 * fibre));
        // Keep premultiplied colour valid as the pools overlap.
        if (result.a > 1) result /= result.a;
        return result;
    }

    // A stain is broad and dilute, wicks as small dark points along the grain,
    // then contracts into warped strokes before the exact type dries in place.
    float gather = smoothstep(.23, .82, p);
    float radius = mix(7.5, .35, gather);
    float2 wetPosition = position + wander * (1 - gather) * 5.0;
    half4 pool = pigmentPool(layer, wetPosition, radius);
    half4 smallPool = pigmentPool(layer, wetPosition, radius * .34);
    // The paper answers immediately, before an individual sentence or drawing
    // starts finding its strokes. Stagger belongs to gathering, not to a blank
    // leaf waiting for every content clock to wake up.
    float stain = smoothstep(0.0, .06, progress) * (1 - smoothstep(.45, .92, p));
    float wick = smoothstep(.08 + cloud * .10, .38 + grain * .15, p);
    float points = smoothstep(.34, .86, grain + fibre * .18);
    float wetMarks = wick * (1 - smoothstep(.50, .89, p));
    half4 haze = pool * half(stain * (.20 + cloud * .14));
    half4 fibres = smallPool * half(wetMarks * (.18 + points * .50));
    half4 stroke = layer.sample(wetPosition + float2(fibre - .5, 0) * (1 - gather) * 1.8);
    float cohesion = smoothstep(.28 + cloud * .18, .86, p);
    half4 forming = stroke * half(cohesion) + haze + fibres;
    if (forming.a > 1) forming /= forming.a;
    // This blend is only the final drying, after displaced pigment has already
    // become recognisable. The live unfiltered view takes over at the endpoint.
    return mix(forming, layer.sample(position), half(smoothstep(.82, 1.0, p)));
}
