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

统计项目中所有 Lua 文件的行数、大小并列出最大的十个文件：

```bash
python count_lua_files.py
```

也可以传入要统计的目录：

```bash
python count_lua_files.py "D:\path\to\project"
```

Windows 下也可以直接双击 [`run.bat`](run.bat)（优先使用 `pythonw`，无黑窗口）。

## Lua 跨平台兼容检查 / Lua compatibility check

手动运行的独立检查器：按不同"严格程度"静态检查项目里的 Lua 文件是否能跑通。
它只读不改，不需要与项目代码建立任何连接。

```bash
# 默认严格度 3（love.js，最严格），自动检查项目根目录
python check_compat.py

# 也可以传入要检查的目录，或指定严格度
python check_compat.py --strict 1
python check_compat.py --strict 2
python check_compat.py D:/path/to/other/game --strict 1

# 三种严格度一次性对比 / 输出 JSON 供其它工具接入
python check_compat.py --all
python check_compat.py --json
```

Windows 下也可以直接双击 [`check_compat.bat`](check_compat.bat)（默认按严格度 3 检查）。

### 三级严格度（对应三种目标平台）

| 严格度 | 目标平台 | 说明 |
| ------ | -------- | ---- |
| `1` | Windows 开发端 | 最宽松。NTFS 大小写不敏感，`require` 大小写写错也能命中；LÖVE 12 / Lua 5.4 的新语法（`goto`、位运算等）都能用 |
| `2` | exe 发布 / Linux 等 | 较严格。`.love` 一旦在区分大小写的文件系统上解包，`require` / `ImportFile` 引用的大小写必须与磁盘一致 |
| `3` | love.js (Web) | 最严格。love.js 是 LuaJIT / Lua 5.1 语义：`goto`、`::label::`、`// << >> & \| ~`、`0b` 字面量会编译失败；虚拟文件系统也大小写敏感 |

### 能检查出什么（按严重性分级：error / warning / info）

- **error（该严格度下会阻断运行）**：
  - UTF-8 BOM、非 UTF-8 编码
  - 字符串 / 长注释未闭合、括号不配对等基础语法问题
  - `require` / `ImportFile` 目标模块文件不存在
  - 大小写与磁盘不一致（严格度 2/3 时）
  - `goto` / `::label::` 等 Lua 5.2+ 语法（严格度 3 时）
- **warning（可能踩雷）**：
  - `loadstring` / `setfenv` / `getfenv` 等 Lua 5.1 专属 API（LÖVE 12 换成 Lua 5.4 后已移除）
  - 动态 `require`（运行时变量拼路径，静态无法确认；严格度 2/3 上升为警告）
- **info（仅供参考）**：
  - `require` 到 `love` / `ffi` / `bit` 等运行时模块（注意 `ffi` 仅 LuaJIT/5.1 有）
  - `io.popen` / `os.execute`（love.js 中不可用）
  - 大小写不一致（严格度 1 时，Windows 大小写不敏感，不阻断）

### 特殊处理

- 兼容项目自己的 [`ImportFile`](../Scripts/Libraries/Engine/PathDefiner.lua) 加载器：默认按
  `Scripts.Libraries.<路径>` 解析，shader / dll 类型也会单独检查。
- 能解开 `local path = (...):match(...)`、`local cwd = (...):gsub(...) .. "."` 这类
  `init.lua` 相对 require 惯用法，并校验展开后的大小写与存在性。

> 注意：这是**静态检查**，不可能 100% 替代真实运行；它专注在可可靠判定的
> 跨平台雷区（大小写、Lua 版本语法差异、模块缺失、基础语法）。

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
  build_tool.py       # 主程序（GUI + 打包逻辑）
  count_lua_files.py  # Lua 文件统计脚本
  check_compat.py     # Lua 跨平台兼容检查器（三级严格度）
  check_compat.bat    # 检查器 Windows 启动脚本
  run.bat             # Windows 启动脚本
  README.md           # 本说明
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
