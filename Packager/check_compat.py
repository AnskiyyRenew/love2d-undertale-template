# -*- coding: utf-8 -*-
"""
Lua 跨平台兼容检查器 / Lua cross-platform compatibility checker
====================================================================

手动运行的独立脚本：只读取并静态检查项目里的 Lua 文件，判断它们在不同
目标平台上"是否可能跑通"。它不依赖项目里的任何文件，也不修改任何文件。

为什么要存在？
--------------------------------------------------------------------
同一个 LÖVE 项目发到不同平台时，出问题的"严格程度"不一样：

  * 严格度 1  Windows 开发端 —— 最宽松
       - NTFS 大小写不敏感，require 里大小写写错也能命中；
       - LÖVE 12 / Lua 5.4，goto、位运算等新语法全部可用；
       - 所以最宽松。

  * 严格度 2  Windows .exe 发布 / Linux 等 —— 较严格
       - .love 一旦解包到 Linux 等区分大小写的文件系统，
         require / ImportFile 引用的大小写必须与磁盘一致；
       - 运行时方言仍是 LÖVE 12 / Lua 5.4。

  * 严格度 3  love.js (Web) —— 最严格
       - love.js 内部是 LuaJIT / Lua 5.1 语义：
         goto、::label::、// << >> & | ~、0b 二进制字面量等
         Lua 5.2+ 语法会直接编译失败；
       - 虚拟文件系统大小写敏感，大小写问题同样致命。

本工具据此把"问题"分成三类严重性：
    error   -> 该严格度下会阻断运行
    warning -> 该严格度下通常能跑，但存在踩雷风险（或某条代码路径会崩）
    info    -> 只是提醒，一般不影响运行

规则矩阵（每列 = 该严格度下的严重性）:
    error=E warning=W info=I

    类别                      | 1 Windows | 2 exe/Linux | 3 love.js
    --------------------------+-----------+-------------+----------
    BOM/编码/语法/括号/字符串 |    E      |      E      |    E
    require 目标文件不存在     |    E      |      E      |    E
    引用大小写不一致           |    I      |      E      |    E
    goto / ::label::           |    I      |      I      |    E
    位运算/整除 // 等 5.3 语法 |    I      |      I      |    E
    loadstring/setfenv/...     |    W      |      W      |    I
    (5.1 API，Lua 5.4 已移除)  |           |             |
    动态 require 无法确认      |    I      |      W      |    W
    外部 C/内置模块            |    I      |      I      |    I

用法 / Usage:
    python check_compat.py [项目目录] [--strict 1|2|3] [--all]
    python check_compat.py --strict 3      # 按 love.js 最严格检查（默认项目根）
    python check_compat.py D:/mygame --strict 1
    python check_compat.py --all           # 三种严格度全部输出对比

注意 / Caveat:
    这是"静态检查"，不可能 100% 替代真实运行；它专注于能可靠判定的
    跨平台雷区（大小写、语法版本差异、模块是否缺失、基础语法合法性）。
"""

import os
import re
import sys
import json
import argparse
import posixpath

# ---------------------------------------------------------------------------
# 基本常量
# ---------------------------------------------------------------------------

APP_VERSION = "1.0.0"

STRICT_PROFILES = {
    1: "Windows 开发端 (LÖVE 12 / Lua 5.4, 大小写不敏感)",
    2: "exe 发布 / Linux 等 (大小写敏感)",
    3: "love.js (LuaJIT / Lua 5.1, 大小写敏感, 最严格)",
}

E, W, I = "error", "warning", "info"
SEV_LABEL = {"error": "[错误]", "warning": "[警告]", "info": "[提示]"}

# 每个检测类别在 1/2/3 严格度下的严重性
SEV_MATRIX = {
    "bom":                (E, E, E),   # UTF-8 BOM 会让 Lua 加载器报错
    "encoding":           (W, W, W),   # 非 UTF-8 编码
    "unclosed_comment":   (E, E, E),   # 长注释未闭合
    "unclosed_string":    (E, E, E),   # 字符串未闭合
    "bracket_mismatch":   (E, E, E),   # 括号不配对
    "bad_token":          (E, E, E),   # 无法识别的字符
    "missing_module":     (E, E, E),   # require/ImportFile 目标不存在
    "shader_missing":     (E, E, E),   # ImportFile("..","shader") 目标不存在
    "case_mismatch":      (I, E, E),   # 引用与磁盘大小写不一致
    "goto_statement":     (I, I, E),   # goto（Lua 5.2+）
    "label_5_2":          (I, I, E),   # ::label::（Lua 5.2+）
    "op_5_3":             (I, I, E),   # // << >> & | ~ 位运算/整除
    "binary_literal_5_3": (I, I, E),   # 0b 二进制字面量
    "external_module":    (I, I, I),   # require 到 C/内置模块
    "dynamic_require":    (I, W, W),   # 动态 require，静态无法确认
    "dynamic_import":     (I, W, W),   # 动态 ImportFile
    "api_5_1_removed":    (W, W, I),   # loadstring/setfenv/getfenv 等
    "os_popen":           (I, I, W),   # io.popen / os.execute 在 love.js 受限
}

BUILTIN_STD_MODULES = {
    "string", "table", "math", "io", "os", "coroutine",
    "package", "debug", "utf8",
}
# LÖVE/LuaJIT 运行时直接提供（love 一定在；ffi/bit/bit32 仅 LuaJIT/Lua 5.1 有）
EXTERNAL_RUNTIME_MODULES = {"love", "ffi", "bit", "bit32", "jit"}
# 第三方 C 扩展/外部模块：只有随 .love 一起打包才可用
EXTERNAL_THIRD_PARTY = {
    "enet", "lpeg", "socket", "ssl", "http", "cjson", "lfs",
    "sqlite3", "openssl", "zlib", "luasec", "bit64",
}
EXTERNAL_MODULES = EXTERNAL_RUNTIME_MODULES | EXTERNAL_THIRD_PARTY

EXCLUDED_DIR_NAMES = {
    ".git", ".svn", ".hg", ".idea", ".vscode", "__pycache__",
    "node_modules", ".cache", ".gradle", "Export", "love-android",
    "Packager", "Documentation",
}
LUA_SUFFIX = ".lua"

# ---------------------------------------------------------------------------
# 词法器
# ---------------------------------------------------------------------------

LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
}
# 按长度降序排列，保证最长匹配（... 先于 .. 先于 .）
SYMBOLS = [
    "...", "==", "~=", "<=", ">=", "<<", ">>", "//", "::", "..",
    "+", "-", "*", "/", "%", "^", "#", "&", "~", "|", "<", ">", "=",
    "(", ")", "{", "}", "[", "]", ";", ":", ",", ".",
]

OPEN_BRACKETS = {"(": ")", "[": "]", "{": "}"}
CLOSE_BRACKETS = {")": "(", "]": "[", "}": "{"}

# Lua 5.2+ / 5.3+ 语法（在 LuaJIT/5.1 下编译失败）
TOKEN_5_2 = {"::"}
TOKEN_5_3 = {"//", "<<", ">>", "&", "|", "~"}

# 在 Lua 5.1 存在、Lua 5.2+ 被移除的全局 API
API_REMOVED_5_1 = {"loadstring", "setfenv", "getfenv"}


class Token(object):
    """简化 token：kind in name/keyword/number/string/longstring/symbol"""
    __slots__ = ("kind", "value", "line")

    def __init__(self, kind, value, line):
        self.kind = kind
        self.value = value
        self.line = line

    def __repr__(self):  # pragma: no cover - 调试用
        return "Token(%s,%r,%d)" % (self.kind, self.value, self.line)


def _count_long_open(text, i):
    """若 text[i:] 以 '[[' 或 '[=*[' 开头，返回 (level, 内容起始索引)。
    否则返回 None。"""
    n = len(text)
    if i >= n or text[i] != "[":
        return None
    j = i + 1
    while j < n and text[j] == "=":
        j += 1
    if j < n and text[j] == "[":
        return j - i - 1, j + 1  # level, 内容起始
    return None


def _find_long_close(text, start, level):
    """从 start 开始找 ']' + '='*level + ']'，返回 (内容结束索引, 行数增量)。
    找不到返回 None。"""
    close = "]" + "=" * level + "]"
    idx = text.find(close, start)
    if idx < 0:
        return None
    return idx, text.count("\n", start, idx)


def tokenize(text):
    """把 Lua 源码切成 token，并返回 (tokens, lex_issues)。
    lex_issues 每一项为 (line, category, message)。字符串/注释均已跳过，
    所以后续的括号配对可以放心基于 token 判断。"""
    tokens = []
    issues = []
    n = len(text)
    i = 0
    line = 1

    def newline_count(seg):
        return seg.count("\n")

    while i < n:
        ch = text[i]

        # ---- 空白 ----
        if ch in " \t\r\n\f\v":
            if ch == "\n":
                line += 1
            i += 1
            continue

        # ---- 注释 ----
        if ch == "-" and i + 1 < n and text[i + 1] == "-":
            # 长注释 --[[ ]] / --[=[ ]=]
            lvl = _count_long_open(text, i + 2)
            if lvl is not None:
                level, content_start = lvl
                res = _find_long_close(text, content_start, level)
                if res is None:
                    issues.append((line, "unclosed_comment",
                                   "长注释未闭合（缺少 ]%s]）" % ("=" * level)))
                    break
                close_idx, linc = res
                line += linc
                i = close_idx + 2 + level
            else:
                # 行注释
                nl = text.find("\n", i)
                if nl < 0:
                    break
                line += 1
                i = nl + 1
            continue

        # ---- 长字符串 [==[ ... ]==] ----
        if ch == "[":
            lvl = _count_long_open(text, i)
            if lvl is not None:
                level, content_start = lvl
                res = _find_long_close(text, content_start, level)
                if res is None:
                    issues.append((line, "unclosed_string",
                                   "长字符串未闭合（缺少 ]%s]）" % ("=" * level)))
                    break
                close_idx, linc = res
                value = text[content_start:close_idx]
                tokens.append(Token("longstring", value, line))
                line += linc + value.count("\n")
                i = close_idx + 2 + level
                continue

        # ---- 短字符串 ----
        if ch in "'\"":
            quote = ch
            j = i + 1
            closed = False
            while j < n:
                c = text[j]
                if c == "\\":
                    # 转义：跳过下一个字符（含 \ 换行 续行）
                    j += 2
                    if j - 1 < n and text[j - 1] == "\n":
                        line += 1
                    continue
                if c == quote:
                    closed = True
                    break
                if c == "\n":
                    break  # Lua 短字符串不允许裸换行
                j += 1
            if not closed:
                issues.append((line, "unclosed_string",
                               "字符串未闭合（从 %s 开始）" % quote))
                # 从换行处继续，避免连锁误报
                nl = text.find("\n", i)
                if nl < 0:
                    break
                line += 1
                i = nl + 1
                continue
            value = text[i + 1:j]
            tokens.append(Token("string", value, line))
            line += value.count("\n")  # 转义续行可能跨行
            i = j + 1
            continue

        # ---- 数字 ----
        if ch.isdigit() or (ch == "." and i + 1 < n and text[i + 1].isdigit()):
            j = i
            if ch == "0" and i + 1 < n and text[i + 1] in "xX":
                j = i + 2
                while j < n and (text[j].isdigit()
                                 or text[j] in "abcdefABCDEF"):
                    j += 1
            else:
                while j < n and (text[j].isdigit() or text[j] in "._"):
                    j += 1  # 容忍 a..b 被拆开的情况
                # 重新收紧：数字只允许到小数/指数之前
                j = _end_number(text, i)
            raw = text[i:j]
            tokens.append(Token("number", raw, line))
            if j < n and raw.lower().startswith("0b"):
                tokens[-1].value = raw  # 标记二进制字面量（分类另算）
            i = j
            continue

        # ---- 标识符 / 关键字 ----
        if ch.isalpha() or ch == "_":
            j = i
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            word = text[i:j]
            if word in LUA_KEYWORDS:
                tokens.append(Token("keyword", word, line))
            else:
                tokens.append(Token("name", word, line))
            i = j
            continue

        # ---- 符号（最长匹配）----
        matched = False
        for sym in SYMBOLS:
            if text.startswith(sym, i):
                tokens.append(Token("symbol", sym, line))
                i += len(sym)
                matched = True
                break
        if matched:
            continue

        # ---- 其它字符 ----
        issues.append((line, "bad_token",
                       "无法识别的字符 %r（常见：全角符号/残留乱码）" % ch))
        i += 1

    return tokens, issues


def _end_number(text, start):
    """返回数字字面量结束索引（粗略）。"""
    n = len(text)
    i = start
    if text[i] == "0" and i + 1 < n and text[i + 1] in "xX":
        i += 2
        while i < n and (text[i].isdigit() or text[i] in "abcdefABCDEF"):
            i += 1
        return i
    if text[i] == "0" and i + 1 < n and text[i + 1] in "bB":
        i += 2
        while i < n and text[i] in "01":
            i += 1
        return i
    while i < n and (text[i].isdigit() or text[i] == "."):
        i += 1
    if i < n and text[i] in "eE":
        j = i + 1
        if j < n and text[j] in "+-":
            j += 1
        if j < n and text[j].isdigit():
            while j < n and (text[j].isdigit() or text[j] == "."):
                j += 1
            i = j
    return i


# ---------------------------------------------------------------------------
# 文件收集 / 大小写敏感的文件系统探测
# ---------------------------------------------------------------------------

def collect_lua_files(root):
    """递归收集 root 下所有 .lua 文件（相对 POSIX 路径），跳过常见工具目录。"""
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames
                             if d not in EXCLUDED_DIR_NAMES)
        for fn in filenames:
            if fn.lower().endswith(LUA_SUFFIX):
                rel = os.path.relpath(os.path.join(dirpath, fn), root)
                out.append(rel.replace(os.sep, "/"))
    return sorted(out)


class CaseIndex(object):
    """带缓存的大小写敏感目录查询：用于发现"引用与磁盘大小写不一致"。"""

    def __init__(self, root):
        self.root = root
        self._cache = {}  # 目录绝对路径 -> {小写名: 真实名}

    def _list(self, abs_dir):
        """返回 {lowername: realname}（文件与目录都包含），目录缺失返回 None。"""
        if abs_dir in self._cache:
            return self._cache[abs_dir]
        try:
            names = os.listdir(abs_dir)
        except OSError:
            self._cache[abs_dir] = None
            return None
        mapping = {}
        for nm in names:
            mapping.setdefault(nm.lower(), nm)
        self._cache[abs_dir] = mapping
        return mapping

    def locate(self, rel_path):
        """按大小写敏感的方式在磁盘上找 rel_path（POSIX 形式）。
        返回 (exact, real_rel_path)；找不到返回 None。
        exact=False 表示每一级都命中但存在大小写差异。"""
        parts = [p for p in rel_path.split("/") if p]
        if not parts:
            return None
        cur = self.root
        real_parts = []
        exact = True
        for idx, comp in enumerate(parts):
            mapping = self._list(cur)
            if mapping is None:
                return None
            real = mapping.get(comp.lower())
            if real is None:
                return None
            if real != comp:
                exact = False
            real_parts.append(real)
            if idx != len(parts) - 1:
                cur = os.path.join(cur, real)
        return (exact, "/".join(real_parts))


# ---------------------------------------------------------------------------
# 模块解析
# ---------------------------------------------------------------------------

def module_identity(rel_path):
    """由磁盘路径推出"规范模块名"（LÖVE 从项目根 require 时的名字）。
    Scripts/Libraries/Battle/init.lua -> Scripts.Libraries.Battle
    Scripts/Libraries/Overworld/map.lua -> Scripts.Libraries.Overworld.map
    main.lua / conf.lua -> None（入口文件，无模块名）"""
    base = os.path.basename(rel_path)
    if base == "main.lua" or base == "conf.lua":
        return None
    if base == "init.lua":
        comps = posixpath.dirname(rel_path).split("/")
        return ".".join(c for c in comps if c)
    comps = rel_path[:-len(LUA_SUFFIX)].split("/")
    return ".".join(comps)


def resolve_module(cidx, module_name):
    """把一个模块名映射回磁盘。返回 dict:
      state: ok | case | missing | external
      path : 命中文件(相对路径) | None
    require 语义：先找 <路径>.lua，再找 <路径>/init.lua。"""
    comps = [c for c in module_name.split(".") if c]
    if not comps:
        return {"state": "missing", "path": None}
    base = "/".join(comps)

    for suffix, is_dir in ((".lua", False), ("/init.lua", True)):
        found = cidx.locate(base + suffix)
        if found:
            exact, real = found
            return {"state": "ok" if exact else "case", "path": real}
    return {"state": "missing", "path": None}


# ---------------------------------------------------------------------------
# require / ImportFile 调用解析
# ---------------------------------------------------------------------------

def _match_closing(tokens, open_index):
    """从 open_index（应为 '('）找到匹配的 ')' 索引。找不到返回 None。"""
    depth = 0
    for j in range(open_index, len(tokens)):
        t = tokens[j]
        if t.kind == "symbol":
            if t.value in "([{":
                depth += 1
            elif t.value in ")]}":
                depth -= 1
                if depth == 0:
                    return j
    return None


def _top_level_split(tokens, target):
    """在括号深度 0 处按 target 符号拆分 token 子列表。"""
    depth = 0
    segs = []
    cur = []
    for t in tokens:
        if t.kind == "symbol":
            v = t.value
            if v in "([{":
                depth += 1
            elif v in ")]}":
                depth -= 1
            elif v == target and depth == 0:
                if cur:
                    segs.append(cur)
                    cur = []
                continue
        cur.append(t)
    if cur:
        segs.append(cur)
    return segs


def _is_vararg_group(ts):
    return (len(ts) == 3 and ts[0].kind == "symbol" and ts[0].value == "("
            and ts[1].kind == "symbol" and ts[1].value == "..."
            and ts[2].kind == "symbol" and ts[2].value == ")")


def _find_top_level_colon_method(ts):
    """寻找顶层 ':' + NAME + '(' 结构，返回 ':' 的索引。"""
    depth = 0
    for idx in range(len(ts)):
        t = ts[idx]
        if t.kind == "symbol":
            if t.value in "([{":
                depth += 1
                continue
            if t.value in ")]}":
                depth -= 1
                continue
            if t.value == ":" and depth == 0 and idx + 2 < len(ts):
                if (ts[idx + 1].kind == "name"
                        and ts[idx + 2].kind == "symbol"
                        and ts[idx + 2].value == "("):
                    return idx
    return None


def _lua_pattern_simple(pattern):
    """把"简单的 Lua pattern"转成 Python 可用的字面替换逻辑。
    只支持：纯文本 + %x 转义 + ^/$ 锚点；遇到字符类等返回 None。"""
    if not pattern:
        return {"prefix": "", "suffix": "", "literal": ""}
    out = []
    anchor_start = pattern.startswith("^")
    anchor_end = pattern.endswith("$")
    body = pattern[1:] if anchor_start else pattern
    body = body[:-1] if anchor_end else body
    i = 0
    while i < len(body):
        c = body[i]
        if c == "%":
            if i + 1 >= len(body):
                return None
            nxt = body[i + 1]
            if nxt.isalpha():
                return None  # %a %d 等字符类，不处理
            out.append(nxt)  # %x -> 字面量 x
            i += 2
        elif c in "*+?[]()|-":
            return None  # 真正的魔法字符（. 除外）
        else:
            # 注意：模块名替换惯用法里写的是 'plugins.box2d'，
            # 虽然 Lua 中裸 '.' 是"任意字符"，但这里按字面点号处理更实用。
            out.append(c)
            i += 1
    return {"prefix": "" if anchor_start else None,
            "suffix": "" if anchor_end else None,
            "literal": "".join(out)}


def _try_lua_gsub(s, pattern, repl):
    spec = _lua_pattern_simple(pattern)
    if spec is None:
        return None
    lit = spec["literal"]
    pos = s.find(lit)
    if pos < 0:
        return s
    # 处理锚点：若带 ^ 而字符串不以之开头则不替换；若带 $ 而在末尾才替换
    if spec["prefix"] is not None and pos != 0:
        return s
    if spec["suffix"] is not None and pos + len(lit) != len(s):
        return s
    return s[:pos] + repl + s[pos + len(lit):]


def _fold_args(tokens, ctx):
    """把 require/ImportFile 的实参 token 列表折叠成一个字符串。
    ctx = {module, vars}。无法静态求值返回 None。"""
    # 去掉可能整体包裹的最外层括号
    while (len(tokens) >= 2 and tokens[0].kind == "symbol"
           and tokens[0].value == "("
           and tokens[-1].kind == "symbol"
           and tokens[-1].value == ")"):
        inner = tokens[1:-1]
        # 确保成对（粗略）
        if _match_closing(tokens, 0) == len(tokens) - 1:
            tokens = inner
        else:
            break

    segs = _top_level_split(tokens, "..")
    if len(segs) > 1:
        vals = []
        for s in segs:
            v = _fold_unit(s, ctx)
            if v is None:
                return None
            vals.append(v)
        return "".join(vals)
    return _fold_unit(tokens, ctx)


def _fold_unit(ts, ctx):
    if not ts:
        return None
    t0 = ts[0]
    if len(ts) == 1:
        if t0.kind in ("string", "longstring"):
            return t0.value
        if t0.kind == "name":
            return ctx.get("vars", {}).get(t0.value)
        if t0.kind == "symbol" and t0.value == "...":
            return ctx.get("module")  # 可能 None
        return None

    # vararg 上的方法调用： ( ... ) : gsub ( A , B )
    cm = _find_top_level_colon_method(ts)
    if cm is not None:
        recv = ts[:cm]
        mname = ts[cm + 1].value
        open_p = cm + 2
        close_p = _match_closing(ts, open_p)
        if close_p is None:
            return None
        arg_ts = ts[open_p + 1:close_p]
        # 把参数按逗号拆开（顶层）
        arg_segs = _top_level_split(arg_ts, ",")
        if _is_vararg_group(recv):
            base = ctx.get("module")
        else:
            base = _fold_unit(recv, ctx)
        if base is None:
            return None
        if mname == "gsub":
            if len(arg_segs) == 2:
                pat = _fold_unit(arg_segs[0], ctx)
                rep = _fold_unit(arg_segs[1], ctx)
                if pat is None or rep is None:
                    return None
                return _try_lua_gsub(base, pat, rep)
        return None
    return None


# ---------------------------------------------------------------------------
# 模块前缀变量解释器
# 常见惯用写法（用于文件内"相对 require"）：
#   local path = (...):match("(.-)[^%.]+$")
#   local cwd  = (...):gsub('%.init$','') .. "."
#   local _p   = (...):match("(.-)[^%.]+$")
#   local path = _p .. "ShaderToy."
# 这里按行解析这些 local 赋值（RHS 只含字符串字面量、(...)、以及已绑定变量
# 的 .. 拼接），做不动点迭代直到不再产生新值。
# ---------------------------------------------------------------------------

_RE_LOCAL_ASSIGN = re.compile(r"^\s*local\s+([A-Za-z_]\w*)\s*=\s*(.+?)\s*$")

_RE_STR = re.compile(r'^(["\'])(.*)\1$', re.S)
_RE_LONG_STR = re.compile(r"^\[(=*)\[(.*?)\]\1\]$", re.S)


def _split_lua_concat(rhs):
    """在引号/长括号之外按 '..' 拆分表达式，返回各段字符串。"""
    segs = []
    buf = []
    i, n = 0, len(rhs)
    while i < n:
        c = rhs[i]
        if c in "'\"":
            j = i + 1
            while j < n and rhs[j] != c:
                if rhs[j] == "\\":
                    j += 2
                    continue
                j += 1
            buf.append(rhs[i:j + 1])
            i = j + 1
            continue
        if c == "[":
            # 长括号 [==[ ... ]==]（作为字面量整体）
            lvl = _count_long_open(rhs, i)
            if lvl is not None:
                level, _ = lvl
                close = "]%s]" % ("=" * level)
                j = rhs.find(close, i)
                if j < 0:
                    buf.append(rhs[i:])
                    i = n
                    continue
                buf.append(rhs[i:j + len(close)])
                i = j + len(close)
                continue
        if c == "." and i + 1 < n and rhs[i + 1] == ".":
            # ... 是变长参数（vararg），不是拼接
            if i + 2 < n and rhs[i + 2] == ".":
                buf.append("...")
                i += 3
                continue
            # .. 才是字符串拼接
            segs.append("".join(buf).strip())
            buf = []
            i += 2
            continue
        buf.append(c)
        i += 1
    if buf:
        segs.append("".join(buf).strip())
    return segs


def _literal_value(seg):
    """尝试把一段转成字符串字面量，失败返回 (False, None)。"""
    seg = seg.strip()
    m = _RE_STR.match(seg)
    if m and seg[0] == seg[-1]:
        return True, m.group(2)
    m = _RE_LONG_STR.match(seg)
    if m:
        return True, m.group(2)
    return False, None


def _dir_prefix(module_name):
    """'A.B.C' -> 'A.B.'（(...):match("(.-)[^%.]+$") 的语义）"""
    if not module_name:
        return None
    parts = module_name.split(".")
    if len(parts) <= 1:
        return ""
    return ".".join(parts[:-1]) + "."


def _scan_method_args(seg):
    """若 seg 形如 '(...):match(...)' / '(...):gsub(a, b)'，
    返回 (method, [arg1, arg2, ...])；否则返回 None。
    手动扫描以正确处理字符串/长字符串里的括号与逗号。"""
    s = seg.strip()
    if not s.startswith("(...):"):
        return None
    rest = s[len("(...):"):]
    j = 0
    while j < len(rest) and (rest[j].isalnum() or rest[j] == "_"):
        j += 1
    method = rest[:j]
    if not method or j >= len(rest) or rest[j] != "(":
        return None
    i = j + 1
    depth = 1
    args = []
    buf = []
    quote = None
    while i < len(rest):
        c = rest[i]
        if quote is not None:
            if c == "\\" and i + 1 < len(rest):
                buf.append(c)
                buf.append(rest[i + 1])
                i += 2
                continue
            if c == quote:
                quote = None
            buf.append(c)
            i += 1
            continue
        if c in "'\"":
            quote = c
            buf.append(c)
            i += 1
            continue
        if c == "[":
            lvl = _count_long_open(rest, i)
            if lvl is not None:
                level, _ = lvl
                close = "]" + "=" * level + "]"
                k = rest.find(close, i)
                if k < 0:
                    return None
                buf.append(rest[i:k + len(close)])
                i = k + len(close)
                continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                args.append("".join(buf).strip())
                if quote is not None:
                    return None
                return (method, args)
        elif c == "," and depth == 1:
            args.append("".join(buf).strip())
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    return None


def _eval_vararg_method(seg, module):
    """求值 (...):match('..') -> 去掉最后一节的目录前缀；
        (...):gsub('a','b') -> 替换后的模块名。失败返回 None。"""
    if not module:
        return None
    res = _scan_method_args(seg)
    if not res:
        return None
    method, args = res
    if method == "match":
        return _dir_prefix(module)
    if method == "gsub" and len(args) >= 2:
        okp, pat = _literal_value(args[0])
        okr, rep = _literal_value(args[1])
        if okp and okr:
            return _try_lua_gsub(module, pat, rep)
    return None


def _collect_module_vars(text, module):
    """返回 {变量名: 前缀字符串}，近似文件内 '模块相对路径前缀' 的取值。"""
    out = {}

    def solve_seg(seg):
        seg = seg.strip()
        ok, val = _literal_value(seg)
        if ok:
            return val
        if seg == "(...)":
            return module  # 可能是 None
        if re.fullmatch(r"[A-Za-z_]\w*", seg):
            return out.get(seg)
        return _eval_vararg_method(seg, module)

    lines = text.splitlines()
    # 反复扫描直到没有新变量可解（支持链条绑定）
    changed = True
    passes = 0
    while changed and passes < 10:
        changed = False
        passes += 1
        for ln in lines:
            m = _RE_LOCAL_ASSIGN.match(ln)
            if not m:
                continue
            name, rhs = m.group(1), m.group(2)
            if name in out:
                continue
            if "--" in rhs:  # 粗去行注释
                rhs = rhs.split("--", 1)[0].rstrip()
            parts = _split_lua_concat(rhs)
            if not parts:
                continue
            vals = []
            solvable = True
            for seg in parts:
                v = solve_seg(seg)
                if v is None:
                    solvable = False
                    break
                vals.append(v)
            if solvable:
                out[name] = "".join(vals)
                changed = True
    return out


# ---------------------------------------------------------------------------
# 单文件分析
# ---------------------------------------------------------------------------

class FileReport(object):
    def __init__(self, rel):
        self.rel = rel
        self.issues = []

    def add(self, line, category, message, extra=None):
        self.issues.append({
            "file": self.rel,
            "line": line,
            "category": category,
            "message": message,
            "extra": extra or "",
        })


def analyze_file(root, rel, cidx):
    """分析单个 Lua 文件，返回 FileReport。"""
    rep = FileReport(rel)
    abs_path = os.path.join(root, rel.replace("/", os.sep))

    try:
        with open(abs_path, "rb") as f:
            raw = f.read()
    except OSError as exc:
        rep.add(1, "encoding", "无法读取文件: %s" % exc)
        return rep

    # ---- BOM / 编码 ----
    if raw.startswith(b"\xef\xbb\xbf"):
        rep.add(1, "bom", "文件以 UTF-8 BOM 开头，Lua 加载器会报 "
                           "'unexpected symbol near'。建议用无 BOM 保存。")
        raw = raw[3:]
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        text = raw.decode("utf-8", errors="replace")
        rep.add(1, "encoding", "不是有效的 UTF-8 文本（可能有 GBK 等编码内容），"
                               "跨平台时建议统一为 UTF-8（注释/字符串内通常无害）。")

    # ---- 词法 ----
    tokens, lex_issues = tokenize(text)
    for line, cat, msg in lex_issues:
        rep.add(line, cat, msg)

    # ---- 括号配对 ----
    stack = []
    for t in tokens:
        if t.kind == "symbol":
            v = t.value
            if v in OPEN_BRACKETS:
                stack.append((v, t.line))
            elif v in CLOSE_BRACKETS:
                if not stack:
                    rep.add(t.line, "bracket_mismatch",
                            "多余的闭合括号 %r" % v)
                elif stack[-1][0] != CLOSE_BRACKETS[v]:
                    rep.add(t.line, "bracket_mismatch",
                            "括号不配对：%r 闭合了 %s（第 %d 行）"
                            % (v, OPEN_BRACKETS[stack[-1][0]], stack[-1][1]))
                    stack.pop()
                else:
                    stack.pop()
    for v, ln in stack:
        rep.add(ln, "bracket_mismatch",
                "括号 %r 未闭合" % v)

    # ---- Lua 版本敏感语法扫描 ----
    for t in tokens:
        if t.kind == "keyword" and t.value == "goto":
            rep.add(t.line, "goto_statement",
                    "使用了 goto（Lua 5.2+ 语法，LuaJIT/Lua 5.1 会编译失败）")
        if t.kind == "symbol":
            if t.value == "::":
                rep.add(t.line, "label_5_2",
                        "使用了 ::label::（Lua 5.2+ 语法，LuaJIT/Lua 5.1 不支持）")
            elif t.value in TOKEN_5_3:
                rep.add(t.line, "op_5_3",
                        "使用了运算符 %r（Lua 5.3+，LuaJIT/Lua 5.1 不支持）" % t.value)
        if t.kind == "number" and t.value.lower().startswith("0b"):
            rep.add(t.line, "binary_literal_5_3",
                    "使用了 0b 二进制字面量（Lua 5.3+）")

    # ---- 5.1 专属 API（Lua 5.4 移除）----
    for idx, t in enumerate(tokens):
        if (t.kind == "name" and t.value in API_REMOVED_5_1
                and idx + 1 < len(tokens)
                and tokens[idx + 1].kind == "symbol"
                and tokens[idx + 1].value == "("):
            rep.add(t.line, "api_5_1_removed",
                    "%s 是 Lua 5.1 专属 API，在 Lua 5.2+（含 LÖVE 12）已被移除，"
                    "调用时会报 nil" % t.value)

    # ---- io.popen / os.execute（love.js 受限）----
    for idx in range(len(tokens) - 1):
        a, b = tokens[idx], tokens[idx + 1]
        if (a.kind == "name" and b.kind == "symbol" and b.value == "."
                and idx + 2 < len(tokens)
                and tokens[idx + 2].kind == "name"):
            if a.value == "io" and tokens[idx + 2].value == "popen":
                rep.add(a.line, "os_popen",
                        "io.popen 在 love.js 中不可用（会报 nil 或挂起）")
            if a.value == "os" and tokens[idx + 2].value in ("execute", "remove"):
                rep.add(a.line, "os_popen",
                        "os.%s 在 love.js 中受限/不可用" % tokens[idx + 2].value)

    # ---- 模块身份与相对路径变量绑定 ----
    module = module_identity(rel)
    ctx_vars = _collect_module_vars(text, module)
    ctx = {"module": module, "vars": ctx_vars}

    # ---- 扫描 require / ImportFile 调用 ----
    _scan_calls(rep, tokens, cidx, ctx)
    return rep


def _scan_calls(rep, tokens, cidx, ctx):
    n = len(tokens)
    for idx in range(n):
        t = tokens[idx]
        if t.kind != "name":
            continue
        # 防止把 require.foo / ImportFilex 之类误判
        nxt = tokens[idx + 1] if idx + 1 < n else None
        if t.value == "require" and nxt and nxt.kind == "symbol":
            if nxt.value == "(":
                close = _match_closing(tokens, idx + 1)
                if close is None:
                    return
                args = tokens[idx + 2:close]
                _handle_require(rep, t.line, args, cidx, ctx)
            elif nxt.value in (":", "."):
                pass  # require 的字段/方法，不算加载
            elif nxt.kind in ("string", "longstring"):
                _handle_require(rep, t.line, [nxt], cidx, ctx)
            # 其它（如 local require = require）忽略
        elif t.value == "ImportFile" and nxt and nxt.kind == "symbol" \
                and nxt.value == "(":
            # "function ImportFile(...)" 是定义而非调用，跳过
            if idx > 0 and tokens[idx - 1].kind == "keyword" \
                    and tokens[idx - 1].value == "function":
                continue
            close = _match_closing(tokens, idx + 1)
            if close is None:
                return
            args = tokens[idx + 2:close]
            _handle_import(rep, t.line, args, cidx, ctx)


def _handle_require(rep, line, args, cidx, ctx):
    if not args:
        rep.add(line, "dynamic_require", "require() 缺少参数？")
        return
    name = _fold_args(args, ctx)
    if name is None or not name:
        rep.add(line, "dynamic_require",
                "动态 require，无法静态确认目标模块（可能是运行时变量）")
        return
    name = name.strip()
    if not name:
        rep.add(line, "dynamic_require", "require 目标为空字符串？")
        return
    if name in BUILTIN_STD_MODULES:
        return  # 标准库，安全
    if name in EXTERNAL_RUNTIME_MODULES:
        # love 由 LÖVE 提供；ffi/bit/bit32 仅 LuaJIT（love.js / LÖVE 11）提供
        rep.add(line, "external_module",
                "require 到运行时模块 '%s'：love 由 LÖVE 提供；"
                "ffi/bit/bit32 只有 LuaJIT/Lua 5.1 才有（LÖVE 12 换成 Lua 5.4 后没有）"
                % name)
        return
    if name in EXTERNAL_THIRD_PARTY:
        rep.add(line, "external_module",
                "require 到第三方 C/外部模块 '%s'：必须随 .love 一起打包，"
                "否则运行时报 module not found" % name)
        return
    res = resolve_module(cidx, name)
    if res["state"] == "missing":
        rep.add(line, "missing_module",
                "require 目标模块不存在：'%s'（找不到 %s.lua 或 %s/init.lua）"
                % (name, name.replace(".", "/"), name.replace(".", "/")))
        return
    if res["state"] == "case":
        rep.add(line, "case_mismatch",
                "require 大小写与磁盘不一致：引用 '%s'，实际文件 '%s'"
                % (name, res["path"]))


def _handle_import(rep, line, args, cidx, ctx):
    if not args:
        return
    # 按顶层逗号把实参拆成多段（第一段是路径，第二段是类型）
    segs = _top_level_split(args, ",")
    # 第一个参数（整个表达式都要折叠，如 "A.B." .. var）
    first = _fold_args(segs[0], ctx) if segs else None
    # 第二个参数：类型（字面量字符串）
    itype = ""
    if len(segs) >= 2:
        tv = _fold_args(segs[1], ctx)
        if tv:
            itype = tv.strip().lower()
    if first is None:
        rep.add(line, "dynamic_import",
                "ImportFile 使用动态路径，无法静态确认目标")
        return
    path = first.strip()
    if not path:
        rep.add(line, "dynamic_import", "ImportFile 路径为空？")
        return

    # DLL / .so 处理：PathDefiner 里命中扩展名就走动态库
    if re.search(r"\.(dll|so|dylib)$", path, re.IGNORECASE):
        rep.add(line, "external_module",
                "ImportFile 加载动态库 '%s'：需确认该平台存在对应文件"
                % path)
        return
    if itype == "dll":
        rep.add(line, "external_module",
                "ImportFile(type='dll') 加载 '%s'：需确认运行平台有该库" % path)
        return

    # shader 类型：找 Scripts/Shaders/<path 斜杠化>.glsl
    if itype == "shader":
        rel = "Scripts/Shaders/" + path.replace(".", "/")
        for candidate in (rel + ".glsl", rel + ".lua"):
            found = cidx.locate(candidate)
            if found:
                if not found[0]:
                    rep.add(line, "case_mismatch",
                            "shader 大小写与磁盘不一致：引用 '%s'，实际 '%s'"
                            % (path, found[1]))
                return
        rep.add(line, "shader_missing",
                "shader 文件不存在：'%s'（已查找 Scripts/Shaders/ 下 .glsl/.lua）"
                % path)
        return

    # 默认 / lua：模块 = Scripts.Libraries. + path
    # 注意 PathDefiner 会先把 / 和 \ 归一化为点
    norm = path.replace("/", ".").replace("\\", ".")
    module_name = "Scripts.Libraries." + norm
    res = resolve_module(cidx, module_name)
    if res["state"] == "external":
        rep.add(line, "external_module",
                "ImportFile 指向外部/C 模块 '%s'" % module_name)
        return
    if res["state"] == "missing":
        rep.add(line, "missing_module",
                "ImportFile 目标不存在：'%s'（实际会 require %s，找不到对应文件）"
                % (path, module_name))
        return
    if res["state"] == "case":
        rep.add(line, "case_mismatch",
                "ImportFile 大小写与磁盘不一致：引用 '%s'，实际文件 '%s'"
                % (path, res["path"]))


# ---------------------------------------------------------------------------
# 输出
# ---------------------------------------------------------------------------

def sev_for(category, strict):
    return SEV_MATRIX.get(category, (I, I, I))[strict - 1]


def run_check(root, strict):
    """对项目执行一次指定严格度的检查，返回 (issues, file_count)。"""
    if not os.path.isdir(root):
        raise SystemExit("项目目录不存在: %s" % root)
    if not os.path.isfile(os.path.join(root, "main.lua")):
        print("警告: 目录中没有 main.lua，可能不是游戏根目录：%s" % root)

    cidx = CaseIndex(root)
    files = collect_lua_files(root)
    issues = []
    for rel in files:
        rep = analyze_file(root, rel, cidx)
        issues.extend(rep.issues)

    # 按当前严格度映射严重性
    for it in issues:
        it["sev"] = sev_for(it["category"], strict)
    return issues, len(files)


def _print_report(root, strict, issues, file_count):
    errors = [i for i in issues if i["sev"] == E]
    warns = [i for i in issues if i["sev"] == W]
    infos = [i for i in issues if i["sev"] == I]

    print("=" * 72)
    print(" Lua 跨平台兼容检查 (check_compat.py v%s)" % APP_VERSION)
    print("=" * 72)
    print("项目目录 : %s" % root)
    print("Lua 文件 : %d 个" % file_count)
    print("严格度   : %d - %s" % (strict, STRICT_PROFILES[strict]))

    def _dump(title, lst, show_all):
        if not lst:
            return
        print("-" * 72)
        print("%s %s" % (title, len(lst)))
        print("-" * 72)
        shown = lst if show_all else lst[:MAX_SHOWN]
        for i in shown:
            line = "  行 %-5d " % i["line"] if i["line"] else "        "
            print("%s %s%s %s" % (SEV_LABEL[i["sev"]], line,
                                  i["file"], i["message"]))
        if not show_all and len(lst) > MAX_SHOWN:
            print("  …… 其余 %d 条略过（用 --all 查看全部）"
                  % (len(lst) - MAX_SHOWN))

    # 错误是阻断运行的核心信息，始终全量展示；warning/info 按需截断
    _dump("[错误 error] 会阻断运行的问题（共", errors, True)
    _dump("[警告 warning] 可能踩雷的问题（共", warns, True)
    _dump("[提示 info] 仅供参考（共", infos, False)

    print("-" * 72)
    if errors:
        print("结果 : ✗ 不通过 —— 严格度 %d (%s) 下有 %d 个会阻断运行的问题"
              % (strict, STRICT_PROFILES[strict], len(errors)))
        return 1
    print("结果 : ✓ 通过 —— 严格度 %d (%s) 下没有会阻断运行的问题"
          % (strict, STRICT_PROFILES[strict]))
    if warns:
        print("        （但有 %d 条警告，建议逐条确认）" % len(warns))
    return 0


MAX_SHOWN = 100


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="check_compat.py",
        description="Lua 跨平台兼容检查器：按严格度检查项目 Lua 文件是否能跑通。")
    ap.add_argument("project", nargs="?", default=None,
                    help="游戏项目根目录（含 main.lua）；默认取本脚本所在目录的上一级")
    ap.add_argument("--strict", type=int, choices=(1, 2, 3), default=3,
                    help="严格度: 1=Windows开发端 2=exe/Linux 3=love.js(默认)")
    ap.add_argument("--all", action="store_true",
                    help="一次性输出三种严格度的结论")
    ap.add_argument("--json", action="store_true",
                    help="以 JSON 输出原始问题（便于接入其它工具）")
    args = ap.parse_args(argv)

    root = args.project
    if root is None:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    root = os.path.abspath(root)

    # 让中文在 Windows 终端正常显示
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

    if args.json:
        strict = args.strict
        issues, count = run_check(root, strict)
        for it in issues:
            it.pop("sev", None)
        print(json.dumps({
            "root": root,
            "strict": strict,
            "file_count": count,
            "issues": issues,
        }, ensure_ascii=False, indent=2))
        return 0

    if args.all:
        any_fail = 0
        for strict in (1, 2, 3):
            issues, count = run_check(root, strict)
            rc = _print_report(root, strict, issues, count)
            print()
            any_fail = any_fail or rc
        return 1 if any_fail else 0

    issues, count = run_check(root, args.strict)
    return _print_report(root, args.strict, issues, count)


if __name__ == "__main__":
    sys.exit(main())
