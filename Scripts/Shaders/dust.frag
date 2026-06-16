uniform number dt;
uniform number scan_y;
uniform vec2 screen_size_inv;
uniform vec2 scale_factor;  // 新增：缩放因子
extern vec4 sColor;

number noise(vec2 p, number s) {
    return fract(sin(s * dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    if (texture_coords.y < scan_y) {
        number n = noise(texture_coords, dt) * 2.0 - 1.0;
        // 考虑缩放因子
        vec2 adjusted_offset = vec2(asin(n)*10.0, 60.0*dt) * screen_size_inv / scale_factor;
        vec4 texcolor = Texel(texture, texture_coords + adjusted_offset);
        texcolor.a -= 0.125 * dt;
        if (texture_coords.y < scan_y - 8.0 * screen_size_inv.y / scale_factor.y) {
            texcolor.a = 0;
        }
        return texcolor * sColor;
    }
    vec4 texcolor = Texel(texture, texture_coords);
    return texcolor * sColor;
}