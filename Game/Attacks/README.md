# Game/Attacks

Game-side battle attack pattern (PlayerAttacks) script directory; the engine reads from here first.

- Module `Game.Attacks.<name>` maps to `<name>.lua` in this directory
- Falls back to the engine directory `Scripts/Libraries/Battle/PlayerAttacks/` when not provided
- The engine's default `stick` can be overridden too (`Game/Attacks/stick.lua`)
- If a file is missing or fails to load, the engine falls back to the default attack pattern and logs it — the battle will not hang because of it

If you only want to change one or two behaviors of an attack pattern, `Game/Hacks/` is
lighter; put the file here when you want to replace the implementation entirely.
