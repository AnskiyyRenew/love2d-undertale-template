// Per-channel RGB offset (RGB split / chromatic aberration).
//
// Each channel is sampled from the same texture at its own offset, so red,
// green and blue no longer line up. Nothing else happens: no time-driven
// animation, no distortion, no extra tint. Offsets stay where Lua puts them
// until they are sent again.
//
//   local shader = ImportFile("RGBOffset", "shader")
//   shader:send("tex_size", {sprite.width, sprite.height})
//   shader:send("r_offset", { 2, 0})   -- red   moved 2px right
//   shader:send("g_offset", { 0, 0})   -- green stays put
//   shader:send("b_offset", {-2, 0})   -- blue  moved 2px left
//   sprite:SetShaders({shader})
//
// An offset moves the channel it belongs to: +x right, -x left, +y down,
// -y up. `tex_size` converts those pixel offsets into texture coordinates,
// so it has to match the size of the texture being drawn. Send {1, 1} to
// read the offsets as raw UV instead (0..1 across the whole texture).
// Leaving any uniform unset is harmless: the size falls back to 1 and the
// offsets to 0, which draws the texture unaltered.
//
// Every call to ImportFile builds a new shader object, and uniforms live on
// the object, so two sprites sharing one instance share its offsets. Create
// one instance per sprite when they need different values.

// Texture size in pixels; converts the pixel offsets below into UV. {1, 1} makes them raw UV.
extern vec2 tex_size;
// Red channel offset in pixels: +x right, -x left, +y down, -y up.
extern vec2 r_offset;
// Green channel offset in pixels, same axes as r_offset.
extern vec2 g_offset;
// Blue channel offset in pixels, same axes as r_offset.
extern vec2 b_offset;

// Sampled at an offset for one channel: the channel travels one way, so the
// lookup travels the other. A sample landing outside the texture counts as
// empty instead of repeating the edge pixel, which keeps a channel from
// smearing outward along the border of the sprite it belongs to.
vec4 sample_channel(Image tex, vec2 offset, vec2 texel, vec2 base) {
    vec2 uv = base - offset * texel;
    vec4 pixel = Texel(tex, clamp(uv, 0.0, 1.0));

    vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
    return pixel * inside.x * inside.y;
}

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords) {
    vec2 texel = 1.0 / max(tex_size, vec2(1.0));

    vec4 r = sample_channel(tex, r_offset, texel, tex_coords);
    vec4 g = sample_channel(tex, g_offset, texel, tex_coords);
    vec4 b = sample_channel(tex, b_offset, texel, tex_coords);

    // Alpha follows the three channels together, so the split grows the
    // silhouette to cover all three instead of clipping two of them.
    float alpha = max(max(r.a, g.a), b.a);
    return vec4(r.r, g.g, b.b, alpha) * color;
}
