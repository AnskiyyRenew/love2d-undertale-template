# Game/Hacks

游戏侧的引擎注入（hack）入口。引擎在**所有库加载完之后、第一个场景之前**自动
执行本目录下的脚本，用来改引擎底层（战斗 UI、战斗流程、精灵行为等）而**不需要
改 `Scripts/` 里的任何文件**。

## 文件规则

- 目录下所有 `.lua` 都是入口，**以下划线 `_` 开头的文件除外**（它们是给入口
  require 的普通模块，不会被当入口执行）。
- 按**文件名数字前缀**排序执行：`010_ui.lua` 早于 `020_flow.lua`。
- 每个文件返回 `{name = ..., apply = function(Hack) ... end}`，也可以直接返回
  一个函数（等价于 `apply`）。

```lua
-- Game/Hacks/010_my_ui.lua
return {
    name = "自定义战斗 UI",
    apply = function(Hack)
        Hack.Replace("Scripts.Libraries.Battle.UI", "Game.Hacks.MyUI")
    end
}
```

## 三个原语

| API | 用途 |
| --- | --- |
| `Hack.Replace(引擎模块, Game 模块)` | 整份替换模块。写进 `package.preload` 生效，**懒加载模块（Battle / UI）也照样吃得到** |
| `Hack.After(模块名, fn)` | 模块一加载完就执行 `fn(module)`。改 `Battle` / `UI` 这种启动时还不存在的全局，只能用这个 |
| `Hack.Wrap(owner, key, wrapper)` | 包住一个函数，`wrapper(original, ...)` 里先拿到原函数 |
| `Hack.Set(owner, key, value)` | 直接覆盖一个字段 |
| `Hack.Patch(owner, patch)` | 深合并一张表（表递归合并，其它值覆盖） |

## 行为约定

- **隔离**：单个 hack 崩了只报 `[Hack] ERROR` 并跳过，不影响其它 hack，也不阻止
  游戏启动。
- **顺序**：数字小的先跑；后跑的 `Wrap` 包在更外层（先看到调用）。
- **冲突**：同一个 `owner.key` 被包两次会打 `[Hack] WARNING`。
- **F5**：先 `Hack.Unapply()` 还原所有原值，再 `Hack.Load()` 重放，不会叠成
  套娃。还原信息存在全局 `_HACK_STATE`，不受 `ClearModuleTree` 影响。
- **无副作用**：不放任何文件（或只有 `_` 开头的模块）时，什么都不发生。
- F6 调试信息会列出当前生效的 hack。

## 注意

- `Hack.Replace` 的目标如果**已经加载**，会退化为逐字段热替换，并打 WARNING：
  此时可能有代码已经持有旧函数引用，行为不完全等价。优先在目标加载前替换
  （或直接用 `Hack.After`）。
- 想换灵魂脚本请用 `Game/Souls/`，换贴图请用 `Game/Resources/Sprites/`——
  那两处是正经的覆盖机制，不用 hack。
