#import bevy_pbr::mesh_view_bindings
#import bevy_pbr::mesh_bindings

#import bevy_pbr::pbr_types
#import bevy_pbr::utils
#import bevy_pbr::clustered_forward
#import bevy_pbr::lighting
#import bevy_pbr::shadows
#import bevy_pbr::pbr_functions

struct Material {
    sampling_mode: u32;
};

[[group(1), binding(0)]]
var<uniform> material: Material;
[[group(1), binding(1)]]
var base_color_texture: texture_2d<f32>;
[[group(1), binding(2)]]
var base_color_sampler: sampler;

struct FragmentInput {
    [[builtin(front_facing)]] is_front: bool;
    [[builtin(position)]] frag_coord: vec4<f32>;
    [[location(0)]] world_position: vec4<f32>;
    [[location(1)]] world_normal: vec3<f32>;
    [[location(2)]] uv: vec2<f32>;
#ifdef VERTEX_TANGENTS
    [[location(3)]] world_tangent: vec4<f32>;
#endif
#ifdef VERTEX_COLORS
    [[location(4)]] color: vec4<f32>;
#endif
};

//CC0 ported from https://www.shadertoy.com/view/ltfXWS

// Calculates the lengths of (a.x, b.x) and (a.y, b.y) at the same time
fn v2len(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return sqrt(a * a + b * b);
}

// Samples from a linearly-interpolated texture to produce an appearance similar to
// nearest-neighbor interpolation, but with resolution-dependent antialiasing
fn texture_blocky(tex: texture_2d<f32>, samp: sampler, uv: vec2<f32>) -> vec4<f32> {
    let tex_res = vec2<f32>(textureDimensions(base_color_texture));

    var uv = uv * tex_res; // enter texel coordinate space.
    
    let seam = floor(uv + 0.5); // find the nearest seam between texels.
    
    // scale up the distance to the seam so that all interpolation happens in a one-pixel-wide space.
    uv = (uv - seam) / v2len(dpdx(uv), dpdy(uv)) + seam;
    
    uv = clamp(uv, seam - 0.5, seam + 0.5); // clamp to the center of a texel.
    
    return textureSample(tex, samp, uv / tex_res); // convert back to 0..1 coordinate space.
}

// Simulates nearest-neighbor interpolation on a linearly-interpolated texture
fn texture_nearest(tex: texture_2d<f32>, samp: sampler, uv: vec2<f32>) -> vec4<f32> {
    let tex_res = vec2<f32>(textureDimensions(base_color_texture));
    return textureSample(tex, samp, (floor(uv * tex_res) + 0.5) / tex_res);
}

[[stage(fragment)]]
fn fragment(in: FragmentInput) -> [[location(0)]] vec4<f32> {
    
    var pbr_input: PbrInput;

    // Select sampling mode based on uniform parameter
    if (material.sampling_mode == 0u) {
        pbr_input.material.base_color = textureSample(base_color_texture, base_color_sampler, in.uv);
    } else if (material.sampling_mode == 1u) { 
        pbr_input.material.base_color = texture_nearest(base_color_texture, base_color_sampler, in.uv);
    } else if (material.sampling_mode == 2u) { 
        pbr_input.material.base_color = texture_blocky(base_color_texture, base_color_sampler, in.uv);
    }

    pbr_input.material.reflectance = 0.5;
    pbr_input.material.alpha_cutoff = 0.0;
    pbr_input.material.flags = 16u;
    pbr_input.material.emissive = vec4<f32>(0.0,0.0,0.0,1.0);
    pbr_input.material.metallic = 0.0;
    pbr_input.material.perceptual_roughness = 1.0;

    pbr_input.occlusion = 1.0;
    pbr_input.frag_coord = in.frag_coord;
    pbr_input.world_position = in.world_position;
    pbr_input.world_normal = in.world_normal;

    pbr_input.is_orthographic = view.projection[3].w == 1.0;

    pbr_input.N = prepare_normal(0u, in.world_normal, in.uv, in.is_front);
    pbr_input.V = calculate_view(in.world_position, pbr_input.is_orthographic);

    let output_color = pbr(pbr_input);

    return tone_mapping(pbr(pbr_input));

}