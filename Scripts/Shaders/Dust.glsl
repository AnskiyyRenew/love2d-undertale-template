uniform number dt;
uniform number scan_y;
uniform vec2 screen_size_inv;
uniform vec2 scale_factor;

number noise(vec2 p, number s) {
    return fract(sin(s * dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    number edge = 1.0 * screen_size_inv.y / scale_factor.y;
    number top = 9.0 * screen_size_inv.y / scale_factor.y;

    if (texture_coords.y < scan_y - edge) {
        // Ramp: 0 at the scan edge -> 1 at the fade-out edge, so the vertical drop
        // is 0 at the boundary with the intact image below (no seam), and only
        // grows toward the top of the band as the dust tears away.
        number band = clamp((scan_y - edge - texture_coords.y) / (top - edge), 0.0, 1.0);
        number n = noise(texture_coords, dt) * 2.0 - 1.0;
        vec2 adjusted_offset = vec2(asin(n) * 7.0, band * 15.0 * dt) * screen_size_inv / scale_factor;
        vec4 texcolor = Texel(texture, texture_coords + adjusted_offset);
        texcolor.a -= 0.04;
        if (texture_coords.y < scan_y - top) {
            texcolor.a = 0;
        }
        return texcolor * color;
    }
    vec4 texcolor = Texel(texture, texture_coords);
    return texcolor * color;
}