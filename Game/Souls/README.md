# Game/Souls

游戏侧灵魂（Soul）脚本目录，引擎优先读取此处。

- 灵魂模块 `Game.Souls.<名称>` 对应本目录下 `<名称>.lua`
- 引擎自带灵魂为 `red` / `orange` / `blue`，同名文件可整份覆盖
- 未提供时回退引擎目录 `Scripts/Libraries/Battle/Player/Souls/`

灵魂贴图不受本目录影响：贴图走 `Sprites` 的资源查找，放 `Game/Resources/Sprites/`
下同名文件即可覆盖。
