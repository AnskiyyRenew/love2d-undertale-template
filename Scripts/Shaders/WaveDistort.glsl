// Elapsed time in seconds; advances the wave phase.
extern float time;
// Peak displacement as a fraction of the texture size (0.06 = 6% of width on X, 6% of height on Y).
extern float amplitude;
// Phase per texture pixel; higher values give a tighter ripple.
extern float frequency;
// Wave speed in radians per second.
extern float speed;
// Texture size in pixels; converts UV to pixel coordinates so the ripple is even on X and Y.
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