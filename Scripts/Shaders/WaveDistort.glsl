extern float time;
extern float amplitude;
extern float frequency;
extern float speed;
extern vec2 tex_size;

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) {
    vec2 pixel_coords = tex_coords * tex_size;
    
    float offset_x = sin(pixel_coords.y * frequency + time * speed) * amplitude * tex_size.x;
    float offset_y = sin(pixel_coords.x * frequency + time * speed * 0.8) * amplitude * tex_size.y;
    vec2 distorted_uv = tex_coords + vec2(offset_x / tex_size.x, offset_y / tex_size.y);
    distorted_uv = clamp(distorted_uv, 0.0, 1.0);
    
    vec4 pixel = Texel(tex, distorted_uv);
    return pixel * color;
}