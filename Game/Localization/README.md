# Game/Localization

Your game's **patch layer** for translation files — it is merged on top of the engine's.

- One JSON per language, named `<language code>.json`, e.g. `zh_CN.json`, `en.json`
- Lookup order is `Game/Localization/` first, `Localization/` (engine defaults) second
- **Merge is per key, not per file**: anything you leave out here falls back to the engine's
  copy automatically, so this file only needs the entries you actually override
- Nested objects merge key by key; arrays are replaced whole
- If a file here fails to parse it is skipped with a warning and the engine copy still loads
- Press **F2** in game to reload without restarting
