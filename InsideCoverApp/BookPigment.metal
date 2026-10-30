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

// A rotated two-ring pool. The rotation follows paper noise, so the ring's
// eight-point pattern becomes fibre grain instead of a star around each mark.
static half4 inkPool(SwiftUI::Layer layer, float2 p, float radius, float spin) {
    float2x2 turn = float2x2(cos(spin), sin(spin), -sin(spin), cos(spin));
    half4 pool = layer.sample(p) * half(0.20);
    constexpr float2 inner[] = {float2(1, 0), float2(-1, 0), float2(0, 1), float2(0, -1)};
    constexpr float2 outer[] = {float2(.92, .38), float2(-.38, .92), float2(-.92, -.38), float2(.38, -.92),
                              float2(.38, .92), float2(-.92, .38), float2(-.38, -.92), float2(.92, -.38)};
    for (int i = 0; i < 4; ++i) {
        pool += layer.sample(p + turn * inner[i] * radius * .5) * half(0.10);
    }
    for (int i = 0; i < 8; ++i) {
        pool += layer.sample(p + turn * outer[i] * radius) * half(0.05);
    }
    return pool;
}

// Every colour sample comes from the actual rendered marks, including the
// accent word and coloured artwork. No rectangular fade or replacement ink.
//
// The sentence clock (UIKit prose only) is two maps stacked in one texture,
// each spanning the padded layer: the top half holds each sentence's start band in three binary channels, the
// bottom half holds where each pixel falls in its sentence's reading order
// (0.1 at its first letter, 1.0 at its last, black for paper) in red, beside
// the label's blurred ink in green, the puddle's surface. Two final rows
// are mid-grey so the order can be decoded whatever colour space the image
// was converted through.
[[ stitchable ]] half4 bookPigment(float2 position, SwiftUI::Layer layer,
                                  float4 bounds, float progress, float sinking,
                                  float seed, float regionDelaySpan, float regionDuration, float objectDelay,
                                  float picture, texture2d<half> sentenceClock) {
    if (progress <= 0) return sinking > .5 ? layer.sample(position) : half4(0);
    if (progress >= 1) return sinking > .5 ? half4(0) : layer.sample(position);

    constexpr sampler mapSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float2 size = max(bounds.zw - 24, float2(1));
    float2 local = position - bounds.xy - 12;
    float2 uv = local / size;
    float cloud = pigmentNoise(position / 19.0, seed);
    float grain = pigmentHash(floor(position * 1.7), seed + 4);
    float fibre = .5 + .5 * sin(position.y * 2.6 + pigmentNoise(position / 7.0, seed + 2) * 8.0);
    float2 wander = float2(pigmentNoise(position / 11.0, seed + 7),
                          pigmentNoise(position / 9.0, seed + 13)) * 2 - 1;

    if (sinking > .5) {
        float p = progress;
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

    // Where the travelling ink reaches this pixel: reading order along the
    // pixel's own sentence for prose, a left-to-right stroke for a line of
    // type, top-left to bottom-right for a few lines of handwriting, and an
    // outward seep from one wet point for any picture.
    float sentenceDelay = 0;
    float order = 2;
    float field = -1;
    float2 flow = float2(1, 0);
    if (regionDelaySpan > 0) {
        float rows = float(sentenceClock.get_height());
        float half_ = max(1.0, (rows - 2) * .5);
        float reference = float(sentenceClock.sample(mapSampler, float2(.5, (rows - .5) / rows)).r);
        float gamma = log(clamp(reference, .02, .98)) / log(.5);
        constexpr sampler fieldSampler(coord::normalized, address::clamp_to_edge, filter::linear);
        float2 padded = bounds.zw;
        float2 mapped = position - bounds.xy;
        float2 own = clamp(mapped / padded, float2(0), float2(.9999));
        field = pow(float(sentenceClock.sample(fieldSampler, float2(own.x, (half_ + own.y * half_) / rows)).g), 1 / gamma);
        // Ink spills a little past a sentence's line box; that paper borrows
        // the nearest sentence's clock instead of drying on its own. Along
        // the line first: past a line's end, the line below may belong to a
        // sentence that has already dried, and borrowing it cut puddles flat.
        constexpr float2 reach[] = {float2(0), float2(-9, 0), float2(9, 0), float2(0, -7), float2(0, 7)};
        for (int i = 0; i < 5; ++i) {
            float2 q = clamp((mapped + reach[i]) / padded, float2(0), float2(.9999));
            float coded = pow(float(sentenceClock.sample(mapSampler, float2(q.x, (half_ + q.y * half_) / rows)).r), 1 / gamma);
            if (coded > .05) {
                order = saturate((coded - .1) / .9);
                float3 clockBits = step(float3(.5), float3(sentenceClock.sample(mapSampler, float2(q.x, q.y * half_ / rows)).rgb));
                sentenceDelay = dot(clockBits, float3(1, 2, 4)) / 7 * regionDelaySpan;
                break;
            }
        }
    } else {
        float aspect = size.x / size.y;
        float warp = (pigmentNoise(position / 23.0, seed + 31) - .5) * .16;
        if (picture > .5) {
            float2 source = float2(.32 + .36 * pigmentHash(float2(3, 7), seed),
                                   .34 + .32 * pigmentHash(float2(5, 11), seed));
            float2 shape = float2(aspect, 1);
            float far = max(max(length(source * shape), length((float2(1, 0) - source) * shape)),
                            max(length((float2(0, 1) - source) * shape), length((float2(1) - source) * shape)));
            float2 away = (uv - source) * shape;
            flow = away / max(length(away), 1e-3);
            order = saturate(length(away) / far + warp);
        } else if (aspect > 1.6) {
            order = saturate(uv.x * .9 + uv.y * .1 + warp);
        } else {
            order = saturate(uv.x * .6 + uv.y * .4 + warp);
        }
    }

    float delay = objectDelay + sentenceDelay + .02 * cloud;
    // Later sentences keep their full wet phase and finish later. Compressing
    // by (1 - delay) made every sentence dry together on the old leaf clock.
    float p = saturate((progress - delay) / regionDuration);
    // The final blend already returns the exact source at p == 1. A region
    // that has dried needs no pool, even while later sentences still write.
    if (p >= 1) return layer.sample(position);

    // The front crosses its region by p = .6, leaving every mark at least a
    // quarter of its phase to condense and dry before the live view returns.
    float front = -.12 + (p - .04) * 2.0;
    float reached = front - order;
    float rise = smoothstep(-.06, 0.0, reached);
    float gather = smoothstep(.02, .22, reached);
    float wet = rise * (1 - smoothstep(.30, .80, reached));
    float radius = mix(7.0, .35, gather);
    float2 wetPosition = position + wander * (1 - gather) * 4.0;
    // The ring turns slowly across the leaf: fast turning carved marbled
    // swirls into the puddle's surface.
    // A per-pixel jitter smears the taps' copies of each mark into grain.
    // Pictures are continuous tone; their copies hardly show, so they keep
    // only a little of the jitter that would otherwise speckle a photo.
    float jitter = pigmentHash(floor(position * 2.0), seed + 23) * (picture > .5 ? .3 : 1.0);
    half4 pool = inkPool(layer, wetPosition, radius * (.8 + .4 * jitter),
                         pigmentNoise(position / 41.0, seed + 19) * 6.2832 + jitter * 1.1);

    // Ahead of the ink: the paper darkens faintly from the first frame (too
    // faint to read the words through), then wicks forward in fibre points.
    // Both fade slowly behind the front: dropping them as it passed opened a
    // crisp clean window in the paper around the puddle.
    float stain = smoothstep(0.0, .06, progress) * (1 - smoothstep(-.05, .45, reached)) * (1 - smoothstep(.45, .92, p));
    float wick = smoothstep(-.24 + cloud * .06, -.03, reached) * (1 - smoothstep(-.02, .25, reached));
    // Prose has its puddle field instead: a wick pooled across the lines
    // left faint streaks along the seams between them.
    if (field >= 0) wick = 0;
    float points = smoothstep(.34, .86, grain + fibre * .18);
    half4 haze = pool * half(stain * (.05 + cloud * .06) + wick * (.08 + points * .40));

    // At the front: a liquid puddle. A threshold on the pooled ink lets
    // neighbouring letters run together as one surface; raising it pulls the
    // puddle back into the letters' cores. Prose brings a smooth blurred
    // field; other marks fall back to the narrowing pool. Pigment gathers at
    // the drying edge, so a puddle's rim reads darker than its middle.
    float coverage = field >= 0 ? field : float(pool.a);
    if (field < 0 && picture < .5 && size.x / size.y > 1.6) {
        // A line of type has no field: a smooth bead rides just behind its
        // front and lets the pooled letters run into it.
        float behind = (reached - .04) * size.x / .9;
        float across = (uv.y - .5) * size.y;
        float bead = exp(-behind * behind / 196.0 - across * across / (size.y * size.y * .2))
                   * (.75 + .5 * pigmentNoise(position / 9.0, seed + 41))
                   * smoothstep(-8.0, 0.0, local.x) * smoothstep(size.x + 8.0, size.x, local.x);
        coverage = max(coverage * .8, bead * .3 * (1 - gather));
    }
    float threshold = field >= 0 ? mix(.06, .30, gather) : mix(.05, .5, gather);
    float body = smoothstep(threshold - .06, threshold + .10, coverage);
    float rim = 1 - smoothstep(threshold + .04, threshold + .30, coverage);
    // Pigment colour is the pooled marks' own; where the pool is nearly
    // empty it stays dark instead of dividing up into pale noise.
    half3 pigment = min(pool.rgb / max(pool.a, half(.06)), half3(1));
    half4 stroke = layer.sample(wetPosition + float2(fibre - .5, 0) * (1 - gather) * 1.6);
    if (picture > .5) {
        // A picture's ink is its own colours. Wet pigment is deeper and more
        // saturated, never blacker, and its dyes separate as they run: red
        // travels furthest from the wet point, blue least, so the puddle's
        // edge carries a soft fringe of the picture's colours. Only the
        // puddle separates; split strokes read as a glitch, not as ink.
        float carry = wet * (1 - gather) * 3.5;
        half4 farther = layer.sample(wetPosition - flow * carry * 1.6);
        half4 nearer = layer.sample(wetPosition - flow * carry * .6);
        half3 farInk = min(farther.rgb / max(farther.a, half(.06)), half3(1));
        half3 nearInk = min(nearer.rgb / max(nearer.a, half(.06)), half3(1));
        pigment = half3(mix(pigment.r, farInk.r, half(.45)), mix(pigment.g, nearInk.g, half(.45)), pigment.b);
        half lightness = dot(pigment, half3(.299, .587, .114));
        pigment = clamp(mix(half3(lightness), pigment, half(1 + .55 * wet)), half3(0), half3(1)) * half(1 - .10 * wet);
        half strokeLightness = dot(stroke.rgb, half3(.299, .587, .114));
        stroke.rgb = clamp(mix(half3(strokeLightness), stroke.rgb, half(1 + .35 * wet)), half3(0), half3(stroke.a));
    } else {
        pigment *= half(1 - .30 * wet);
        stroke.rgb *= half(1 - .22 * wet);
    }
    float depth = body * rise * (.66 + .34 * rim);
    half4 puddle = half4(pigment * half(depth), half(depth));
    float cohesion = smoothstep(.12, .30, reached);
    half4 forming = mix(puddle, stroke, half(cohesion)) + haze * half(1 - cohesion);
    // Keep premultiplied colour valid as the pools overlap.
    if (forming.a > 1) forming /= forming.a;
    // The live unfiltered view takes over at the endpoint.
    return mix(forming, layer.sample(position), half(smoothstep(.84, 1.0, p)));
}
