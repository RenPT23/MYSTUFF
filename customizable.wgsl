// ═══════════════════════════════════════════════════════════════════════
// OmniShader WGSL
// Extremely configurable general-purpose post-processing shader
// WebGPU / WGSL
// ═══════════════════════════════════════════════════════════════════════
//
// Expected input:
//   @group(0) @binding(0) -> source texture
//   @group(0) @binding(1) -> sampler
//   @group(0) @binding(2) -> Uniforms
//
// Fullscreen triangle:
//   vertex_index 0 -> (-1,-1)
//   vertex_index 1 -> ( 3,-1)
//   vertex_index 2 -> (-1, 3)
// ═══════════════════════════════════════════════════════════════════════

struct Uniforms {
    // ─────────────────────────────────────────────────────────────────
    // Resolution / time
    // ─────────────────────────────────────────────────────────────────

    resolution       : vec2<f32>,
    time             : f32,
    delta_time       : f32,

    // ─────────────────────────────────────────────────────────────────
    // UV transform
    // ─────────────────────────────────────────────────────────────────

    uv_scale         : vec2<f32>,
    uv_offset        : vec2<f32>,
    uv_rotation      : f32,

    // ─────────────────────────────────────────────────────────────────
    // Basic color
    // ─────────────────────────────────────────────────────────────────

    exposure         : f32,
    contrast         : f32,
    brightness       : f32,
    saturation       : f32,
    gamma            : f32,
    hue              : f32,

    // ─────────────────────────────────────────────────────────────────
    // Color channels
    // ─────────────────────────────────────────────────────────────────

    red              : f32,
    green            : f32,
    blue             : f32,

    // ─────────────────────────────────────────────────────────────────
    // Advanced color
    // ─────────────────────────────────────────────────────────────────

    temperature      : f32,
    tint             : f32,
    shadows          : f32,
    highlights       : f32,

    // ─────────────────────────────────────────────────────────────────
    // Vignette
    // ─────────────────────────────────────────────────────────────────

    vignette_strength : f32,
    vignette_radius   : f32,
    vignette_softness : f32,

    // ─────────────────────────────────────────────────────────────────
    // Chromatic aberration
    // ─────────────────────────────────────────────────────────────────

    chromatic_amount : f32,
    chromatic_angle  : f32,

    // ─────────────────────────────────────────────────────────────────
    // Distortion
    // ─────────────────────────────────────────────────────────────────

    distortion       : f32,
    distortion2      : f32,

    // ─────────────────────────────────────────────────────────────────
    // Pixelation
    // ─────────────────────────────────────────────────────────────────

    pixel_size       : f32,

    // ─────────────────────────────────────────────────────────────────
    // Sharpen / blur
    // ─────────────────────────────────────────────────────────────────

    sharpen          : f32,
    blur             : f32,

    // ─────────────────────────────────────────────────────────────────
    // Posterization
    // ─────────────────────────────────────────────────────────────────

    posterize_levels : f32,

    // ─────────────────────────────────────────────────────────────────
    // Scanlines
    // ─────────────────────────────────────────────────────────────────

    scanline_strength : f32,
    scanline_frequency : f32,

    // ─────────────────────────────────────────────────────────────────
    // Film grain
    // ─────────────────────────────────────────────────────────────────

    grain_strength   : f32,
    grain_scale      : f32,

    // ─────────────────────────────────────────────────────────────────
    // Dithering
    // ─────────────────────────────────────────────────────────────────

    dither_strength  : f32,

    // ─────────────────────────────────────────────────────────────────
    // RGB split
    // ─────────────────────────────────────────────────────────────────

    rgb_split        : f32,

    // ─────────────────────────────────────────────────────────────────
    // Inversion
    // ─────────────────────────────────────────────────────────────────

    invert           : f32,

    // ─────────────────────────────────────────────────────────────────
    // Edge glow
    // ─────────────────────────────────────────────────────────────────

    edge_glow        : f32,
    edge_threshold   : f32,

    // ─────────────────────────────────────────────────────────────────
    // Additional controls
    // ─────────────────────────────────────────────────────────────────

    opacity          : f32,
    monochrome       : f32,
    sepia            : f32,
    posterize_mix    : f32,

    // Prevent uniform alignment/padding issues.
    _padding         : vec2<f32>,
};

@group(0) @binding(0)
var source_texture : texture_2d<f32>;

@group(0) @binding(1)
var source_sampler : sampler;

@group(0) @binding(2)
var<uniform> u : Uniforms;


// ═══════════════════════════════════════════════════════════════════════
// Fullscreen triangle
// ═══════════════════════════════════════════════════════════════════════

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) uv : vec2<f32>,
};

@vertex
fn vs_main(
    @builtin(vertex_index) vertex_index : u32
) -> VertexOutput {

    var positions = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 3.0, -1.0),
        vec2<f32>(-1.0,  3.0)
    );

    var uvs = array<vec2<f32>, 3>(
        vec2<f32>(0.0, 0.0),
        vec2<f32>(2.0, 0.0),
        vec2<f32>(0.0, 2.0)
    );

    var out : VertexOutput;

    out.position = vec4<f32>(
        positions[vertex_index],
        0.0,
        1.0
    );

    out.uv = uvs[vertex_index];

    return out;
}


// ═══════════════════════════════════════════════════════════════════════
// Utility functions
// ═══════════════════════════════════════════════════════════════════════

fn saturate(x : f32) -> f32 {
    return clamp(x, 0.0, 1.0);
}


fn hash12(p : vec2<f32>) -> f32 {
    var p3 = fract(vec3<f32>(
        p.xyx * 0.1031
    ));

    p3 += dot(p3, p3.yzx + 33.33);

    return fract(
        (p3.x + p3.y) * p3.z
    );
}


fn random_noise(p : vec2<f32>) -> f32 {
    return hash12(
        p + vec2<f32>(u.time * 13.17, u.time * 7.31)
    );
}


fn rgb_to_luma(c : vec3<f32>) -> f32 {
    return dot(
        c,
        vec3<f32>(
            0.2126,
            0.7152,
            0.0722
        )
    );
}


fn hue_rotate(
    color : vec3<f32>,
    amount : f32
) -> vec3<f32> {

    let angle = amount * 6.28318530718;

    let c = cos(angle);
    let s = sin(angle);

    let w = vec3<f32>(
        0.299,
        0.587,
        0.114
    );

    let m = mat3x3<f32>(
        w.x + c * (1.0 - w.x) + s * -w.x,
        w.x + c * -w.x       + s *  0.143,
        w.x + c * -w.x       + s * -(1.0 - w.x),

        w.y + c * -w.y       + s * -w.y,
        w.y + c * (1.0 - w.y) + s *  0.140,
        w.y + c * -w.y       + s *  0.283,

        w.z + c * -w.z       + s * (1.0 - w.z),
        w.z + c * -w.z       + s * -w.z,
        w.z + c * (1.0 - w.z) + s * w.z
    );

    return m * color;
}


// ═══════════════════════════════════════════════════════════════════════
// UV transformation
// ═══════════════════════════════════════════════════════════════════════

fn transform_uv(uv : vec2<f32>) -> vec2<f32> {

    var p = uv - 0.5;

    // Scale
    p /= max(u.uv_scale, vec2<f32>(0.00001));

    // Rotation
    let c = cos(u.uv_rotation);
    let s = sin(u.uv_rotation);

    p = mat2x2<f32>(
        c, -s,
        s,  c
    ) * p;

    p += 0.5;

    p += u.uv_offset;

    return p;
}


// ═══════════════════════════════════════════════════════════════════════
// Barrel / pincushion distortion
// ═══════════════════════════════════════════════════════════════════════

fn distort_uv(uv : vec2<f32>) -> vec2<f32> {

    var p = uv - 0.5;

    let r2 = dot(p, p);

    p *=
        1.0 +
        u.distortion * r2 +
        u.distortion2 * r2 * r2;

    return p + 0.5;
}


// ═══════════════════════════════════════════════════════════════════════
// Pixelation
// ═══════════════════════════════════════════════════════════════════════

fn pixelate(uv : vec2<f32>) -> vec2<f32> {

    if (u.pixel_size <= 1.0) {
        return uv;
    }

    let size = vec2<f32>(
        u.pixel_size,
        u.pixel_size
    ) / u.resolution;

    return floor(uv / size) * size + size * 0.5;
}


// ═══════════════════════════════════════════════════════════════════════
// Basic sampling
// ═══════════════════════════════════════════════════════════════════════

fn sample_source(uv : vec2<f32>) -> vec4<f32> {
    return textureSample(
        source_texture,
        source_sampler,
        uv
    );
}


// ═══════════════════════════════════════════════════════════════════════
// Blur
// ═══════════════════════════════════════════════════════════════════════

fn blur_sample(
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.blur <= 0.001) {
        return sample_source(uv).rgb;
    }

    let texel =
        1.0 / u.resolution *
        u.blur;

    var color = vec3<f32>(0.0);

    color += sample_source(
        uv + vec2<f32>(-2.0, -2.0) * texel
    ).rgb;

    color += sample_source(
        uv + vec2<f32>( 0.0, -2.0) * texel
    ).rgb;

    color += sample_source(
        uv + vec2<f32>( 2.0, -2.0) * texel
    ).rgb;

    color += sample_source(
        uv + vec2<f32>(-2.0,  0.0) * texel
    ).rgb;

    color += sample_source(
        uv
    ).rgb * 2.0;

    color += sample_source(
        uv + vec2<f32>( 2.0,  0.0) * texel
    ).rgb;

    color += sample_source(
        uv + vec2<f32>(-2.0,  2.0) * texel
    ).rgb;

    color += sample_source(
        uv + vec2<f32>( 0.0,  2.0) * texel
    ).rgb;

    color += sample_source(
        uv + vec2<f32>( 2.0,  2.0) * texel
    ).rgb;

    return color / 10.0;
}


// ═══════════════════════════════════════════════════════════════════════
// Sharpen
// ═══════════════════════════════════════════════════════════════════════

fn sharpen_sample(
    uv : vec2<f32>,
    original : vec3<f32>
) -> vec3<f32> {

    if (u.sharpen <= 0.001) {
        return original;
    }

    let texel = 1.0 / u.resolution;

    let surrounding =
        sample_source(uv + vec2<f32>( texel.x, 0.0)).rgb +
        sample_source(uv + vec2<f32>(-texel.x, 0.0)).rgb +
        sample_source(uv + vec2<f32>(0.0,  texel.y)).rgb +
        sample_source(uv + vec2<f32>(0.0, -texel.y)).rgb;

    let blurred = surrounding * 0.25;

    return original +
        (original - blurred) * u.sharpen;
}


// ═══════════════════════════════════════════════════════════════════════
// Chromatic aberration
// ═══════════════════════════════════════════════════════════════════════

fn chromatic_sample(
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.chromatic_amount <= 0.001) {
        return sample_source(uv).rgb;
    }

    let direction = vec2<f32>(
        cos(u.chromatic_angle),
        sin(u.chromatic_angle)
    );

    let offset =
        direction *
        u.chromatic_amount /
        u.resolution;

    let r = sample_source(
        uv + offset
    ).r;

    let g = sample_source(
        uv
    ).g;

    let b = sample_source(
        uv - offset
    ).b;

    return vec3<f32>(
        r,
        g,
        b
    );
}


// ═══════════════════════════════════════════════════════════════════════
// RGB split
// ═══════════════════════════════════════════════════════════════════════

fn rgb_split_sample(
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.rgb_split <= 0.001) {
        return sample_source(uv).rgb;
    }

    let offset =
        vec2<f32>(
            u.rgb_split / u.resolution.x,
            0.0
        );

    return vec3<f32>(
        sample_source(uv + offset).r,
        sample_source(uv).g,
        sample_source(uv - offset).b
    );
}


// ═══════════════════════════════════════════════════════════════════════
// Color processing
// ═══════════════════════════════════════════════════════════════════════

fn process_color(
    input : vec3<f32>
) -> vec3<f32> {

    var color = input;

    // Exposure
    color *= pow(
        2.0,
        u.exposure
    );

    // Brightness
    color += u.brightness;

    // Contrast
    color = (
        color - 0.5
    ) * u.contrast + 0.5;

    // Saturation
    let luma = rgb_to_luma(color);

    color = mix(
        vec3<f32>(luma),
        color,
        u.saturation
    );

    // Temperature
    color.r += u.temperature * 0.1;
    color.b -= u.temperature * 0.1;

    // Tint
    color.g += u.tint * 0.1;

    // Channel multipliers
    color *= vec3<f32>(
        u.red,
        u.green,
        u.blue
    );

    // Hue
    color = hue_rotate(
        color,
        u.hue
    );

    // Shadows
    let shadow_mask =
        1.0 - smoothstep(
            0.0,
            0.5,
            luma
        );

    color +=
        u.shadows *
        shadow_mask;

    // Highlights
    let highlight_mask =
        smoothstep(
            0.5,
            1.0,
            luma
        );

    color +=
        u.highlights *
        highlight_mask;

    // Gamma
    color = pow(
        max(color, vec3<f32>(0.0)),
        vec3<f32>(
            1.0 / max(u.gamma, 0.001)
        )
    );

    // Monochrome
    color = mix(
        color,
        vec3<f32>(
            rgb_to_luma(color)
        ),
        u.monochrome
    );

    // Sepia
    let sepia_color = vec3<f32>(
        dot(color, vec3<f32>(0.393, 0.769, 0.189)),
        dot(color, vec3<f32>(0.349, 0.686, 0.168)),
        dot(color, vec3<f32>(0.272, 0.534, 0.131))
    );

    color = mix(
        color,
        sepia_color,
        u.sepia
    );

    // Posterization
    if (u.posterize_levels > 1.0) {

        let levels =
            max(u.posterize_levels, 2.0);

        let posterized =
            floor(
                color * levels
            ) / (levels - 1.0);

        color = mix(
            color,
            posterized,
            u.posterize_mix
        );
    }

    // Invert
    color = mix(
        color,
        vec3<f32>(1.0) - color,
        u.invert
    );

    return color;
}


// ═══════════════════════════════════════════════════════════════════════
// Vignette
// ═══════════════════════════════════════════════════════════════════════

fn apply_vignette(
    color : vec3<f32>,
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.vignette_strength <= 0.001) {
        return color;
    }

    let p = uv - 0.5;

    let distance =
        length(p) * 1.41421356;

    let vignette =
        smoothstep(
            u.vignette_radius,
            u.vignette_radius -
                max(u.vignette_softness, 0.001),
            distance
        );

    return color *
        mix(
            1.0 - u.vignette_strength,
            1.0,
            vignette
        );
}


// ═══════════════════════════════════════════════════════════════════════
// Scanlines
// ═══════════════════════════════════════════════════════════════════════

fn apply_scanlines(
    color : vec3<f32>,
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.scanline_strength <= 0.001) {
        return color;
    }

    let line =
        sin(
            uv.y *
            u.resolution.y *
            u.scanline_frequency
        );

    let factor =
        1.0 -
        (line * 0.5 + 0.5) *
        u.scanline_strength;

    return color * factor;
}


// ═══════════════════════════════════════════════════════════════════════
// Grain
// ═══════════════════════════════════════════════════════════════════════

fn apply_grain(
    color : vec3<f32>,
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.grain_strength <= 0.001) {
        return color;
    }

    let noise = random_noise(
        uv *
        u.resolution /
        max(u.grain_scale, 1.0)
    );

    let grain =
        noise * 2.0 - 1.0;

    return color +
        grain * u.grain_strength;
}


// ═══════════════════════════════════════════════════════════════════════
// Dithering
// ═══════════════════════════════════════════════════════════════════════

fn apply_dither(
    color : vec3<f32>,
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.dither_strength <= 0.001) {
        return color;
    }

    let matrix = array<f32, 16>(
         0.0,  8.0,  2.0, 10.0,
        12.0,  4.0, 14.0,  6.0,
         3.0, 11.0,  1.0,  9.0,
        15.0,  7.0, 13.0,  5.0
    );

    let x =
        u32(
            floor(
                uv.x * u.resolution.x
            )
        ) & 3u;

    let y =
        u32(
            floor(
                uv.y * u.resolution.y
            )
        ) & 3u;

    let index = y * 4u + x;

    let threshold =
        matrix[index] / 16.0 - 0.5;

    return color +
        threshold *
        u.dither_strength /
        255.0;
}


// ═══════════════════════════════════════════════════════════════════════
// Edge glow
// ═══════════════════════════════════════════════════════════════════════

fn apply_edge_glow(
    color : vec3<f32>,
    uv : vec2<f32>
) -> vec3<f32> {

    if (u.edge_glow <= 0.001) {
        return color;
    }

    let texel =
        1.0 / u.resolution;

    let c = rgb_to_luma(
        sample_source(uv).rgb
    );

    let l = rgb_to_luma(
        sample_source(
            uv - vec2<f32>(texel.x, 0.0)
        ).rgb
    );

    let r = rgb_to_luma(
        sample_source(
            uv + vec2<f32>(texel.x, 0.0)
        ).rgb
    );

    let t = rgb_to_luma(
        sample_source(
            uv - vec2<f32>(0.0, texel.y)
        ).rgb
    );

    let b = rgb_to_luma(
        sample_source(
            uv + vec2<f32>(0.0, texel.y)
        ).rgb
    );

    let edge = abs(c - l) +
               abs(c - r) +
               abs(c - t) +
               abs(c - b);

    let mask =
        smoothstep(
            u.edge_threshold,
            1.0,
            edge
        );

    return color +
        vec3<f32>(mask * u.edge_glow);
}


// ═══════════════════════════════════════════════════════════════════════
// Main fragment shader
// ═══════════════════════════════════════════════════════════════════════

@fragment
fn fs_main(
    input : VertexOutput
) -> @location(0) vec4<f32> {

    var uv = input.uv;

    // UV transform
    uv = transform_uv(uv);

    // Lens distortion
    uv = distort_uv(uv);

    // Pixelation
    uv = pixelate(uv);

    // Clamp for safety
    uv = clamp(
        uv,
        vec2<f32>(0.0),
        vec2<f32>(1.0)
    );

    // Base sampling
    var color =
        chromatic_sample(uv);

    // RGB split
    color = mix(
        color,
        rgb_split_sample(uv),
        saturate(u.rgb_split)
    );

    // Blur
    let blurred =
        blur_sample(uv);

    color = mix(
        color,
        blurred,
        saturate(u.blur * 0.15)
    );

    // Sharpen
    color =
        sharpen_sample(
            uv,
            color
        );

    // Color pipeline
    color =
        process_color(color);

    // Edge glow
    color =
        apply_edge_glow(
            color,
            uv
        );

    // Scanlines
    color =
        apply_scanlines(
            color,
            uv
        );

    // Film grain
    color =
        apply_grain(
            color,
            uv
        );

    // Dither
    color =
        apply_dither(
            color,
            uv
        );

    // Vignette
    color =
        apply_vignette(
            color,
            uv
        );

    // Final opacity
    let original =
        sample_source(input.uv).rgb;

    color = mix(
        original,
        color,
        saturate(u.opacity)
    );

    return vec4<f32>(
        saturate(color),
        1.0
    );
}
