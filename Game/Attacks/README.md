# Game/Attacks

游戏侧战斗攻击模式（PlayerAttacks）脚本目录，引擎优先读取此处。

- 模块 `Game.Attacks.<名称>` 对应本目录下 `<名称>.lua`
- 未提供时回退引擎目录 `Scripts/Libraries/Battle/PlayerAttacks/`
- 引擎默认的 `stick` 同样可以覆盖（`Game/Attacks/stick.lua`）
- 找不到或加载报错时会回退默认攻击模式并打日志，战斗不会因此卡死

只想改某个攻击模式的一两个行为时，用 `Game/Hacks/` 更轻；要整份换实现时放这里。
