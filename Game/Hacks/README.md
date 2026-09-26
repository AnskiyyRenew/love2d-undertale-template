# Game/Hacks

Game-side entry point for engine injections (hacks). The engine runs the scripts in
this directory automatically, **after all libraries are loaded and before the first
scene**, so you can change engine internals (battle UI, battle flow, sprite behavior,
...) **without editing any file under `Scripts/`**.

## File rules

- Every `.lua` file **directly in this directory** is an entry point, **except files starting
  with an underscore `_`** (those are plain modules for entries to require, and are not
  executed as entries). Subdirectories are not scanned at all.
- Entries run sorted by the **numeric prefix of the filename**: `010_ui.lua` before
  `020_flow.lua`.
- Each file returns `{name = ..., apply = function(Hack) ... end}`, or a plain function
  (equivalent to `apply`).

```lua
-- Game/Hacks/010_my_ui.lua
return {
    name = "Custom battle UI",
    apply = function(Hack)
        Hack.Replace("Scripts.Libraries.Battle.UI", "Game.Hacks._MyUI")
    end
}
```

!!! warning "The replacement module must NOT look like an entry"
    A replacement module placed at `Game/Hacks/MyUI.lua` will also be picked up as an entry
    point and run (with a `[Hack] WARNING`, because it returns a table without `apply`).
    Put it under an underscore name (`Game.Hacks._MyUI`) or in a subdirectory
    (`Game.Hacks.ui.MyUI`).

## Declarative overrides: `Game/Overrides.lua`

If you only need whole-module replacement, skip the imperative API entirely and write a
mapping table in `Game/Overrides.lua`:

```lua
-- Game/Overrides.lua
return {
    ["Scripts.Libraries.Battle.UI"] = "Game.UI.Battle",
}
```

It shares the same mechanism (and the same diagnostics) as `Hack.Replace`. The file is read
on every `Hack.Load()`, and an empty `return {}` means "nothing to override".

| | `Game/Hacks/*.lua` | `Game/Overrides.lua` |
| --- | --- | --- |
| Style | imperative Lua | declarative table |
| Can do | whole-module replace **and** fine-grained Wrap/Set/Patch | whole-module replace only |
| Use when | you need to touch a couple of functions | you rewrote an entire module |

## Primitives

| API | Purpose |
| --- | --- |
| `Hack.Replace(engine module, Game module)` | Replace a whole module. Written into `package.preload`, so it also takes effect for **lazily loaded modules (Battle / UI)** |
| `Hack.After(module name, fn)` | Run `fn(module)` as soon as the module is loaded. This is the only way to change globals like `Battle` / `UI` that do not exist yet at startup |
| `Hack.Wrap(owner, key, wrapper)` | Wrap a function; `wrapper(original, ...)` receives the original function first |
| `Hack.Set(owner, key, value)` | Overwrite a field directly |
| `Hack.Patch(owner, patch)` | Deep-merge a table (tables merge recursively, other values are overwritten) |

## Behavior

- **Isolation**: if one hack crashes, it only logs `[Hack] ERROR` and is skipped. Other
  hacks are unaffected and the game still starts.
- **Order**: lower numbers run first; a later `Wrap` sits further outside (sees the call first).
- **Conflicts**: wrapping the same `owner.key` twice logs a `[Hack] WARNING`.
- **F5**: `Hack.Unapply()` restores all original values first, then `Hack.Load()` replays
  them, so nothing nests. Restore info lives in the global `_HACK_STATE` and is not
  affected by `ClearModuleTree`.
- **No side effects**: with no files here (or only `_`-prefixed modules), nothing happens.
- F6 debug info lists the hacks currently in effect.

## Caveats

- If a `Hack.Replace` target is **already loaded**, it degrades to a per-field hot swap and
  logs a WARNING: some code may already hold a reference to the old function, so behavior
  is not exactly equivalent. Prefer replacing before the target loads (or just use
  `Hack.After`).
- **Reach for a proper override first.** Only the content that has a Game-area lookup needs
  no hack at all; the rest is engine behavior and belongs here.

| What you want to change | Proper mechanism (no hack) |
| --- | --- |
| Soul scripts | `Game/Souls/<name>.lua` |
| Enemy animations | `Game/Animations/<name>.lua` |
| Wave scripts | `Game/Waves/<name>.lua` |
| Attack patterns | `Game/Attacks/<name>.lua` |
| Encounters | `Game/Encounter/<file>.lua` (Game-only, no engine twin) |
| World rules / items | `Game/Logics/init.lua`, `Game/Logics/items.lua` (hard required) |
| Any sprite / map / music / text | the matching file under `Game/Resources/` or `Game/Maps/` |
| Any font | the same filename under `Game/Resources/Fonts/` (loaded through `Fonts.New`) |
| Configuration defaults | `Game/conf_pure.lua` (layered on top of the root copy) |
| Anything else (battle UI, battle flow, ...) | **`Game/Hacks/` or `Game/Overrides.lua`** |
