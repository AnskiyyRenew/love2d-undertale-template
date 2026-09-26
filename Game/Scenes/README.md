# Game/Scenes

Game-side scene script directory (the engine reads from here first).

- Scene module `Game.Scenes.<name>` maps to `<name>.lua` in this directory
- Overrides the engine scene of the same name, `Scripts.Scenes.<name>`; falls back to the engine side when not provided
- Note: if an override file exists but throws at the top level, the engine automatically
  falls back to the engine side and logs `WARNING: ... exists but failed to load`
  together with the real error message
