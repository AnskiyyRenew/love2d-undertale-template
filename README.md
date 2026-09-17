# SoulEngine — A LOVE2D UNDERTALE Fangame Template

![ICON](./icon.png)

[English](#english) | [中文](#中文)

---

<a id="english"></a>
## English

`SoulEngine` is a LOVE2D template and framework for building games inspired by [UNDERTALE](https://undertale.com/).
Rather than a bare battle demo, it ships a complete day-to-day development workflow — battle scenes, overworld exploration, text presentation, Tiled maps, localization, debugging and packaging — so you can start a real fangame project on day one.

Influenced by [Create Your Frisk](https://github.com/RhenaudTheLukark/CreateYourFrisk), it shares a similar spirit and workflow design.

### Highlights

The template is organized around six topics. Each one is wired up and comes with working examples — no need to assemble the pieces yourself.

- **Battle system** — FIGHT / ACT / ITEM / MERCY flow, enemy and player definitions, attack timing, hit / miss / flee logic, custom waves and wave templates, plus built-in bones and Gaster Blasters.
- **Overworld** — Tiled-based room maps, player movement and camera follow, collisions and trigger areas, signs, chests, save points, warps, scripted interactions, and random encounters that hand off to the battle scene.
- **Text, sprites & scenes** — typewriter dialogue, instant text, bubble boxes, color / font / size / effect tags, multilingual text; scene switching, sprite management, layer sorting, tween and timing helpers.
- **Shaders, audio & GUI** — screen shaders, multi-pass rendering, masks and stencils; sound and music playback with loop points and volume / pitch transitions; buttons, sliders, text inputs, panels, windows, dropdowns.
- **Tooling & workflow** — custom error screen for readable crash reports, `_RELEASED` switch separating dev from release mode, fast scene reset / reload shortcuts, built-in example scenes / waves / maps, bundled Windows packaging tools, built-in localization flow (English and Simplified Chinese examples included).
- **API & networking** — GameJolt API (auth, trophies, sessions, datastore, scores / leaderboards), ships with `sock.lua` for multiplayer experiments, Windows-specific utilities (window helpers, screenshots, system dialogs).

### Documentation

The repo ships with a full documentation site under `Documentation/`, covering getting started, Lua basics, the engine workflow, advanced features, battle development, overworld development, localization, packaging and common error handling.

- **Online** — always up to date: https://anskiyyrenew.github.io/SoulEngine-Documentation/
- **Offline** — open the `Documentation/` folder locally, works without internet access.

### Getting Started

**Prerequisites**

- Familiarity with [UNDERTALE](https://undertale.com/) is recommended.
- [LOVE2D](https://love2d.org/) **11.3** or compatible. Future updates aim to maintain compatibility with newer LOVE versions.

**Run the project**

- Use your editor's LOVE2D run feature (recommended: [Visual Studio Code](https://code.visualstudio.com/) with LOVE/Lua extensions), or
- Drag the project folder onto `love.exe` (`lovec.exe` on Windows).

**Good fit for** — creators making UNDERTALE-inspired fangames in LOVE2D, developers who want both battle and overworld, beginners who need structured docs instead of raw source, and small teams or solo creators who want to start quickly.

**Mobile** — on Android you can browse and edit scripts with a capable file manager or code editor such as [MT Manager](https://mt2.cn).

### Credits

This template uses the following libraries:

- [MD5](https://github.com/kikito/md5.lua) by kikito — pure-Lua 5.1 MD5 implementation.
- [dkjson](http://dkolf.de/dkjson-lua/) — JSON module for Lua with UTF-8 support.
- [STI](https://github.com/karai17/Simple-Tiled-Implementation) by karai17 — Tiled map loader and renderer for LÖVE.
- [sock](https://github.com/camchenry/sock.lua) by camchenry — networking library for LÖVE, useful for multiplayer experiments.

### Community

- **Discord:** https://discord.gg/QeCmVMX7Mk
- **QQ Group:** 626073642

---

<a id="中文"></a>
## 中文

`SoulEngine` 是一个基于 LOVE2D 的模板与框架，用于开发受 [UNDERTALE](https://undertale.com/) 启发的游戏。
它不只是一个简单的战斗演示，而是一套完整的日常开发工作流——战斗场景、大地图探索、文本呈现、Tiled 地图、本地化、调试与打包——让你第一天就能开始真正的同人游戏项目。

受 [Create Your Frisk](https://github.com/RhenaudTheLukark/CreateYourFrisk) 影响，在精神与工作流设计上与之类似。

### 亮点

模板围绕六个专题组织，每个专题都已接好线并附带可运行示例——无需自行拼装。

- **战斗系统** —— FIGHT / ACT / ITEM / MERCY 流程、敌人与玩家定义、攻击时机、命中 / 未命中 / 逃跑逻辑、自定义波次与波次模板，内置骨头与 Gaster Blaster。
- **大地图** —— 基于 Tiled 的房间地图、玩家移动与相机跟随、碰撞与触发区、告示牌、宝箱、存档点、传送门、脚本化交互，以及可交接到战斗场景的随机遇敌。
- **文本、精灵与场景** —— 打字机对话、即时文本、气泡框、颜色 / 字体 / 字号 / 效果标签、多语言文本；场景切换、精灵管理、图层排序、补间与时序辅助。
- **着色器、音频与 GUI** —— 屏幕着色器、多通道渲染、遮罩与模板；带循环点与音量 / 音调过渡的声音与音乐播放；按钮、滑块、文本输入框、面板、窗口、下拉框。
- **工具与工作流** —— 用于可读崩溃报告的自定义错误屏、区分开发 / 发布模式的 `_RELEASED` 开关、快速场景重置 / 重载快捷键、内置示例场景 / 波次 / 地图、随附的 Windows 打包工具、内置本地化流程（含简体中文与英文示例）。
- **API 与网络** —— GameJolt API（认证、奖杯、会话、数据存储、分数 / 排行榜）、随附 `sock.lua` 用于多人联机实验、Windows 专用工具（窗口辅助、截图、系统对话框）。

### 文档

仓库随附一套完整文档站点，位于 `Documentation/` 下，涵盖入门、Lua 基础、引擎工作流、进阶特性、战斗开发、大地图开发、本地化、打包与常见错误处理。

- **在线** —— 始终最新：https://anskiyyrenew.github.io/SoulEngine-Documentation/
- **离线** —— 在本地打开 `Documentation/` 文件夹，无需联网。

### 快速开始

**前置条件**

- 建议熟悉 [UNDERTALE](https://undertale.com/)。
- [LOVE2D](https://love2d.org/) **11.3** 或兼容版本。后续更新将尽量兼容更新的 LOVE 版本。

**运行项目**

- 使用编辑器的 LOVE2D 运行功能（推荐：[Visual Studio Code](https://code.visualstudio.com/) 配合 LOVE/Lua 扩展），或
- 把项目文件夹拖到 `love.exe` 上（Windows 上为 `lovec.exe`）。

**适用人群** —— 想用 LOVE2D 制作 UNDERTALE 风格同人游戏的创作者、需要战斗和大地图的开发者、需要结构化文档而非源码的初学者、想快速起步的小团队或独立创作者。

**移动端** —— 在 Android 上可用 [MT Manager](https://mt2.cn) 等支持代码编辑的文件管理器浏览和编辑脚本。

### 致谢

本模板使用了以下库：

- [MD5](https://github.com/kikito/md5.lua) by kikito —— 纯 Lua 5.1 MD5 实现。
- [dkjson](http://dkolf.de/dkjson-lua/) —— 支持 UTF-8 的 Lua JSON 模块。
- [STI](https://github.com/karai17/Simple-Tiled-Implementation) by karai17 —— LÖVE 的 Tiled 地图加载器与渲染器。
- [sock](https://github.com/camchenry/sock.lua) by camchenry —— LÖVE 的网络库，适合多人联机实验。

### 社区

- **Discord：** https://discord.gg/QeCmVMX7Mk
- **QQ 群：** 626073642
