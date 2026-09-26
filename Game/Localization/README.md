# Game/Localization

Game-side override directory for translation files (the engine reads from here first).

- Put one JSON file per language, named `<language code>.json`, e.g. `zh_CN.json`, `en.json`
- The engine looks up the language code given to `Localize` in this directory
- Falls back to the engine directory `Localization/` when not found
