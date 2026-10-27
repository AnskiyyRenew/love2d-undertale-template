# Update Log

> Changes since tag `v3.0.0` (`dfbdb1a`) — to be used as the release note for the next build.

## New Features
- Added the GUI library (`Scripts/Libraries/GUI/`), loaded as the global `GUI`: `Window`, `Label`, `Button`, `Slider`, `TextInput`, `Dropdown`, an `Input` mouse helper and the low-level `primitives`
- Added shape-aware collision: `sprite:SetHitboxShape("ellipse")` / `"rect"`, `sprites.GetHitboxShape`, `Player.SetHitboxShape` and the `Collisions.ShapeWithShape` / `ShapeWithPoint` / `ShapeName` / `IsEllipse` dispatchers
- Added a native secret store for the GameJolt private key (`Packager/Secrets/` + `Scripts/Libraries/Utils/Secrets.lua`): the key is compiled into a `.dll` / `.so` and read back through LuaJIT FFI, degrading quietly to `nil` when the library is missing
- Added an overworld save-data bridge to the battle system: `battle.SyncFromOverworld()`, `battle.SyncToOverworld()`, `battle.HasOverworldData()` and the `auto_overworld_sync` flag for scripted fights
- Added wall-touch queries to the arena: `arenas.PlayerOnWallLeft`, `arenas.PlayerOnWallRight`, `arenas.PlayerOnWall` and `arenas.GetWallSide`
- Added text measurement to every typer module: `typer:GetWidth()`, `typer:GetHeight()` and `typer:GetLettersSize()`, plus `Typers.GetLettersSize(typer)` which accepts an instance of any of the four modules
- Added `typer:SetFunc(name, fn)` to EText, so `[func:name]` can call registered closures and module locals instead of only `_G` functions
- Added `Typers.CCRemove(cc)` for disposing a floating CC text, and the default CC animation now releases itself once it has finished
- Added asset preloading: `audio.PreloadFile(path, kind)`, `sprites.PreloadFile(path)` and the `SE.Preload` / `SE.PreloadAll` wrappers
- Added `BluePlatform:SetStencils()` and a `Step` callback
- Added a Celeste-style platformer soul example at `Game/Souls/celeste.lua` (walk, jump, wall grab / slide / jump, 8-direction dash with double dash, stamina)
- Added `Gamejolt.logout()`, which discards the stored credentials locally and stops the session heartbeat
- Added a third return value to every GameJolt endpoint: `kind` is `"transport"` when the request never produced a usable answer and `"api"` when the server explicitly refused it
- Added an optional `as_guest` argument to `Gamejolt.submitScore(score, table_id, sort, extra_data, as_guest)`; scores are filed under the logged-in account unless it is set
- Overworld overlays now pick their side automatically: `Overworld.ui_prefer` defaults to `"auto"`, and a dialog or the stat menu opens above the player once the player drops below `Overworld.ui_threshold` (canvas Y, default `320`). `Overworld.ResolveUIPosition()`, `Overworld.GetPlayerScreenY()` and `Overworld.FlipY(y)` are exposed for custom overlays, and `"up"` / `"down"` still pin one side
- The stat menu's left column mirrors across the screen midline in the `"up"` layout: the status box moves under the button box while the button box (centred on `240`) stays put, and the text inside keeps its offset so the lines are never flipped

## Bug Fixes
- Fixed stencil masks leaking across frames and waves: `Masks.Clear()` now zeroes the stencil buffer instead of only disabling the test, and `love.draw` clears the stencil buffer every frame
- Fixed the whole canvas turning permanently black: `Masks.Clear()` re-disables the stencil test after `pop("all")` restores the enabled state saved on entry
- Fixed `arenas.Clear()` blanking every registered mask, which dropped the main battle box's clipping after the first turn; a destroyed arena now unregisters only its own mask
- Fixed the player's collision half-size being hardcoded to 8px; it is now derived from the sprite's real size and scale, so a crouched soul no longer floats above platforms
- Fixed bone edge placement ignoring `ypivot`: `ToDown`, `ToUp`, `ToLeft` and `ToRight` now keep the bone flush with the arena edge for any pivot
- Fixed bullet-vs-soul tests ignoring an ellipse hitbox; the player test now goes through `Collisions.ShapeWithShape`
- Fixed `BluePlatform`'s `mode` gating movement entirely; it now gates only the sideways carry
- Fixed the shop's black background panel not inheriting the white panel's `y`
- Removed a stale `Player.SetSoul("blue")` call from the sample wave
- Fixed GameJolt logins never being rolled back: `Gamejolt.authUser()` stored the username and token before validating them and kept them on failure, so `isLoggedIn()` stayed `true` after a rejected login and every later request went out with dead credentials. Credentials are now committed only after `/users/auth/` accepts them, and a failed attempt returns the library to the logged-out state
- Fixed `Gamejolt.isLoggedIn()` answering `true` for empty strings or non-string input; it now requires non-empty credentials that the API accepted at least once
- Fixed `Gamejolt.authUser()` reporting success on a response that carried no `response` envelope: the check was `success ~= false`, and `nil ~= false` is true. `apiRequest` now requires a table payload, and `success` is caught as both `"false"` and boolean `false`
- Fixed GameJolt requests being able to take down a frame: `https.request` runs inside `pcall`, so DNS and TLS failures return `false, message, "transport"` instead of raising into `love.update`
- Fixed GameJolt query values being concatenated raw; every parameter is percent-encoded and the signature is computed over the encoded string, so keys, data and usernames holding spaces, `&`, `=` or CJK characters no longer break the URL or fail the signature check
- Fixed GameJolt endpoints throwing while concatenating `nil` when called before `init()` or before logging in; both now return `false` with a message
- Fixed `Gamejolt.submitScore()` submitting as a guest even after a successful `authUser()`; credentials are appended whenever someone is logged in
- Fixed the session heartbeat retrying forever with credentials the server had already refused: an `"api"` failure stops the heartbeat and drops back to logged out, while transport failures still retry
- Fixed `Gamejolt.init()` carrying the previous player's credentials over to another `app_id`

## Partial Changes
- `BORDER_MODE` now defaults to `false` in `conf.lua`
- The default player `_hitbox` changed from `{4, 4}` to `{2, 2}`
- The F7 collision overlay draws ellipse hitboxes as outlines
- `scene_battle_ow` is now a thin, idempotent reference wrapper over the Battle-library sync, so every battle scene gets the overworld hand-off instead of only this one
- Level-ups read `DATA.lv_data` and add the gained max HP to the current HP, Undertale-style
- `audio.PlaySound` and `audio.PlayMusic` clone a preloaded template Source instead of decoding the file on every call
- `.gitignore` keeps `secrets.local.json`, `build/` and `Resources/Libs/Secrets/` local; only the example template is committed
- Removed accidentally committed `__pycache__` files
- Root `README.md` rewritten
- Documentation regenerated as a bilingual (en + zh_CN) offline build
- `Gamejolt.sessionClose()` stops the heartbeat but keeps the credentials; `Gamejolt.logout()` is the call that drops them
- GameJolt failures return `false, message, kind` instead of `false, message`; `Gamejolt.authUser()` still returns only `boolean, message`
- `apiRequest` takes the unsigned request path instead of a complete URL, so the URL and its signature are assembled in one place
- The GameJolt documentation page is rewritten in both languages: the workarounds documented for `authUser` and for data-store encoding are no longer needed

<!--
Included commits (v3.0.0..HEAD):
  9a09239 offline doc
  4cbc622 bilingual offline docs + engine sync
  76d9df7 Native secret store, Celeste soul, shape-aware collision and mask leak fixes
  ec66f09 fix(masks): re-disable stencil test after pop("all") to stop black canvas
  fec5a2b Typer text measurement, arena mask cleanup and regenerated docs
-->
