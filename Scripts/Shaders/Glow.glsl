extern vec3 glow_color;
extern float glow_intensity;
extern float threshold;
extern vec2 tex_size;

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) {
    vec4 pixel = Texel(tex, tex_coords);
    
    vec2 size = 1.0 / tex_size;
    
    vec4 left = Texel(tex, tex_coords - vec2(size.x, 0));
    vec4 right = Texel(tex, tex_coords + vec2(size.x, 0));
    vec4 up = Texel(tex, tex_coords - vec2(0, size.y));
    vec4 down = Texel(tex, tex_coords + vec2(0, size.y));
    
    float lum_center = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    float lum_left = dot(left.rgb, vec3(0.299, 0.587, 0.114));
    float lum_right = dot(right.rgb, vec3(0.299, 0.587, 0.114));
    float lum_up = dot(up.rgb, vec3(0.299, 0.587, 0.114));
    float lum_down = dot(down.rgb, vec3(0.299, 0.587, 0.114));
    
    float edge = abs(lum_left - lum_center) + abs(lum_right - lum_center) +
                 abs(lum_up - lum_center) + abs(lum_down - lum_center);
    
    edge = smoothstep(threshold, threshold + 0.2, edge);
    
    vec3 glow = glow_color * edge * glow_intensity;
    vec3 result = pixel.rgb + glow;
    
    return vec4(result, pixel.a * color.a);
}