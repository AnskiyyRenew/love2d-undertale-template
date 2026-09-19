# Game/Scenes

游戏侧场景脚本目录（引擎优先读取此处）。

- 场景模块 `Game.Scenes.<名称>` 对应本目录下 `<名称>.lua`
- 覆盖引擎同名场景 `Scripts.Scenes.<名称>`；未提供时走引擎侧
- 注意：若覆盖文件存在但顶层报错，引擎会自动回退引擎侧，并在日志中打出
  `WARNING: ... exists but failed to load` 与真实错误信息
