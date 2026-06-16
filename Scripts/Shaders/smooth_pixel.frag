// edited from https://github.com/CptPotato/GodotThings/tree/master/SmoothPixelFiltering

extern vec2 texture_pixel_size;

vec4 texture_point_smooth(Image tex, vec2 uv, vec2 pixel_size) {
    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);
    vec2 lxy = max(sqrt(ddx * ddx + ddy * ddy), vec2(0.000001));
    vec2 uv_pixels = uv / pixel_size;
    vec2 uv_pixels_floor = floor(uv_pixels + 0.5) - vec2(0.5);
    vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;

    uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5)) * pixel_size / lxy + vec2(0.5), 0.0, 1.0);
    uv = uv_pixels_floor * pixel_size;

    return Texel(tex, uv + uv_dxy_pixels * pixel_size);
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    return color * texture_point_smooth(tex, texture_coords, texture_pixel_size);
}
