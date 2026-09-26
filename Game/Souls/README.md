# Game/Souls

Game-side soul (Soul) script directory; the engine reads from here first.

- Soul module `Game.Souls.<name>` maps to `<name>.lua` in this directory
- The engine ships the souls `red` / `orange` / `blue` / `yellow`; a file with the same name replaces the whole module
- Falls back to the engine directory `Scripts/Libraries/Battle/Player/Souls/` when not provided
- `_temp.lua` is the template and the one place the contract is written down:
  every soul sets itself up in `Init(sprite, can_move, args)`, which the engine
  calls on each soul switch. Sprite binding, tint and state reset live in the
  soul file, not in `Player.SetSoul`.

Soul sprites are not affected by this directory: sprites go through the `Sprites`
resource lookup, so just drop a file with the same name under `Game/Resources/Sprites/`
to override it.
