# -*- coding: utf-8 -*-
"""
LÖVE Packager / LÖVE 打包工具
====================================================================

A small GUI (tkinter) tool to package a Love2D (LÖVE) project into:

  * .love                      - the game zip (loadable by LÖVE)
  * Windows .exe               - love.exe merged with the .love file
  * Android preparation files  - love-android template + game.love,
                                 ready to be built into an APK with Android Studio
  * love-js (Web)              - game.love + love.js web export
  * source backup zip          - full source backup

Safety note (important!)
------------------------
To avoid recursive packaging ("memory bomb"), the tool ALWAYS excludes:
  * its own script file,
  * its own folder (when it is inside the project),
  * the output directory,
  * existing *.love files (when the option is enabled, default on).
The output directory defaults to "<project>/Export" and is excluded
automatically, so the generated archives are never re-packaged into
themselves.

Requirements
------------
  * Python 3 (standard library only, tkinter is bundled with the
    official Windows installer)
  * To create an .exe : a local LÖVE installation (love.exe)
  * To create Android preparation files: the love-android template
    (https://github.com/love2d/love-android)
  * To run love-js: Node.js + the love.js package (optional)

Run:  python build_tool.py    (or double-click run.bat)
"""

import os
import re
import sys
import shlex
import shutil
import locale
import queue
import zipfile
import threading
import struct
import subprocess

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext

APP_VERSION = "1.0.0"
LANGUAGES = ("zh", "en")

DEFAULT_VCS_DIRS = {".git", ".svn", ".hg", ".idea", ".vscode",
                    "__pycache__", "node_modules", ".cache", ".gradle"}
DEFAULT_EXCLUDED_EXTS = ".love, .pyc, .pyo, .tmp, .bak"

# ---------------------------------------------------------------------------
# Localization (zh / en)
# ---------------------------------------------------------------------------

STRINGS = {
    "zh": {
        "app_title": "LÖVE 打包工具",
        "menu_language": "语言",
        "menu_lang_zh": "中文",
        "menu_lang_en": "English",
        "tip_text": "将 LÖVE 项目打包为 .love / .exe / Android 准备文件 / love-js。"
                    "会自动排除工具本身与输出目录，防止循环打包。",
        "section_project": "项目设置",
        "project_dir": "项目目录（包含 main.lua）:",
        "output_dir": "输出目录:",
        "project_name": "项目名称:",
        "browse": "浏览...",
        "section_targets": "导出目标",
        "target_love": "生成 .love 文件",
        "target_exe": "生成 Windows 可执行文件 (.exe)",
        "target_android": "生成 Android APK 构建准备文件",
        "target_web": "生成 love-js Web 导出",
        "target_source": "生成完整源码备份 (.zip)",
        "section_exports": "导出参数",
        "love_dir": "LÖVE 安装目录（含 love.exe）:",
        "rcedit": "rcedit 路径（可选，用于嵌入图标）:",
        "icon_file": "exe 图标 (.ico/.png)（可选）:",
        "android_template": "love-android 模板目录:",
        "lovejs_cmd": "love.js 命令（可选，如 npx love.js）:",
        "section_excludes": "排除设置（防止循环打包）",
        "excluded_exts": "排除的扩展名（逗号分隔）:",
        "exclude_tool": "排除打包工具文件夹本身",
        "exclude_out": "排除输出目录",
        "exclude_vcs": "排除 .git/.vscode/__pycache__ 等",
        "exclude_love": "排除已有的 *.love 文件",
        "exclude_doc": "排除 Documentation 文档文件夹",
        "action_build": "开始打包",
        "action_open_out": "打开输出目录",
        "log_title": "日志",
        "status_ready": "就绪",
        "status_building": "正在打包...",
        "status_done": "打包完成",
        "err_no_project": "请先选择项目目录。",
        "err_no_main": "项目目录中未找到 main.lua，请确认选择的是游戏根目录。",
        "err_no_output": "请先选择输出目录。",
        "err_no_name": "请输入项目名称。",
        "err_output_same": "输出目录不能与项目目录相同（否则会被全部排除，无法打包）。",
        "err_no_target": "请至少勾选一种导出目标。",
        "err_love_dir": "未找到 love.exe，请检查 LÖVE 安装目录。",
        "err_android_template": "未找到 love-android 模板目录或 app/src/main 结构。",
        "confirm_open_out": "打包完成！是否打开输出目录？",
        "msg_done": "所有导出任务已完成。",
        "msg_love_created": "已生成 .love 文件: {path}（{count} 个文件）",
        "msg_love_intermediate": "（已生成中间 .love 供其它导出使用: {path}）",
        "msg_skipped_doc": "已跳过 Documentation 文件夹。",
        "msg_exe_created": "已生成 Windows 可执行文件: {path}",
        "msg_dll_copied": "已复制 DLL: {name}",
        "msg_android_created": "已生成 Android 构建准备文件: {path}",
        "msg_android_hint": "提示: 用 Android Studio 打开该目录并构建 APK。",
        "msg_web_created": "已生成 love-js 导出准备文件: {path}",
        "msg_web_no_cmd": "未提供 love.js 命令，已仅复制 game.love，可手动运行 love.js。",
        "msg_web_cmd_error": "love.js 运行失败: {err}",
        "msg_source_created": "已生成源码备份: {path}",
        "msg_excluded_tool": "已排除工具目录: {path}",
        "msg_excluded_output": "已排除输出目录: {path}",
        "msg_icon_embedded": "已嵌入图标: {path}",
        "msg_icon_skipped": "未找到 rcedit，跳过图标嵌入（不影响运行）。",
        "err_rcedit": "rcedit 执行失败: {err}",
        "msg_icon_png_convert": "已将 PNG 转换为多尺寸 ICO: {path}",
        "msg_icon_png_no_pillow": "未安装 Pillow，无法自动把 PNG 转成 ICO。请安装 Pillow（pip install Pillow）或改用 .ico 图标。",
        "msg_icon_warn_small": "图标只有 {sizes}，尺寸过小，资源管理器大图标会模糊。建议使用含 16/32/48/256 的 .ico。",
        "msg_start": "===== 开始打包: {name} =====",
        "msg_err": "错误: {err}",
        "help_title": "帮助",
        "help_text": (
            "使用方法:\n"
            "1. 选择项目目录（包含 main.lua 的文件夹）。\n"
            "2. 选择输出目录（默认在项目内 Export 文件夹，会自动排除，避免循环打包）。\n"
            "3. 勾选需要的导出目标:\n"
            "   - .love: 直接生成游戏 zip。\n"
            "   - Windows .exe: 需本机安装 LÖVE，填写 love.exe 所在目录；\n"
            "     工具会把 love.exe 与 game.love 合并为独立 exe，并复制所需 DLL。\n"
            "   - Android: 需下载 love-android 模板\n"
            "     (https://github.com/love2d/love-android)；工具会把 game.love\n"
            "     放入 app/src/main/assets，之后用 Android Studio 构建 APK。\n"
            "   - love-js: 可填写 love.js 命令（如 npx love.js），\n"
            "     否则仅生成 game.love 与说明。\n"
            "4. 排除设置默认已排除工具本身、输出目录、*.love、.git 等，\n"
            "   防止循环打包（内存炸弹）。\n"
            "5. 点击“开始打包”。"
        ),
    },
    "en": {
        "app_title": "LÖVE Packager",
        "menu_language": "Language",
        "menu_lang_zh": "中文",
        "menu_lang_en": "English",
        "tip_text": "Package a LÖVE project into .love / .exe / Android prep / love-js. "
                    "The tool itself and the output folder are excluded automatically "
                    "to avoid recursive packaging.",
        "section_project": "Project Settings",
        "project_dir": "Project directory (contains main.lua):",
        "output_dir": "Output directory:",
        "project_name": "Project name:",
        "browse": "Browse...",
        "section_targets": "Export Targets",
        "target_love": "Create .love file",
        "target_exe": "Create Windows executable (.exe)",
        "target_android": "Create Android APK build preparation",
        "target_web": "Create love-js (Web) export",
        "target_source": "Create full source backup (.zip)",
        "section_exports": "Export Options",
        "love_dir": "LÖVE installation directory (contains love.exe):",
        "rcedit": "rcedit path (optional, to embed icon):",
        "icon_file": "exe icon (.ico/.png) (optional):",
        "android_template": "love-android template directory:",
        "lovejs_cmd": "love.js command (optional, e.g. npx love.js):",
        "section_excludes": "Exclusions (prevent recursive packing)",
        "excluded_exts": "Excluded extensions (comma separated):",
        "exclude_tool": "Exclude the packager tool folder itself",
        "exclude_out": "Exclude the output directory",
        "exclude_vcs": "Exclude .git/.vscode/__pycache__ etc.",
        "exclude_love": "Exclude existing *.love files",
        "exclude_doc": "Exclude Documentation folder",
        "action_build": "Build",
        "action_open_out": "Open output folder",
        "log_title": "Log",
        "status_ready": "Ready",
        "status_building": "Building...",
        "status_done": "Done",
        "err_no_project": "Please choose a project directory first.",
        "err_no_main": "main.lua not found in the project directory. Make sure you selected the game root.",
        "err_no_output": "Please choose an output directory first.",
        "err_no_name": "Please enter a project name.",
        "err_output_same": "The output directory must be different from the project directory.",
        "err_no_target": "Please select at least one export target.",
        "err_love_dir": "love.exe not found. Check the LÖVE installation directory.",
        "err_android_template": "love-android template not found, or missing app/src/main structure.",
        "confirm_open_out": "Build finished! Open the output directory?",
        "msg_done": "All export tasks completed.",
        "msg_love_created": "Created .love file: {path} ({count} files)",
        "msg_love_intermediate": "(intermediate .love created for other exports: {path})",
        "msg_skipped_doc": "Skipped Documentation folder.",
        "msg_exe_created": "Created Windows executable: {path}",
        "msg_dll_copied": "Copied DLL: {name}",
        "msg_android_created": "Created Android build preparation: {path}",
        "msg_android_hint": "Hint: open this folder in Android Studio and build the APK.",
        "msg_web_created": "Created love-js export preparation: {path}",
        "msg_web_no_cmd": "No love.js command provided; copied game.love only. You can run love.js manually.",
        "msg_web_cmd_error": "love.js failed: {err}",
        "msg_source_created": "Created source backup: {path}",
        "msg_excluded_tool": "Excluded tool directory: {path}",
        "msg_excluded_output": "Excluded output directory: {path}",
        "msg_icon_embedded": "Icon embedded: {path}",
        "msg_icon_skipped": "rcedit not found; skipped icon embedding (does not affect running).",
        "err_rcedit": "rcedit failed: {err}",
        "msg_icon_png_convert": "Converted PNG to multi-size ICO: {path}",
        "msg_icon_png_no_pillow": "Pillow is not installed; cannot auto-convert PNG to ICO. Install it (pip install Pillow) or use an .ico file.",
        "msg_icon_warn_small": "Icon only has {sizes} - too small; Explorer large icons will look blurry. Use an .ico containing 16/32/48/256 sizes.",
        "msg_start": "===== Build started: {name} =====",
        "msg_err": "Error: {err}",
        "help_title": "Help",
        "help_text": (
            "How to use:\n"
            "1. Choose the project directory (the folder containing main.lua).\n"
            "2. Choose the output directory (defaults to Export inside the project;\n"
            "   it is auto-excluded to prevent recursive packing).\n"
            "3. Check the export targets you need:\n"
            "   - .love: creates the game zip directly.\n"
            "   - Windows .exe: needs LÖVE installed; provide the folder containing\n"
            "     love.exe. The tool merges love.exe + game.love into a standalone\n"
            "     exe and copies the required DLLs.\n"
            "   - Android: download the love-android template\n"
            "     (https://github.com/love2d/love-android); the tool places game.love\n"
            "     into app/src/main/assets, then build the APK with Android Studio.\n"
            "   - love-js: optionally provide a love.js command (e.g. npx love.js);\n"
            "     otherwise only game.love and a README are produced.\n"
            "4. The exclusion settings skip the tool itself, the output directory,\n"
            "   *.love, .git etc. by default to avoid recursive packing.\n"
            "5. Click Build."
        ),
    },
}


# ---------------------------------------------------------------------------
# Small helpers (language / paths / filtering)
# ---------------------------------------------------------------------------

def detect_system_language():
    """Return 'zh' when the OS locale is Chinese, otherwise 'en'."""
    lang = None
    for getter in (lambda: locale.getdefaultlocale()[0],
                   lambda: locale.getlocale()[0],
                   lambda: os.environ.get("LANGUAGE"),
                   lambda: os.environ.get("LANG")):
        try:
            lang = getter()
            if lang:
                break
        except Exception:
            continue
    return "zh" if str(lang).lower().startswith("zh") else "en"


def is_strict_subdir(child, parent):
    """True if child is a directory strictly inside parent."""
    child = os.path.abspath(child)
    parent = os.path.abspath(parent)
    if child == parent:
        return False
    try:
        return os.path.commonpath([child, parent]) == parent
    except ValueError:
        return False


def sanitize_name(name):
    name = (name or "").strip()
    name = re.sub(r'[\\/:*?"<>|\r\n]+', "_", name)
    return name or "game"


def find_love_dir():
    """Try to locate a LÖVE installation directory containing love.exe."""
    candidates = (
        r"C:\Program Files\LOVE",
        r"C:\Program Files (x86)\LOVE",
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\LOVE"),
    )
    for p in candidates:
        if os.path.isfile(os.path.join(p, "love.exe")):
            return p
    exe = shutil.which("love")
    if exe:
        return os.path.dirname(exe)
    return None


def find_rcedit():
    tool = os.path.dirname(os.path.abspath(__file__))
    for name in ("rcedit-x64.exe", "rcedit.exe", "rcedit"):
        p = os.path.join(tool, name)
        if os.path.isfile(p):
            return p
    return shutil.which("rcedit") or None


def find_android_template():
    cwd = os.path.abspath(os.getcwd())
    tool = os.path.dirname(os.path.abspath(__file__))
    for base in (tool, cwd):
        p = os.path.join(base, "love-android")
        if os.path.isdir(os.path.join(p, "app", "src", "main")):
            return p
    return None


def iter_project_files(project_dir, exclude_dirs, exclude_exts, exclude_paths):
    """
    Walk the project and yield (relative_path_with_forward_slashes, abs_path)
    for every file that should be packaged.

    exclude_dirs   : set of directory *names* to skip (e.g. {'.git'}).
    exclude_exts   : set of file *extensions* to skip (e.g. {'.love'}).
    exclude_paths  : set of absolute paths (files or directories) to skip.
                     Directory entries are marked with a trailing os.sep.
    """
    project_dir = os.path.abspath(project_dir)
    exclude_dirs = set(str(d).lower() for d in exclude_dirs)
    exclude_exts = set(str(e).lower() for e in exclude_exts)
    exclude_abs = set()
    for p in exclude_paths:
        p = os.path.abspath(p)
        if os.path.isdir(p):
            exclude_abs.add(p.lower() + os.sep)
        else:
            exclude_abs.add(p.lower())

    def _is_excluded(path_abs):
        p_l = os.path.abspath(path_abs).lower()
        for ex in exclude_abs:
            if ex.endswith(os.sep):
                base = ex.rstrip(os.sep)
                if p_l == base or p_l.startswith(ex):
                    return True
            elif p_l == ex:
                return True
        return False

    for root, dirs, files in os.walk(project_dir, onerror=lambda e: None):
        kept = []
        for d in dirs:
            abs_d = os.path.abspath(os.path.join(root, d))
            if d.lower() in exclude_dirs or _is_excluded(abs_d):
                continue
            kept.append(d)
        dirs[:] = kept

        for f in files:
            fp = os.path.join(root, f)
            ext = os.path.splitext(f)[1].lower()
            if ext in exclude_exts or _is_excluded(fp):
                continue
            rel = os.path.relpath(fp, project_dir).replace(os.sep, "/")
            yield rel, fp


def create_zip(project_dir, zip_path, exclude_dirs, exclude_exts, exclude_paths):
    """Create a zip archive from the project (returns the file count)."""
    count = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        items = sorted(iter_project_files(project_dir, exclude_dirs,
                                          exclude_exts, exclude_paths),
                       key=lambda t: t[0].lower())
        for rel, fp in items:
            zf.write(fp, rel)
            count += 1
    return count


def png_to_ico(png_path, ico_path):
    """Convert a PNG into a multi-size ICO via Pillow (best effort).

    Windows Explorer/desktop wants a rich set of sizes (16/24/32/48/64/128/256);
    an .ico with only tiny frames makes large icons look terrible.
    """
    try:
        from PIL import Image
        img = Image.open(png_path).convert("RGBA")
        img.save(ico_path, format="ICO",
                 sizes=[(16, 16), (24, 24), (32, 32), (48, 48),
                        (64, 64), (128, 128), (256, 256)])
        return True
    except Exception:
        return False


def ico_sizes(ico_path):
    """Return [(width, height), ...] of an .ico file ([] when invalid/unreadable)."""
    try:
        with open(ico_path, "rb") as f:
            data = f.read()
        if len(data) < 6 or data[:4] != b"\x00\x00\x01\x00":
            return []
        count = struct.unpack("<H", data[4:6])[0]
        out = []
        for i in range(count):
            w, h = data[6 + i * 16], data[6 + i * 16 + 1]
            out.append(((w or 256), (h or 256)))
        return out
    except Exception:
        return []


# ---------------------------------------------------------------------------
# The tkinter application
# ---------------------------------------------------------------------------

class PackagerApp:
    def __init__(self, root):
        self.root = root
        self.lang = detect_system_language()
        self.log_queue = queue.Queue()
        self._build_running = False
        self._lang_refs = []          # (widget, key, kind)
        self._export_groups = []      # (BooleanVar, [widgets...])

        root.title("")
        root.geometry("780x860")
        root.minsize(700, 720)

        self._build_menu()
        self._build_ui()
        self._bind_traces()
        self._set_language(self.lang)
        self._defaults()
        self._poll_log()

    # ---- language helpers -------------------------------------------------
    def s(self, key, **kw):
        text = STRINGS.get(self.lang, STRINGS["en"]).get(key, key)
        if kw:
            for k, v in kw.items():
                text = text.replace("{" + k + "}", str(v))
        return text

    def add_lang(self, widget, key, kind="text"):
        self._lang_refs.append((widget, key, kind))

    def _set_language(self, lang):
        self.lang = lang if lang in LANGUAGES else "en"
        self.refresh_lang()

    def refresh_lang(self):
        for widget, key, kind in self._lang_refs:
            try:
                if kind == "text":
                    widget.configure(text=self.s(key))
                elif kind == "title":
                    widget.configure(title=self.s(key))
            except Exception:
                pass
        self.root.title(self.s("app_title"))
        self._populate_menu()

    def _build_menu(self):
        self.menubar = tk.Menu(self.root)
        self._lang_menu = tk.Menu(self.menubar, tearoff=0)
        self._help_menu = tk.Menu(self.menubar, tearoff=0)
        self.root.config(menu=self.menubar)
        self._populate_menu()

    def _populate_menu(self):
        # NOTE: on some Tk builds Menu.entryconfigure(index, label=...) throws
        # "unknown option -label" (TclError), so the entries are rebuilt instead.
        try:
            end = self.menubar.index("end")
            if end is not None:
                self.menubar.delete(0, end)
        except tk.TclError:
            pass

        self._lang_menu.delete(0, "end")
        self._lang_menu.add_command(label=self.s("menu_lang_zh"),
                                    command=lambda: self._set_language("zh"))
        self._lang_menu.add_command(label=self.s("menu_lang_en"),
                                    command=lambda: self._set_language("en"))
        self.menubar.add_cascade(label=self.s("menu_language"), menu=self._lang_menu)

        self._help_menu.delete(0, "end")
        self._help_menu.add_command(label=self.s("help_title"), command=self._show_help)
        self.menubar.add_cascade(label=self.s("help_title"), menu=self._help_menu)

    def _show_help(self):
        messagebox.showinfo(self.s("help_title"), self.s("help_text"))

    # ---- UI construction --------------------------------------------------
    def _build_ui(self):
        pad = {"padx": 8, "pady": 4}
        main = ttk.Frame(self.root, padding=10)
        main.pack(fill="both", expand=True)

        tip = ttk.Label(main, text="", wraplength=720, justify="left")
        self.add_lang(tip, "tip_text")
        tip.pack(fill="x", **pad)

        # ---- Project settings ----
        f1 = ttk.LabelFrame(main, padding=6)
        self.add_lang(f1, "section_project", "text")
        f1.pack(fill="x", **pad)
        f1.columnconfigure(1, weight=1)

        lbl = ttk.Label(f1, text="")
        self.add_lang(lbl, "project_dir")
        lbl.grid(row=0, column=0, sticky="w", padx=4, pady=5)
        self.var_proj = tk.StringVar()
        self.entry_proj = ttk.Entry(f1, textvariable=self.var_proj)
        self.entry_proj.grid(row=0, column=1, sticky="ew", padx=4, pady=5)
        self.btn_proj = ttk.Button(f1, text="", width=10,
                                   command=lambda: self._pick_dir(self.var_proj, self._on_project_picked))
        self.add_lang(self.btn_proj, "browse")
        self.btn_proj.grid(row=0, column=2, padx=4)

        lbl = ttk.Label(f1, text="")
        self.add_lang(lbl, "output_dir")
        lbl.grid(row=1, column=0, sticky="w", padx=4, pady=5)
        self.var_out = tk.StringVar()
        self.entry_out = ttk.Entry(f1, textvariable=self.var_out)
        self.entry_out.grid(row=1, column=1, sticky="ew", padx=4, pady=5)
        self.btn_out = ttk.Button(f1, text="", width=10,
                                  command=lambda: self._pick_dir(self.var_out))
        self.add_lang(self.btn_out, "browse")
        self.btn_out.grid(row=1, column=2, padx=4)

        lbl = ttk.Label(f1, text="")
        self.add_lang(lbl, "project_name")
        lbl.grid(row=2, column=0, sticky="w", padx=4, pady=5)
        self.var_name = tk.StringVar()
        self.entry_name = ttk.Entry(f1, textvariable=self.var_name)
        self.entry_name.grid(row=2, column=1, columnspan=2, sticky="ew", padx=4, pady=5)

        # ---- Export targets ----
        f2 = ttk.LabelFrame(main, padding=6)
        self.add_lang(f2, "section_targets", "text")
        f2.pack(fill="x", **pad)

        self.var_love = tk.BooleanVar(value=True)
        self.var_exe = tk.BooleanVar(value=False)
        self.var_android = tk.BooleanVar(value=False)
        self.var_web = tk.BooleanVar(value=False)
        self.var_source = tk.BooleanVar(value=False)

        self.cb_love = ttk.Checkbutton(f2, text="", variable=self.var_love)
        self.add_lang(self.cb_love, "target_love")
        self.cb_love.grid(row=0, column=0, sticky="w", padx=8, pady=3)

        self.cb_exe = ttk.Checkbutton(f2, text="", variable=self.var_exe)
        self.add_lang(self.cb_exe, "target_exe")
        self.cb_exe.grid(row=1, column=0, sticky="w", padx=8, pady=3)

        self.cb_android = ttk.Checkbutton(f2, text="", variable=self.var_android)
        self.add_lang(self.cb_android, "target_android")
        self.cb_android.grid(row=0, column=1, sticky="w", padx=8, pady=3)

        self.cb_web = ttk.Checkbutton(f2, text="", variable=self.var_web)
        self.add_lang(self.cb_web, "target_web")
        self.cb_web.grid(row=1, column=1, sticky="w", padx=8, pady=3)

        self.cb_source = ttk.Checkbutton(f2, text="", variable=self.var_source)
        self.add_lang(self.cb_source, "target_source")
        self.cb_source.grid(row=2, column=0, sticky="w", padx=8, pady=3)

        # ---- Export options ----
        f3 = ttk.LabelFrame(main, padding=6)
        self.add_lang(f3, "section_exports", "text")
        f3.pack(fill="x", **pad)
        f3.columnconfigure(1, weight=1)

        self.var_love_dir = tk.StringVar()
        self.var_rcedit = tk.StringVar()
        self.var_icon = tk.StringVar()
        self.var_android_template = tk.StringVar()
        self.var_lovejs = tk.StringVar()

        self.entry_love_dir = self._opt_row(f3, 0, "love_dir", self.var_love_dir, True)
        self.entry_rcedit = self._opt_row(f3, 1, "rcedit", self.var_rcedit, True,
                                          picker="file",
                                          filetypes=[("rcedit", "rcedit*.exe"),
                                                     ("Executable", "*.exe"),
                                                     ("All files", "*.*")])
        self.entry_icon = self._opt_row(f3, 2, "icon_file", self.var_icon, True,
                                        picker="file",
                                        filetypes=[("Image (*.ico)", "*.ico"),
                                                   ("Image (*.png)", "*.png"),
                                                   ("All files", "*.*")])
        self.entry_android_template = self._opt_row(f3, 3, "android_template",
                                                    self.var_android_template, True)
        self.entry_lovejs = self._opt_row(f3, 4, "lovejs_cmd", self.var_lovejs, False)

        # ---- Exclusions ----
        f4 = ttk.LabelFrame(main, padding=6)
        self.add_lang(f4, "section_excludes", "text")
        f4.pack(fill="x", **pad)
        f4.columnconfigure(1, weight=1)

        lbl = ttk.Label(f4, text="")
        self.add_lang(lbl, "excluded_exts")
        lbl.grid(row=0, column=0, sticky="w", padx=4, pady=5)
        self.var_excluded_exts = tk.StringVar()
        self.entry_excluded_exts = ttk.Entry(f4, textvariable=self.var_excluded_exts)
        self.entry_excluded_exts.grid(row=0, column=1, columnspan=2, sticky="ew", padx=4, pady=5)

        self.var_exclude_tool = tk.BooleanVar(value=True)
        self.var_exclude_out = tk.BooleanVar(value=True)
        self.var_exclude_vcs = tk.BooleanVar(value=True)
        self.var_exclude_love = tk.BooleanVar(value=True)
        self.var_exclude_doc = tk.BooleanVar(value=True)

        cb = ttk.Checkbutton(f4, text="", variable=self.var_exclude_tool)
        self.add_lang(cb, "exclude_tool")
        cb.grid(row=1, column=0, sticky="w", padx=8, pady=3)
        cb = ttk.Checkbutton(f4, text="", variable=self.var_exclude_out)
        self.add_lang(cb, "exclude_out")
        cb.grid(row=1, column=1, sticky="w", padx=8, pady=3)
        cb = ttk.Checkbutton(f4, text="", variable=self.var_exclude_vcs)
        self.add_lang(cb, "exclude_vcs")
        cb.grid(row=2, column=0, sticky="w", padx=8, pady=3)
        cb = ttk.Checkbutton(f4, text="", variable=self.var_exclude_love)
        self.add_lang(cb, "exclude_love")
        cb.grid(row=2, column=1, sticky="w", padx=8, pady=3)
        cb = ttk.Checkbutton(f4, text="", variable=self.var_exclude_doc)
        self.add_lang(cb, "exclude_doc")
        cb.grid(row=3, column=0, sticky="w", padx=8, pady=3)

        # ---- Actions ----
        f5 = ttk.Frame(main)
        f5.pack(fill="x", **pad)
        f5.columnconfigure(2, weight=1)

        self.btn_build = ttk.Button(f5, text="", command=self.on_build)
        self.add_lang(self.btn_build, "action_build")
        self.btn_build.grid(row=0, column=0, padx=4, pady=4, sticky="w")

        self.btn_open = ttk.Button(f5, text="", command=self._open_output)
        self.add_lang(self.btn_open, "action_open_out")
        self.btn_open.grid(row=0, column=1, padx=4, pady=4, sticky="w")

        self.progress = ttk.Progressbar(f5, mode="indeterminate")
        self.progress.grid(row=0, column=2, sticky="ew", padx=8, pady=4)

        self.status = tk.StringVar()
        self.lbl_status = ttk.Label(f5, textvariable=self.status)
        self.lbl_status.grid(row=1, column=0, columnspan=3, sticky="w", padx=4, pady=2)

        # ---- Log ----
        f6 = ttk.LabelFrame(main, padding=6)
        self.add_lang(f6, "log_title", "text")
        f6.pack(fill="both", expand=True, **pad)

        self.log_text = scrolledtext.ScrolledText(f6, height=14, wrap="word",
                                                  state="disabled", font=("Consolas", 9))
        self.log_text.pack(fill="both", expand=True)

    def _opt_row(self, parent, row, label_key, var, with_browse,
                 picker="dir", filetypes=None):
        lbl = ttk.Label(parent, text="")
        self.add_lang(lbl, label_key)
        lbl.grid(row=row, column=0, sticky="w", padx=4, pady=4)
        entry = ttk.Entry(parent, textvariable=var)
        entry.grid(row=row, column=1, sticky="ew", padx=4, pady=4)
        if with_browse:
            if picker == "file":
                btn = ttk.Button(parent, text="", width=10,
                                 command=lambda v=var, ft=filetypes: self._pick_file(v, ft))
            else:
                btn = ttk.Button(parent, text="", width=10,
                                 command=lambda v=var: self._pick_dir(v))
            self.add_lang(btn, "browse")
            btn.grid(row=row, column=2, padx=4, pady=4)
        return entry

    def _bind_traces(self):
        self._export_groups = [
            (self.var_exe, [self.entry_love_dir]),
            (self.var_exe, [self.entry_rcedit]),
            (self.var_exe, [self.entry_icon]),
            (self.var_android, [self.entry_android_template]),
            (self.var_web, [self.entry_lovejs]),
        ]
        for var, _ in self._export_groups:
            var.trace_add("write", lambda *a: self._refresh_export_enabled())
        self._refresh_export_enabled()

    def _refresh_export_enabled(self):
        for var, widgets in self._export_groups:
            state = "normal" if var.get() else "disabled"
            for w in widgets:
                try:
                    w.configure(state=state)
                except Exception:
                    pass

    # ---- defaults / pickers ----------------------------------------------
    def _defaults(self):
        cwd = os.path.abspath(os.getcwd())
        if os.path.isfile(os.path.join(cwd, "main.lua")):
            self.var_proj.set(cwd)
            self.var_out.set(os.path.join(cwd, "Export"))
            self.var_name.set(os.path.basename(cwd))
            # Prefer icon.png: it is converted to a multi-size .ico at build
            # time (the old icon.ico only carried a 16x16 frame).
            for icon_name in ("icon.png", "icon.ico"):
                ico = os.path.join(cwd, icon_name)
                if os.path.isfile(ico):
                    self.var_icon.set(ico)
                    break
        self.var_excluded_exts.set(DEFAULT_EXCLUDED_EXTS)
        if not self.var_love_dir.get():
            love = find_love_dir()
            if love:
                self.var_love_dir.set(love)
        if not self.var_android_template.get():
            tpl = find_android_template()
            if tpl:
                self.var_android_template.set(tpl)
        if not self.var_rcedit.get():
            rc = find_rcedit()
            if rc:
                self.var_rcedit.set(rc)
        self.status.set(self.s("status_ready"))

    def _pick_dir(self, var, on_pick=None):
        p = filedialog.askdirectory()
        if p:
            var.set(p)
            if on_pick:
                on_pick()

    def _pick_file(self, var, filetypes=None):
        p = filedialog.askopenfilename(
            filetypes=filetypes or [("All files", "*.*")])
        if p:
            var.set(p)

    def _on_project_picked(self):
        p = self.var_proj.get().strip()
        if not p:
            return
        if not self.var_out.get().strip():
            self.var_out.set(os.path.join(p, "Export"))
        if not self.var_name.get().strip():
            self.var_name.set(os.path.basename(os.path.normpath(p)))
        if not self.var_icon.get().strip():
            for icon_name in ("icon.png", "icon.ico"):
                ico = os.path.join(p, icon_name)
                if os.path.isfile(ico):
                    self.var_icon.set(ico)
                    break

    # ---- build flow -------------------------------------------------------
    def on_build(self):
        if self._build_running:
            return
        err = self._validate()
        if err:
            messagebox.showerror(self.s("app_title"), err)
            return
        self._build_running = True
        self.btn_build.configure(state="disabled")
        self.progress.start(12)
        self.status.set(self.s("status_building"))
        self.log_text.configure(state="normal")
        self.log_text.delete("1.0", "end")
        self.log_text.configure(state="disabled")
        threading.Thread(target=self._build_worker, daemon=True).start()

    def _validate(self):
        p = self.var_proj.get().strip()
        o = self.var_out.get().strip()
        n = self.var_name.get().strip()
        if not p or not os.path.isdir(p):
            return self.s("err_no_project")
        if not os.path.isfile(os.path.join(p, "main.lua")):
            return self.s("err_no_main")
        if not o:
            return self.s("err_no_output")
        if not n:
            return self.s("err_no_name")
        if os.path.normcase(os.path.abspath(o)) == os.path.normcase(os.path.abspath(p)):
            return self.s("err_output_same")
        targets = (self.var_love.get(), self.var_exe.get(), self.var_android.get(),
                   self.var_web.get(), self.var_source.get())
        if not any(targets):
            return self.s("err_no_target")
        return None

    def _emit(self, key, **kw):
        self.log_queue.put(("log", self.s(key, **kw)))

    def _emit_raw(self, text):
        self.log_queue.put(("log", text))

    def _build_worker(self):
        try:
            self._run_build()
            self.log_queue.put(("done", None))
        except Exception as exc:
            import traceback
            self.log_queue.put(("log", traceback.format_exc()))
            self.log_queue.put(("error", str(exc)))

    def _run_build(self):
        project_dir = os.path.abspath(self.var_proj.get().strip())
        output_dir = os.path.abspath(self.var_out.get().strip())
        name = sanitize_name(self.var_name.get())
        os.makedirs(output_dir, exist_ok=True)

        # ---- build exclusion sets ----
        exclude_dirs = set()
        exclude_exts = set()
        exclude_paths = [os.path.abspath(__file__)]

        tool_dir = os.path.dirname(os.path.abspath(__file__))
        if self.var_exclude_tool.get() and is_strict_subdir(tool_dir, project_dir):
            exclude_paths.append(tool_dir)
            self._emit("msg_excluded_tool", path=tool_dir)
        if self.var_exclude_out.get():
            exclude_paths.append(output_dir)
            self._emit("msg_excluded_output", path=output_dir)
        if self.var_exclude_vcs.get():
            exclude_dirs.update(DEFAULT_VCS_DIRS)
        if self.var_exclude_doc.get():
            exclude_dirs.add("Documentation")
            self._emit("msg_skipped_doc")
        if self.var_exclude_love.get():
            exclude_exts.add(".love")
        for ext in re.split(r"[;，,]+", self.var_excluded_exts.get()):
            e = ext.strip().lower()
            if not e:
                continue
            if not e.startswith("."):
                e = "." + e
            exclude_exts.add(e)

        self._emit("msg_start", name=name)

        need_love = bool(self.var_love.get() or self.var_exe.get()
                         or self.var_android.get() or self.var_web.get())
        love_path = None
        if need_love:
            love_path = os.path.join(output_dir, name + ".love")
            count = create_zip(project_dir, love_path, exclude_dirs,
                               exclude_exts, exclude_paths)
            if self.var_love.get():
                self._emit("msg_love_created", path=love_path, count=count)
            else:
                self._emit("msg_love_intermediate", path=love_path)

        # ---- Windows .exe ----
        if self.var_exe.get():
            love_dir = self.var_love_dir.get().strip() or (find_love_dir() or "")
            love_exe = os.path.join(love_dir, "love.exe")
            if not os.path.isfile(love_exe):
                raise RuntimeError(self.s("err_love_dir"))
            exe_dir = os.path.join(output_dir, name + "-win")
            os.makedirs(exe_dir, exist_ok=True)
            exe_path = os.path.join(exe_dir, name + ".exe")

            # Accept an .ico directly, or a .png that is auto-converted into a
            # multi-size .ico (same behaviour as the reference packager).
            icon_eff = None
            icon_src = self.var_icon.get().strip()
            if icon_src and os.path.isfile(icon_src):
                if icon_src.lower().endswith(".png"):
                    ico_tmp = os.path.join(exe_dir, name + "_icon.ico")
                    if png_to_ico(icon_src, ico_tmp):
                        self._emit("msg_icon_png_convert", path=ico_tmp)
                        icon_eff = ico_tmp
                    else:
                        self._emit("msg_icon_png_no_pillow")
                else:
                    icon_eff = icon_src

            # IMPORTANT ORDER: rcedit rewrites the whole PE and would STRIP the
            # .love payload appended during fusing (verified against love 11.5 /
            # 12.0: an exe fused first and then edited by rcedit cannot run the
            # game any more). Therefore embed the icon on a plain copy of
            # love.exe FIRST - at that point it has no trailing payload - and
            # only then append the .love bytes.
            shutil.copy2(love_exe, exe_path)
            self._embed_icon(exe_path, icon_eff)
            with open(exe_path, "ab") as dst, open(love_path, "rb") as src:
                shutil.copyfileobj(src, dst, 1024 * 1024)
            self._emit("msg_exe_created", path=exe_path)
            for f in sorted(os.listdir(love_dir)):
                if f.lower().endswith(".dll"):
                    shutil.copy2(os.path.join(love_dir, f), os.path.join(exe_dir, f))
                    self._emit("msg_dll_copied", name=f)

        # ---- Android preparation ----
        if self.var_android.get():
            template = self.var_android_template.get().strip() or (find_android_template() or "")
            if not os.path.isdir(os.path.join(template, "app", "src", "main")):
                raise RuntimeError(self.s("err_android_template"))
            target = os.path.join(output_dir, name + "-android")
            if os.path.isdir(target):
                shutil.rmtree(target)
            shutil.copytree(template, target)
            assets = os.path.join(target, "app", "src", "main", "assets")
            os.makedirs(assets, exist_ok=True)
            dest = os.path.join(assets, "game.love")
            if os.path.isfile(dest):
                os.remove(dest)
            shutil.copy2(love_path, dest)
            self._emit("msg_android_created", path=target)
            self._emit("msg_android_hint")

        # ---- love-js (Web) ----
        if self.var_web.get():
            target = os.path.join(output_dir, name + "-web")
            os.makedirs(target, exist_ok=True)
            dest_love = os.path.join(target, "game.love")
            shutil.copy2(love_path, dest_love)
            cmd = self.var_lovejs.get().strip()
            if cmd:
                try:
                    parts = [p.strip('"') for p in shlex.split(cmd, posix=False)]
                    proc = subprocess.run(parts + [dest_love, target],
                                          capture_output=True, text=True)
                    if proc.returncode != 0:
                        err = (proc.stderr or proc.stdout or "unknown").strip()
                        self._emit("msg_web_cmd_error", err=err[:500])
                except Exception as exc:
                    self._emit("msg_web_cmd_error", err=str(exc))
            else:
                self._emit("msg_web_no_cmd")
                self._write_web_readme(target, name)
            self._emit("msg_web_created", path=target)

        # ---- source backup ----
        if self.var_source.get():
            zip_path = os.path.join(output_dir, name + "-source.zip")
            count = create_zip(project_dir, zip_path, exclude_dirs,
                               exclude_exts, exclude_paths)
            self._emit("msg_source_created", path=zip_path)

    def _embed_icon(self, exe_path, icon_path=None):
        """Embed icon_path (or the UI-selected icon) into exe_path via rcedit.

        Returns True when the icon was actually embedded; never raises.
        Logs the rcedit binary used and surfaces rcedit's stderr on failure.
        """
        icon = (icon_path or self.var_icon.get() or "").strip()
        if not icon or not os.path.isfile(icon):
            return False
        rcedit = self.var_rcedit.get().strip() or (find_rcedit() or "")
        if not rcedit:
            self._emit("msg_icon_skipped")
            return False
        self._emit_raw("rcedit: %s" % rcedit)
        try:
            subprocess.run([rcedit, exe_path, "--set-icon", icon],
                           check=True, capture_output=True,
                           text=True, errors="replace")
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or exc.stdout or "").strip()
            self._emit("err_rcedit", err=detail or str(exc))
            return False
        except Exception as exc:
            self._emit("err_rcedit", err=exc)
            return False
        self._emit("msg_icon_embedded", path=icon)
        sizes = ico_sizes(icon)
        if sizes and max(h for _, h in sizes) < 48:
            self._emit("msg_icon_warn_small",
                       sizes=", ".join("%dx%d" % (w, h) for w, h in sizes))
        return True

    def _write_web_readme(self, target, name):
        text = (
            "This folder contains game.love for a love-js (Web) export.\n"
            "Generate the web build with, e.g.:\n"
            "  npx love.js --title \"%s\" game.love .\n"
            "\n"
            "本文件夹包含用于 love-js (Web) 导出的 game.love。\n"
            "可使用例如以下命令生成网页版:\n"
            "  npx love.js --title \"%s\" game.love .\n"
        ) % (name, name)
        with open(os.path.join(target, "README.txt"), "w", encoding="utf-8") as f:
            f.write(text)

    # ---- logging / poll / done -------------------------------------------
    def _poll_log(self):
        try:
            while True:
                kind, payload = self.log_queue.get_nowait()
                if kind == "log":
                    self._append_log(payload)
                elif kind == "done":
                    self._on_done()
                elif kind == "error":
                    self._on_error(payload)
        except queue.Empty:
            pass
        self.root.after(120, self._poll_log)

    def _append_log(self, text):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", text + "\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def _on_done(self):
        self._build_running = False
        self.btn_build.configure(state="normal")
        self.progress.stop()
        self.status.set(self.s("status_done"))
        self._append_log(self.s("msg_done"))
        out = self.var_out.get().strip()
        if out and messagebox.askyesno(self.s("app_title"), self.s("confirm_open_out")):
            self._open_path(out)

    def _on_error(self, msg):
        self._build_running = False
        self.btn_build.configure(state="normal")
        self.progress.stop()
        self.status.set(self.s("status_ready"))
        self._append_log(self.s("msg_err", err=msg))
        short = msg.splitlines()[-1] if msg.splitlines() else msg
        messagebox.showerror(self.s("app_title"), self.s("msg_err", err=short))

    # ---- misc -------------------------------------------------------------
    def _open_path(self, path):
        try:
            if sys.platform.startswith("win"):
                os.startfile(path)  # noqa
            elif sys.platform == "darwin":
                subprocess.Popen(["open", path])
            else:
                subprocess.Popen(["xdg-open", path])
        except Exception:
            pass

    def _open_output(self):
        out = self.var_out.get().strip()
        if out:
            self._open_path(out)


def main():
    # Any startup crash is written to error.log (next to this script) so that
    # even when launched via pythonw (no console) the failure is not invisible.
    log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "error.log")
    try:
        root = tk.Tk()
        try:
            icon = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon.ico")
            if not os.path.isfile(icon):
                icon = os.path.join(os.getcwd(), "icon.ico")
            if os.path.isfile(icon):
                root.iconbitmap(icon)
        except Exception:
            pass
        PackagerApp(root)
        root.mainloop()
    except Exception:
        import traceback
        try:
            with open(log_path, "w", encoding="utf-8") as f:
                f.write("LÖVE Packager crashed:\n")
                f.write(traceback.format_exc())
        except Exception:
            pass
        raise


if __name__ == "__main__":
    main()
