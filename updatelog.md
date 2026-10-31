# Update Log

> Changes since tag `v3.0.1-stable` (`56b162d`) — to be used as the release note for the next build.

## New Features
- Added stencil (mask) and shader support to all four typer modules, sharing one implementation in `Scripts/Libraries/Typers/render.lua`: `typer:SetStencils({mask})`, `typer:SetShaders({shader})`, `GetStencils` / `GetShaders`, `ClearStencils` / `ClearShaders` and `AddShader` / `RemoveShader` — the same calls a sprite takes. Both are optional and cost nothing while unset: the draw path behaves exactly as before until something is applied
- The typer shader pass bakes the text block into an offscreen canvas sized to its bounding box before running the chain. Every glyph is drawn from a font atlas, so a shader reading `tex_coords` would otherwise see atlas-relative UVs instead of 0..1 across the glyph (`WaveDistort` mapped them through `tex_size` and `Gradiant` lerped across the axis — both sampled the wrong texels). Shaders written for sprites now behave identically on text, glyphs keep their exact positions, and masks stack on top: the shader runs first, then the baked canvas is blitted through the mask. Canvases are cached and rounded up to 32px steps (up to 12 sizes), so text that grows while typing reuses one surface instead of allocating per frame
- Added an `immediate` argument to `timers.runFrame(func, interval, count, immediate)` and `timers.runSecond(...)`: when true, `func` fires once at creation and counts toward `count`, before the normal interval takes over — `runFrame(func, 60, 3, true)` fires immediately, then on frame 60 and frame 120
- Added `Scripts/Scenes/TEST/scene_typerfx.lua`, a visual check for the typer mask / shader support: a baseline block, mask-only, shader-only, both combined, and an animated `Wave` shader over an `EText`. Enable it by pointing `FirstRoom` at `TEST.scene_typerfx`

## Bug Fixes
- Fixed the battle turn never receiving `dt`: `ui.Update(dt)` called `state.Update()` without forwarding the delta, so the delta was `nil` inside `state.Update` and stayed `nil` for everything downstream — `Battle._wave.Update(dt)` (DEFENDING), `Battle.attack.Update(dt)` (ATTACKING) and `Battle.FleeUpdate(dt)` (FLEEING). Any wave code that actually reads `dt` — a shader's `update(dt)`, a timer, or movement integration — silently ran on `nil`, which is what surfaced as an error when a converted Shadertoy shader was driven from a wave's `Update`. The delta is now forwarded from `ui.Update` into `state.Update`, so `dt` is the real frame time again in all three states. This was a long-standing bug rather than a regression: it went unnoticed because most wave code does not read `dt` at all

## Partial Changes
- `_VER` in `conf.lua` bumped to `3.0.1-stable`
- The four typer modules now route their draw through `render.draw(emit, bounds, stencils, shaders)` rather than each carrying its own letter loop; the emitted draw calls are unchanged when neither a mask nor a shader is set
- `masks.New`'s `image` parameter is annotated as nullable (`love.Image|table|nil`) in its LuaDoc
- `Scripts/Libraries/Timer.lua` documented in Chinese
