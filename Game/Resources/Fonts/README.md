# Game/Resources/Fonts

Game-side font resource directory (the engine reads from here first).

- Drop a `.ttf` / `.otf` here and **give `Fonts.New` the bare filename**, e.g.
  `Fonts.New("determination_mono.ttf", 24, "mono")` — do not write the
  `Resources/Fonts/` prefix yourself.
- Falls back to the engine directory `Resources/Fonts/` when no same-named file exists here.
- Resolution lives in `Scripts/Libraries/Fonts.lua` (`Fonts.ResolvePath`), a global set up in
  `main.lua` before anything loads a font. Every font load in the engine goes through
  `Fonts.New`, so overriding a typeface needs no code change at all.
- The filename must match exactly (case included) — the lookup is a plain filesystem probe,
  so `MyFont.TTF` and `myfont.ttf` are different files, and on Android / Linux the case
  matters for real.
