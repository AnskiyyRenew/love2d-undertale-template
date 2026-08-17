# LÖVE Packager / LÖVE 打包工具

一个基于 **Python + tkinter** 的图形化打包工具，用于把 Love2D (LÖVE) 项目打包为多种格式。

A GUI (tkinter) tool to package a Love2D (LÖVE) project into several formats.

## 支持的导出格式 / Supported exports

| 格式 Format                  | 说明 Description                                                        |
| ---------------------------- | ----------------------------------------------------------------------- |
| `.love`                      | 游戏 zip，可直接被 LÖVE 加载                                            |
| Windows `.exe`               | 将 `love.exe` 与 `.love` 合并为独立可执行文件并复制所需 DLL              |
| Android 准备文件 (APK)       | 复制 love-android 模板并把 `game.love` 放入 `app/src/main/assets`        |
| love-js (Web)                | 复制 `game.love` 供 love.js 使用，可自动调用 love.js 命令生成网页版      |
| 源码备份 `.zip`              | 完整源码备份                                                            |

## 运行 / Run

```bash
python build_tool.py
```

Windows 下也可以直接双击 [`run.bat`](run.bat)（优先使用 `pythonw`，无黑窗口）。

## 依赖 / Requirements

- **Python 3**（仅使用标准库，官方 Windows 安装包自带 tkinter，无需额外安装）
- 生成 `.exe`：本机需安装 LÖVE（含 `love.exe`）
- 生成 Android 准备文件：需下载 [love-android](https://github.com/love2d/love-android) 模板
- 生成 love-js：可选，需要 Node.js + [love.js](https://github.com/Davidobot/love.js)

## 语言 / Language

工具启动时会自动检测系统语言并切换为 **中文** 或 **English**。
可在顶部菜单“语言 / Language”中随时手动切换。

The tool auto-detects the OS language (zh/en) on startup and can be switched
at any time from the "Language / 语言" menu.

## 防循环打包（内存炸弹）说明 / Anti-recursive packaging

为避免把工具本身或已生成的产物再次打包进去导致“内存炸弹”，工具 **默认始终排除**：

- 工具自身脚本文件（`build_tool.py`）
- 工具所在文件夹（`Packager/`，当其位于项目内时）
- 输出目录（默认 `<项目>/Export`）
- 已有的 `*.love` 文件（可在“排除设置”中关闭）

以上规则都可在界面“排除设置”里调整，但工具自身与输出目录始终会被排除。

To avoid recursive packaging ("memory bomb"), the tool always excludes its own
script, its own folder (when inside the project), the output directory, and
existing `*.love` files. These can be adjusted under "Exclusions", but the tool
itself and the output directory are always excluded.

## 结构 / Layout

```
Packager/
  build_tool.py    # 主程序（GUI + 打包逻辑）
  run.bat          # Windows 启动脚本
  README.md        # 本说明
```

## 导出示例输出 / Example outputs

在 `<项目>/Export` 目录下（以项目名 `game` 为例）：

```
Export/
  game.love               # .love 文件
  game-win/               # Windows exe 文件夹（含 DLL）
    game.exe
    love.dll
    SDL2.dll
    ...
  game-android/           # Android 准备文件（用 Android Studio 构建 APK）
    app/src/main/assets/game.love
    ...
  game-web/               # love-js 准备文件
    game.love
    README.txt
  game-source.zip         # 源码备份
```
