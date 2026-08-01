extern vec4 topLeftColor;
extern vec4 topRightColor;
extern vec4 bottomLeftColor;
extern vec4 bottomRightColor;
extern float angle = 0.0;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords - 0.5;
    float rad = radians(angle);
    float c = cos(rad);
    float s = sin(rad);

    vec2 rotated = vec2(
        uv.x * c + uv.y * s,
        -uv.x * s + uv.y * c
    );
    rotated += 0.5;
    rotated = clamp(rotated, 0.0, 1.0);

    vec4 topColor = mix(topLeftColor, topRightColor, rotated.x);
    vec4 bottomColor = mix(bottomLeftColor, bottomRightColor, rotated.x);
    vec4 finalColor = mix(topColor, bottomColor, rotated.y);

    return finalColor * color;
}
