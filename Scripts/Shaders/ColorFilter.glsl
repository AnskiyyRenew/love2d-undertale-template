extern float grayscale;
extern vec3 tint_color;

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) {
    vec4 pixel = Texel(tex, tex_coords);

    float lum = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray = vec3(lum);
    vec3 result = mix(pixel.rgb, gray, grayscale);

    result = result * tint_color;
    
    return vec4(result, pixel.a * color.a);
}