# Game/Localization

游戏侧翻译文件的覆盖目录（引擎优先读取此处）。

- 放置各语言 JSON 文件，命名 `<语言代码>.json`，如 `zh_CN.json`、`en.json`
- 引擎按 `Localize` 的语言代码在此目录查找
- 未找到时回退引擎目录 `Localization/`
