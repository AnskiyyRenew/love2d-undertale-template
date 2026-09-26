# Game/Waves/bones

Bone (`bones`) wave script directory.

- A wave file `<name>.lua` in this directory is module `Game.Waves.bones.<name>` — i.e. the
  wave name you pass around is `bones.<name>` (e.g. `bones.wave1`)
- Resolution is Game area first, then the engine twin `Scripts.Waves.<name>` (so
  `bones.wave1` also matches `Scripts/Waves/bones/wave1.lua`). A module found in the engine
  directory after the Game area has no copy logs a `[Battle - Wave] WARNING`
- A wave that is missing **or** throws falls back to the default wave (`wave`), so a battle
  always has something to run; the module actually used is recorded in `Battle.waveModule`
