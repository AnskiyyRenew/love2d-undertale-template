# SoulEngine — A LOVE2D UNDERTALE Fangame Template

![ICON](./icon.png)

[English](#english) | [中文](#中文)

---

<a id="english"></a>
## English

`SoulEngine` is a LOVE2D template and framework for building games inspired by [UNDERTALE](https://undertale.com/). It covers what a fangame needs past the battle screen: overworld maps, dialogue, Tiled rooms, localization, debugging and packaging.

[Create Your Frisk](https://github.com/RhenaudTheLukark/CreateYourFrisk) was the main influence, and this follows its approach to project layout and workflow.

### What's included

Seven areas, each wired up with examples you can copy from.

- **Battle system.** FIGHT / ACT / ITEM / MERCY flow, enemy and player definitions, attack timing, hit / miss / flee logic, custom waves and wave templates, plus built-in bones and Gaster Blasters.
- **Overworld.** Tiled room maps, player movement with camera follow, collisions and trigger areas, signs, chests, save points, warps, scripted interactions, and random encounters that hand off to the battle scene.
- **Text, sprites & scenes.** Typewriter dialogue, instant text, bubble boxes, color / font / size / effect tags, multilingual text; scene switching, sprite management, layer sorting, tween and timing helpers.
- **Shaders, audio & GUI.** Screen shaders, multi-pass rendering, masks and stencils; sound and music with loop points and volume / pitch transitions; buttons, sliders, text inputs, panels, windows, dropdowns.
- **Tooling & workflow.** Custom error screen for readable crash reports, `_RELEASED` switch separating dev from release mode, fast scene reset / reload shortcuts, bundled Windows packaging tools, and a built-in localization flow with English and Simplified Chinese examples. Example scenes, waves and maps are included too.
- **API & networking.** GameJolt API (auth, trophies, sessions, datastore, scores and leaderboards), `sock.lua` for multiplayer experiments, and Windows-only helpers for window management, screenshots and system dialogs.
- **Engine upgrades.** Everything you write lives in `Game/`, so a new engine version is a copy-and-overwrite rather than a merge.

### Upgrading the engine

Engine files are `Scripts/`, `Resources/`, the root `Localization/` and the root `conf_pure.lua`. You shouldn't need to touch any of them: content in `Game/` is loaded first, and deeper changes go through `Game/Hacks/` or `Game/Overrides.lua` instead of editing engine files.

`Game/` carries the whole game: `Animations/`, `Attacks/`, `Encounter/`, `Hacks/`, `Localization/`, `Logics/`, `Maps/`, `Resources/`, `Scenes/`, `Souls/`, `Waves/`, plus `Overrides.lua` and `conf_pure.lua`.

Upgrading takes three steps:

1. Download the new engine version.
2. Copy your `Game/` folder over the `Game/` folder of the fresh copy.
3. Run it.

Souls, animations, waves, encounters, maps, sprites, music, text and hacks all travel in that one folder, so there's nothing to diff or re-apply.

> This holds only while your changes stay on the Game side. Edits made directly to `Scripts/` or the engine `Resources/` count as engine changes and won't be carried over.

### Documentation

The docs live in a separate repository, published as a site, and aren't shipped with this repo.

- **Online:** https://anskiyyrenew.github.io/SoulEngine-Documentation/
- **Local:** if a `soulengine-doc3/` folder sits next to the project, that's the MkDocs source for the site. It's listed in `.gitignore`, so a fresh `git clone` won't have it. Use the online site instead.

> `soulengine-doc3/` is a local working copy only. This repository has no `Documentation/` directory.

### Getting started

**Prerequisites**

- Some familiarity with [UNDERTALE](https://undertale.com/) helps.
- [LOVE2D](https://love2d.org/) 12.0 or compatible. Newer LOVE versions should keep working.

**Run the project**

- Use your editor's LOVE2D run feature. [Visual Studio Code](https://code.visualstudio.com/) with LOVE/Lua extensions is the common setup. Or
- drag the project folder onto `love.exe` (`lovec.exe` on Windows).

**Who this is for:** anyone building an UNDERTALE-inspired fangame in LOVE2D who wants battle and overworld together, and would rather read structured docs than dig through source.

**Mobile:** on Android, a file manager with a built-in editor such as [MT Manager](https://mt2.cn) works for browsing and editing scripts.

### Credits

Libraries this template uses:

- [MD5](https://github.com/kikito/md5.lua) by kikito — pure-Lua 5.1 MD5 implementation (`Scripts/Libraries/Utils/MD5.lua`), used for the GameJolt request signature.
- [dkjson](http://dkolf.de/dkjson-lua/) — JSON module for Lua with UTF-8 support (`Scripts/Libraries/Utils/dkjson.lua`).
- [STI](https://github.com/karai17/Simple-Tiled-Implementation) by karai17 — Tiled map loader and renderer for LÖVE (`Scripts/Libraries/STI/`).
- [sock](https://github.com/camchenry/sock.lua) by camchenry — networking library for LÖVE, for multiplayer experiments (`Scripts/Libraries/Network/sock.lua`).
- [bitser](https://github.com/gvx/bitser) by Robin Wellner — fast Lua binary serializer, one of sock's backends.
- [binser](https://github.com/CalvinRose/binser) by Calvin Rose — the other serialization backend shipped with sock.
- [lua-https](https://github.com/love2d/lua-https) — the native `https` module the GameJolt API needs (`Resources/Libs/https.dll`, Windows only).

### Community

- **Discord:** https://discord.gg/QeCmVMX7Mk
- **QQ Group:** 626073642

---

<a id="中文"></a>
## 中文

`SoulEngine` 是一个基于 LOVE2D 的模板与框架，用来开发受 [UNDERTALE](https://undertale.com/) 启发的游戏。除了战斗画面，它还覆盖了同人游戏需要的其他部分：大地图、对话、Tiled 房间、本地化、调试与打包。

[Create Your Frisk](https://github.com/RhenaudTheLukark/CreateYourFrisk) 是主要的影响来源，本项目的目录结构与工作流都参照了它。

### 包含内容

七个方面，每块都接好了线并附带可运行的示例。

- **战斗系统** FIGHT / ACT / ITEM / MERCY 流程、敌人与玩家定义、攻击时机、命中 / 未命中 / 逃跑逻辑、自定义波次与波次模板，内置骨头与 Gaster Blaster。
- **大地图** 基于 Tiled 的房间地图、玩家移动与相机跟随、碰撞与触发区、告示牌、宝箱、存档点、传送门、脚本化交互，以及可交接到战斗场景的随机遇敌。
- **文本、精灵与场景** 打字机对话、即时文本、气泡框、颜色 / 字体 / 字号 / 效果标签、多语言文本；场景切换、精灵管理、图层排序、补间与时序辅助。
- **着色器、音频与 GUI** 屏幕着色器、多通道渲染、遮罩与模板；带循环点与音量 / 音调过渡的声音与音乐播放；按钮、滑块、文本输入框、面板、窗口、下拉框。
- **工具与工作流** 可读崩溃报告的自定义错误屏、区分开发 / 发布模式的 `_RELEASED` 开关、快速场景重置 / 重载快捷键、随附的 Windows 打包工具，以及内置本地化流程（含简体中文与英文示例）。另附示例场景、波次与地图。
- **API 与网络** GameJolt API（认证、奖杯、会话、数据存储、分数与排行榜）、用于多人联机实验的 `sock.lua`、Windows 专用工具（窗口操作、截图、系统对话框）。
- **引擎升级** 你写的东西全在一个 `Game/` 文件夹里，换新版本引擎时复制覆盖即可，不用做合并。

### 引擎升级

引擎侧的文件是 `Scripts/`、`Resources/`、根目录下的 `Localization/` 与 `conf_pure.lua`，一般不需要改。放进 `Game/` 的内容会被优先读取，更深的改动通过 `Game/Hacks/` 或 `Game/Overrides.lua` 处理，不用动引擎文件。

`Game/` 装着整个游戏：`Animations/`、`Attacks/`、`Encounter/`、`Hacks/`、`Localization/`、`Logics/`、`Maps/`、`Resources/`、`Scenes/`、`Souls/`、`Waves/`，以及 `Overrides.lua` 与 `conf_pure.lua`。

升级就三步：

1. 下载新版本引擎。
2. 把你的 `Game/` 文件夹复制到新副本里，覆盖同名文件夹。
3. 运行。

灵魂、动画、波次、遭遇、地图、贴图、音乐、文本和 hack 全都在这个文件夹里，没有要 diff 的文件，也不用重新挂一遍覆盖。

> 前提是改动都留在 Game 侧。直接改过 `Scripts/` 或引擎 `Resources/` 里的文件属于引擎改动，不会被带走。

### 文档

文档单独一个仓库维护，以站点形式发布，不随这个游戏仓库一起分发。

- **在线：** https://anskiyyrenew.github.io/SoulEngine-Documentation/
- **本地：** 如果项目旁边有 `soulengine-doc3/` 文件夹，那就是站点的 MkDocs 源。它在 `.gitignore` 里，全新 `git clone` 下来的仓库不会有它，直接用在线站即可。

> `soulengine-doc3/` 只是本地工作副本。本仓库里没有 `Documentation/` 目录。

### 快速开始

**前置条件**

- 建议先熟悉 [UNDERTALE](https://undertale.com/)。
- [LOVE2D](https://love2d.org/) 12.0 或兼容版本。后续更新会尽量兼容更新的 LOVE 版本。

**运行项目**

- 用编辑器的 LOVE2D 运行功能，常见选择是 [Visual Studio Code](https://code.visualstudio.com/) 配合 LOVE/Lua 扩展。或
- 把项目文件夹拖到 `love.exe` 上（Windows 上是 `lovec.exe`）。

**适合人群：** 在 LOVE2D 里做 UNDERTALE 风格同人游戏、需要战斗和大地图、更希望读结构化文档而不是翻源码的人。

**移动端：** 在 Android 上，可以用 [MT Manager](https://mt2.cn) 这类带编辑器的文件管理器浏览和修改脚本。

### 致谢

本模板使用了以下库：

- [MD5](https://github.com/kikito/md5.lua) by kikito —— 纯 Lua 5.1 的 MD5 实现（`Scripts/Libraries/Utils/MD5.lua`），GameJolt 请求签名用。
- [dkjson](http://dkolf.de/dkjson-lua/) —— 支持 UTF-8 的 Lua JSON 模块（`Scripts/Libraries/Utils/dkjson.lua`）。
- [STI](https://github.com/karai17/Simple-Tiled-Implementation) by karai17 —— LÖVE 的 Tiled 地图加载器与渲染器（`Scripts/Libraries/STI/`）。
- [sock](https://github.com/camchenry/sock.lua) by camchenry —— LÖVE 的网络库，用于多人联机实验（`Scripts/Libraries/Network/sock.lua`）。
- [bitser](https://github.com/gvx/bitser) by Robin Wellner —— 快速的 Lua 二进制序列化库，sock 的后端之一。
- [binser](https://github.com/CalvinRose/binser) by Calvin Rose —— 随 sock 一起附带的另一个序列化后端。
- [lua-https](https://github.com/love2d/lua-https) —— GameJolt API 需要的原生 `https` 模块（`Resources/Libs/https.dll`，仅 Windows）。

### 社区

- **Discord：** https://discord.gg/QeCmVMX7Mk
- **QQ 群：** 626073642
