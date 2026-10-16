# 密钥原生库 / Native secret store

把 GameJolt private key 之类的秘密从 `.lua` 里搬进编译好的 `.dll` / `.so`，
通过 LuaJIT FFI 取回。这样解压 `game.love` 的人翻不到明文。

## 先说清楚边界

这层是**混淆，不是加密**。它能挡住的目标很明确：好奇的玩家打开游戏包、
搜索密钥字符串。挡不住的目标也很明确：

| 攻击方式 | 能否挡住 | 说明 |
| --- | --- | --- |
| 解压 game.love 搜明文 | 能 | 密钥根本不在 Lua 里 |
| 对 dll/so 跑 strings | 能 | 字节经过 XOR，且不是连续 blob |
| 反汇编看 fill 函数 | 不能 | 单条赋值语句，读几行就还原 |
| hook 导出函数 | 不能 | 进程内随便拦截 |
| `print(Gamejolt.private_key)` | 不能 | 密钥最终仍在 Lua 内存里 |

最后一条是最根本的限制：只要密钥参与**客户端**签名，它就等于公开。
GameJolt 官方也是这个立场。真正要守住 private key，只有让它待在服务端。
这里的取舍是：花很小的成本，把"随手就能翻到"变成"得会用反汇编器"。

所以请注意：

- **只藏真正需要藏的东西。** GameJolt 的 `game_id` 是公开信息，放这里没意义，
  只会平白增加维护负担。
- **别指望它保护高价值资产。** 如果泄露密钥会导致实质损失，请走服务端代理。

## 快速开始

```bash
# 1. 填密钥（这个文件已被 git 忽略）
cp secrets.local.example.json secrets.local.json
#    编辑它，只填 gamejolt_pk

# 2. 编译
python build.py
```

产物落在：

```
Resources/Libs/Secrets/secrets.dll                  Windows
Resources/Libs/Secrets/android/<abi>/libsecrets.so  Android
```

Windows 需要一个 **64 位** MinGW gcc —— LÖVE 的 Windows 版是 64 位进程，
32 位工具链产出的 dll 会静默加载失败。脚本会自动探测 Dev-Cpp 自带的
`MinGW64/bin/gcc.exe`，找不到就用 `--gcc` 指定。

Android 需要 NDK。没找到时会跳过并提示，不会让整个构建失败 —— Windows
产物才是日常开发要用的。装好 NDK 后：

```bash
python build.py --ndk D:/android-sdk/ndk/27.3.13750724
```

## 两个平台，两种落位

这是整个方案最容易翻车的地方，`ffi.load` 走的是操作系统加载器
（LoadLibrary / dlopen），**不是** LÖVE 的虚拟文件系统。

**Windows**：源码模式下 dll 待在 `Resources/Libs/Secrets/` 就能被找到。
但 fused exe（`love.exe` + `game.love` 合并）之后磁盘上根本没有源码树，
dll 必须和 exe 放一起 —— 打包脚本已经处理，见 `build_tool.py` 里的
`copy_secret_dll`。

**Android**：`.so` 必须进 APK 的 `lib/<abi>/`，也就是 love-android 模板的
`app/src/main/jniLibs/<abi>/`。塞在 `game.love` 里（一个待在 assets 的 zip）
永远加载不了，因为 dlopen 只搜索应用解压出来的 nativeLibraryDir。
打包脚本的 `copy_secret_sos` 负责这一步，且在 gradlew 之前跑。

**Web / love.js**：没有原生库。Lua 侧会自动回退到 `conf_pure.lua` 的明文值，
再没有就返回 nil，由调用方静默禁用功能。

## Lua 侧用法

```lua
local Secrets = ImportFile("Utils.Secrets")

Secrets.available()      -- 是否来自原生库
Secrets.source()         -- "native" / "fallback" / "none"
Secrets.status()         -- 诊断：命中路径，或每条候选为什么失败
Secrets.gamejoltPK()     -- 取密钥，取不到返回 nil
```

接入 GameJolt（目前 `main.lua` 只加载了模块、还没调用 init，接线时这样写）：

```lua
local Secrets = ImportFile("Utils.Secrets")
local pk = Secrets.gamejoltPK()
if pk then
    Gamejolt.init(Global.GetVariable("GamejoltID"), pk)
else
    -- 密钥不可用：静默禁用成就/排行榜，不要报错打断玩家
end
```

失败路径必须是静默的。开发机上没编译产物、web 版没有原生库，都是正常情况，
不是异常。

## 混淆是怎么做的

生成器 `gen_source.py` 把每个字节 XOR 上一个随索引变化的掩码，然后**不用
静态数组**，而是生成一条条赋值语句：

```c
static void se_fill_0(unsigned char *p)
{
    p[0] = 0x10;
    p[1] = 0x2E;
    ...
}
```

所以 `.rodata` 里不存在任何 blob，`strings` 扫不出来。编译加了 `-s`
（strip）和 `-fvisibility=hidden`，只导出两个符号。

导出函数名刻意起得很朴素（`se_cfg` / `se_cfg_probe`），不出现
`secret`、`key`、`gamejolt` 之类的字眼 —— 目的是让人第一眼看不出这是什么库。

## 维护

**换密钥**：改 `secrets.local.json`，重跑 `build.py`，重新打包。
旧的已发布版本会失效，这是必然的。

**加新密钥**：在 `gen_source.py` 的 `SLOT_ORDER` 末尾追加名字，在
`Secrets.lua` 里加一个对应的 `Secrets.SLOT_XXX` 常量。**只能追加，不能重排或
删除** —— slot 序号是二进制契约，改动会让所有已发布的构建读到错的密钥。

**换机器**：`secrets.local.json` 不进 git，需要单独传递（密码管理器之类）。

## 故障排查

`Secrets.status()` 会把每条候选路径和失败原因都打出来，先看它。

| 现象 | 原因 |
| --- | --- |
| 提示没有 gcc / 编译失败 | 传 `--gcc <path>`，确认是 64 位 MinGW |
| Windows 加载失败 | dll 不在 exe 同目录（fused），或 32/64 位不匹配 |
| Android 加载失败 | .so 没进 `jniLibs/<abi>/`，或 ABI 与设备不符 |
| 能加载但取值是 nil | 该 slot 在 `secrets.local.json` 里是空的 |
| probe 对不上 | 库版本和 `Secrets.lua` 的 `PROBE_MAGIC` 不一致，重新生成 |

---

## 附：验证记录

首次落地时用假密钥跑通了完整链路：

- `gen_source.py` 生成 2810 字节 C 源码
- MinGW64 gcc 4.9.2 编译出 15360 字节 dll
- `LoadLibrary` + `GetProcAddress` 取到 `se_cfg` / `se_cfg_probe`
- probe 返回 `0x5EC0DE`，slot 0 返回正确明文，空 slot 与越界 slot 返回 NULL
- `grep` 扫描 dll：密钥明文 0 命中
- LÖVE 自带的 LuaJIT（lua51.dll）里跑 `ffi.load` + `ffi.string`：取值正确
- `Secrets.lua` 语法编译通过（等价 `luac -p`）
- 打包脚本两个拷贝函数实测落位正确

验证脚本留在 `build/` 下（`test_load.c`、`verify_with_luajit.py`），
该目录已被 git 忽略。
