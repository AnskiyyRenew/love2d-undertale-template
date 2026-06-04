#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Love2D 导出工具（Tkinter GUI）
功能：
- 生成 .love 压缩包（必备）
- 可选：使用指定的 love.exe 生成 Windows 独立 exe（把 love.exe + .love 拼接）
- 可选：选择 .png 文件作为 exe 图标（需要 Pillow 和 rcedit）
- 可选：生成/嵌入 DPI 感知 manifest（禁用 DPI 缩放，防止模糊）
- 为 Android 生成基本工程模板（把 game.love 放到 app/src/main/assets/game.love），并生成 README 指南
- 提供 APK/JDK 的帮助说明弹窗
- 支持中英文界面切换
"""

import os
import sys
import zipfile
import shutil
import threading
import subprocess
import tempfile
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from tkinter.scrolledtext import ScrolledText
import time

# -----------------------
# 多语言文本定义
# -----------------------

LANGUAGES = {
    'zh': {
        # UI labels
        'window_title': "Love2D 导出工具",
        'project_label': "项目文件夹路径（必需）:",
        'browse_btn': "浏览",
        'love_exe_label': "love.exe（可选，若在项目目录会自动检测）:",
        'auto_detect_btn': "自动检测",
        'output_label': "输出目录:",
        'icon_label': "exe 图标（可选，.png 文件）:",
        'select_png_btn': "选择 PNG",
        'clear_btn': "清除",
        'platform_label': "选择导出平台:",
        'windows_check': "Windows (.exe)",
        'android_check': "Android APK (生成模板)",
        'jdk_help_btn': "JDK & Android 构建说明",
        'dpi_check': "禁用 DPI 缩放（生成 DPI-Aware manifest，防止系统拉伸模糊）",
        'dpi_help_btn': "说明",
        'jdk_label': "JDK 安装路径（可选，用于快速检测）：",
        'check_java_btn': "检查 java -version",
        'export_btn': "开始导出",
        'open_output_btn': "打开输出目录",
        'exit_btn': "退出",
        'log_label': "日志",
        'status_ready': "就绪",
        'status_processing': "正在处理…",
        'status_packing_love': "正在打包 .love…",
        'status_converting_icon': "转换图标…",
        'status_generating_exe': "生成 Windows exe…",
        'status_embedding_manifest': "嵌入 manifest…",
        'status_generating_android': "生成 Android 模板…",
        'status_done': "完成 ✓",
        'status_error': "出错 ✗",
        'status_cancelled': "已阻止",
        # Messages
        'output_dir_same_error': (
            "输出目录与项目目录相同：\n{}\n\n"
            "打包时会把正在生成的 .love 打包进自身，导致文件无限增长。\n"
            "请将输出目录设置到项目文件夹之外。"
        ),
        'output_dir_inside_error': (
            "输出目录在项目目录内部：\n{}\n\n"
            "打包时会把 love_exports 文件夹打包进 .love，"
            "导致文件无限增长。\n"
            "请将输出目录设置到项目文件夹之外（例如项目的上级目录）。"
        ),
        'pillow_missing': "⚠ 未安装 Pillow，无法转换图标。请运行：pip install Pillow",
        'png_convert_success': "已将 PNG 转换为 ICO：{}",
        'png_convert_failed': "PNG 转 ICO 失败：{}",
        'rcedit_not_found': "未找到 rcedit.exe（可从 https://github.com/electron/rcedit/releases 下载并放在脚本同目录）",
        'mt_not_found': "未找到 mt.exe（Windows SDK 工具）。将尝试旁加载 manifest 作为备选。",
        'icon_embedded': "✓ 图标已通过 rcedit 嵌入 exe",
        'icon_embed_failed': "rcedit 嵌入图标失败：{}",
        'rcedit_exec_failed': "rcedit 执行失败：{}",
        'rcedit_missing': "⚠ 未找到 rcedit，无法嵌入图标（请将 rcedit.exe 放在脚本同目录）",
        'manifest_embedded': "✓ DPI manifest 已通过 mt.exe 嵌入 exe",
        'manifest_embed_failed': "mt.exe 嵌入 manifest 失败：{}，将改用旁加载文件。",
        'manifest_exception': "嵌入 manifest 时出现异常：{}",
        'manifest_sidecar': "✓ 已生成外部 manifest 文件（旁加载方式）：{}",
        'manifest_sidecar_note': "  注意：外部 manifest 在某些系统可能需要管理员权限或组策略允许才能生效。",
        'manifest_sidecar_best': "  最佳方案是安装 rcedit 后重新打包，让 manifest 嵌入 exe 内部。",
        'manifest_sidecar_write_failed': "写入外部 manifest 失败：{}",
        'android_template_ready': "准备 Android 工程模板...",
        'android_love_copied': "已把 .love 放到模板：{}",
        'android_readme_generated': "已生成 README：{}",
        'auto_detect_title': "自动检测",
        'auto_detect_msg': "请先选择项目文件夹（它是自动检测 love.exe 的地方）",
        'auto_detect_found': "在项目目录中发现 love.exe：{}",
        'auto_detect_parent': "在父目录发现 love.exe：{}",
        'auto_detect_not_found': "未在项目目录或其父目录找到 love.exe（如果有请手动指定）",
        'dpi_help_title': "DPI 感知 Manifest 说明",
        'dpi_help_msg': (
            "Windows 默认会对不声明 DPI 感知的程序进行 DPI 缩放（位图拉伸），\n"
            "导致画面模糊，或者 Love2D 游戏窗口大小与预期不符。\n\n"
            "勾选此选项后，工具会生成一个 XML manifest，声明程序为\n"
            "PerMonitorV2 DPI 感知模式，让系统不再对程序进行 DPI 缩放，\n"
            "让游戏自己处理分辨率。\n\n"
            "嵌入方式（按优先级）：\n"
            "1. 若找到 mt.exe（Windows SDK 工具），manifest 直接嵌入 exe 资源（推荐）\n"
            "   mt.exe 随 Visual Studio 或 Windows SDK 一同安装，一般在：\n"
            "   C:\\Program Files (x86)\\Windows Kits\\10\\bin\\<版本>\\x64\\mt.exe\n"
            "2. 否则，在 exe 同目录生成 <游戏名>.exe.manifest 旁加载文件\n\n"
            "注意：rcedit 只用于嵌入图标，不支持嵌入 manifest。\n"
            "rcedit 下载：https://github.com/electron/rcedit/releases\n"
            "放在本脚本同目录即可自动识别。"
        ),
        'jdk_help_title': "JDK & Android 构建说明",
        'jdk_help_msg': (
            "JDK & Android 构建简要说明：\n\n"
            "为什么需要 JDK？\n"
            " - Android 的构建工具（Gradle / Android Studio）需要 Java（JDK）来运行。\n\n"
            "基本步骤（高层次）：\n"
            "1. 安装 JDK（建议 AdoptOpenJDK / Temurin，版本 11 或 17）并配置 JAVA_HOME。\n"
            "   java -version\n"
            "   javac -version\n\n"
            "2. 安装 Android SDK（建议使用 Android Studio），并确保 adb / sdkmanager 可用。\n\n"
            "3. 获取 love-android 模板（https://github.com/love2d/love-android），\n"
            "   把本工具生成的 game.love 放进去覆盖。\n\n"
            "4. 在 love-android 目录中运行：\n"
            "   ./gradlew assembleRelease\n"
            "   生成的 APK 在 app/build/outputs/apk/ 下。"
        ),
        'java_version_title': "java -version",
        'java_version_error_title': "错误",
        'java_version_error_msg': "无法执行 java -version：{}",
        'open_output_failed': "无法打开目录：{}",
        'warning_no_project': "缺少项目路径",
        'warning_no_project_msg': "请指定 Love2D 项目文件夹路径（必需）。",
        'error_invalid_path': "路径无效",
        'error_invalid_path_msg': "项目路径不存在或不是文件夹。",
        'warning_no_platform': "请选择平台",
        'warning_no_platform_msg': "请至少勾选一个导出平台（Windows 或 APK）。",
        'export_blocked': "⛔ 导出被阻止：{}",
        'export_complete': "==== 导出完成 ====",
        'export_start': "==== 开始导出流程 ====",
        'export_done_title': "完成",
        'export_done_msg': "导出流程已完成。请查看日志和输出目录。",
        'export_failed_title': "导出失败",
        'export_failed_msg': "发生错误：{}",
        'android_template_generated': "已生成 Android 模板目录：{}",
        'android_template_readme': "请查看模板内的 README_BUILD_APK.md，按步骤使用 love-android 或 Android Studio 构建 APK。",
        'android_template_failed': "生成 Android 模板失败：{}",
        'love_exe_not_found': "指定的 love.exe 不存在：{}。将只生成 .love 文件。",
        'love_exe_auto_detected': "在本地自动检测到 love.exe：{}",
        'love_exe_missing': "未指定 love.exe，且在项目/父目录未检测到 love.exe。已生成 .love 文件，但无法生成独立 exe。",
        'icon_embedded_pre': "✓ 图标已嵌入（在追加 .love 之前）",
        'copying_dll': "复制依赖：{}",
        'copy_dll_failed': "复制依赖失败：{} - {}",
        'windows_exe_generated': "Windows 可执行已生成：{}",
        'windows_exe_failed': "创建 Windows exe 失败：{}",
        'export_exception': "导出出现异常：{}",
        'love_archive_creating': "开始创建 .love：{}",
        'love_archive_done': ".love 创建完成：{}",
        'windows_exe_creating': "开始创建 Windows 可执行文件：{}",
        'windows_exe_appended': "已生成 exe（拼接 .love）：{}",
        'language_switch_btn': "English",
    },
    'en': {
        # UI labels
        'window_title': "Love2D Exporter",
        'project_label': "Project Folder Path (Required):",
        'browse_btn': "Browse",
        'love_exe_label': "love.exe (Optional, auto-detected if in project folder):",
        'auto_detect_btn': "Auto Detect",
        'output_label': "Output Directory:",
        'icon_label': "exe Icon (Optional, .png file):",
        'select_png_btn': "Select PNG",
        'clear_btn': "Clear",
        'platform_label': "Select Export Platforms:",
        'windows_check': "Windows (.exe)",
        'android_check': "Android APK (Generate Template)",
        'jdk_help_btn': "JDK & Android Build Guide",
        'dpi_check': "Disable DPI Scaling (Generate DPI-Aware manifest to prevent blurring)",
        'dpi_help_btn': "Help",
        'jdk_label': "JDK Installation Path (Optional, for quick check):",
        'check_java_btn': "Check java -version",
        'export_btn': "Start Export",
        'open_output_btn': "Open Output Directory",
        'exit_btn': "Exit",
        'log_label': "Log",
        'status_ready': "Ready",
        'status_processing': "Processing…",
        'status_packing_love': "Packing .love…",
        'status_converting_icon': "Converting icon…",
        'status_generating_exe': "Generating Windows exe…",
        'status_embedding_manifest': "Embedding manifest…",
        'status_generating_android': "Generating Android template…",
        'status_done': "Done ✓",
        'status_error': "Error ✗",
        'status_cancelled': "Blocked",
        # Messages
        'output_dir_same_error': (
            "Output directory is the same as project directory:\n{}\n\n"
            "The .love file being created would be packed into itself, causing infinite file growth.\n"
            "Please set the output directory outside the project folder."
        ),
        'output_dir_inside_error': (
            "Output directory is inside the project directory:\n{}\n\n"
            "The love_exports folder would be packed into the .love file, "
            "causing infinite file growth.\n"
            "Please set the output directory outside the project folder (e.g., parent directory of the project)."
        ),
        'pillow_missing': "⚠ Pillow not installed, cannot convert icon. Run: pip install Pillow",
        'png_convert_success': "Converted PNG to ICO: {}",
        'png_convert_failed': "PNG to ICO conversion failed: {}",
        'rcedit_not_found': "rcedit.exe not found (download from https://github.com/electron/rcedit/releases and place in script directory)",
        'mt_not_found': "mt.exe not found (Windows SDK tool). Will try sidecar manifest as fallback.",
        'icon_embedded': "✓ Icon embedded via rcedit",
        'icon_embed_failed': "rcedit failed to embed icon: {}",
        'rcedit_exec_failed': "rcedit execution failed: {}",
        'rcedit_missing': "⚠ rcedit not found, cannot embed icon (place rcedit.exe in script directory)",
        'manifest_embedded': "✓ DPI manifest embedded via mt.exe",
        'manifest_embed_failed': "mt.exe failed to embed manifest: {}, using sidecar file instead.",
        'manifest_exception': "Exception while embedding manifest: {}",
        'manifest_sidecar': "✓ Generated external manifest file (sidecar): {}",
        'manifest_sidecar_note': "  Note: External manifest may require administrator privileges or group policy to take effect on some systems.",
        'manifest_sidecar_best': "  Best practice: Install rcedit and repackage to embed manifest inside exe.",
        'manifest_sidecar_write_failed': "Failed to write external manifest: {}",
        'android_template_ready': "Preparing Android project template...",
        'android_love_copied': "Copied .love to template: {}",
        'android_readme_generated': "Generated README: {}",
        'auto_detect_title': "Auto Detect",
        'auto_detect_msg': "Please select a project folder first (where love.exe will be auto-detected)",
        'auto_detect_found': "Found love.exe in project directory: {}",
        'auto_detect_parent': "Found love.exe in parent directory: {}",
        'auto_detect_not_found': "love.exe not found in project directory or its parent (specify manually if available)",
        'dpi_help_title': "DPI Awareness Manifest Help",
        'dpi_help_msg': (
            "Windows applies DPI scaling (bitmap stretching) to programs that don't declare DPI awareness,\n"
            "which can cause blurriness or incorrect window sizes for Love2D games.\n\n"
            "When checked, this tool generates an XML manifest declaring the program as\n"
            "PerMonitorV2 DPI aware, preventing the system from applying DPI scaling,\n"
            "allowing the game to handle its own resolution.\n\n"
            "Embedding methods (by priority):\n"
            "1. If mt.exe (Windows SDK tool) is found, manifest is embedded directly into exe (recommended)\n"
            "   mt.exe is installed with Visual Studio or Windows SDK, typically at:\n"
            "   C:\\Program Files (x86)\\Windows Kits\\10\\bin\\<version>\\x64\\mt.exe\n"
            "2. Otherwise, a sidecar <game>.exe.manifest file is generated alongside the exe\n\n"
            "Note: rcedit is only for icons, does NOT support embedding manifests.\n"
            "rcedit download: https://github.com/electron/rcedit/releases\n"
            "Place it in the same directory as this script for auto-detection."
        ),
        'jdk_help_title': "JDK & Android Build Guide",
        'jdk_help_msg': (
            "JDK & Android Build Quick Guide:\n\n"
            "Why is JDK needed?\n"
            " - Android's build tools (Gradle / Android Studio) require Java (JDK) to run.\n\n"
            "Basic Steps (high-level):\n"
            "1. Install JDK (recommended: AdoptOpenJDK / Temurin, version 11 or 17) and configure JAVA_HOME.\n"
            "   java -version\n"
            "   javac -version\n\n"
            "2. Install Android SDK (recommended via Android Studio), and ensure adb / sdkmanager are available.\n\n"
            "3. Get the love-android template (https://github.com/love2d/love-android),\n"
            "   replace the generated game.love file into it.\n\n"
            "4. In the love-android directory, run:\n"
            "   ./gradlew assembleRelease\n"
            "   The generated APK will be in app/build/outputs/apk/."
        ),
        'java_version_title': "java -version",
        'java_version_error_title': "Error",
        'java_version_error_msg': "Cannot run java -version: {}",
        'open_output_failed': "Cannot open directory: {}",
        'warning_no_project': "Missing Project Path",
        'warning_no_project_msg': "Please specify the Love2D project folder path (required).",
        'error_invalid_path': "Invalid Path",
        'error_invalid_path_msg': "Project path does not exist or is not a folder.",
        'warning_no_platform': "Select Platform",
        'warning_no_platform_msg': "Please select at least one export platform (Windows or APK).",
        'export_blocked': "⛔ Export blocked: {}",
        'export_complete': "==== Export Complete ====",
        'export_start': "==== Starting Export Process ====",
        'export_done_title': "Complete",
        'export_done_msg': "Export process completed. Check the log and output directory.",
        'export_failed_title': "Export Failed",
        'export_failed_msg': "Error occurred: {}",
        'android_template_generated': "Generated Android template directory: {}",
        'android_template_readme': "Check README_BUILD_APK.md in the template for steps to build APK using love-android or Android Studio.",
        'android_template_failed': "Failed to generate Android template: {}",
        'love_exe_not_found': "Specified love.exe does not exist: {}. Will only generate .love file.",
        'love_exe_auto_detected': "Auto-detected love.exe locally: {}",
        'love_exe_missing': "love.exe not specified and not found in project/parent directory. .love file generated but standalone exe cannot be created.",
        'icon_embedded_pre': "✓ Icon embedded (before appending .love)",
        'copying_dll': "Copying dependency: {}",
        'copy_dll_failed': "Failed to copy dependency: {} - {}",
        'windows_exe_generated': "Windows executable generated: {}",
        'windows_exe_failed': "Failed to create Windows exe: {}",
        'export_exception': "Export exception: {}",
        'love_archive_creating': "Creating .love archive: {}",
        'love_archive_done': ".love archive created: {}",
        'windows_exe_creating': "Creating Windows executable: {}",
        'windows_exe_appended': "Generated exe (appended .love): {}",
        'language_switch_btn': "中文",
    }
}

# -----------------------
# Manifest XML for DPI awareness
# -----------------------

DPI_MANIFEST_XML = """\
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0" xmlns:asmv3="urn:schemas-microsoft-com:asm.v3">
  <assemblyIdentity
    type="win32"
    name="Love2DGame"
    version="1.0.0.0"
    processorArchitecture="*"
  />
  <asmv3:application>
    <asmv3:windowsSettings>
      <!-- 禁用 DPI 虚拟化，让游戏以真实物理像素渲染 -->
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">True/PM</dpiAware>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2, PerMonitor</dpiAwareness>
    </asmv3:windowsSettings>
  </asmv3:application>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <!-- Windows 10 and above -->
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <!-- Windows 8.1 -->
      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
      <!-- Windows 8 -->
      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
      <!-- Windows 7 -->
      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
    </application>
  </compatibility>
</assembly>
"""

# -----------------------
# Helper functions
# -----------------------

IGNORED_DIRS = {'.git', '__pycache__', '.vs', '.idea', 'build', 'dist', '.vscode'}

def log_append(text_widget: ScrolledText, msg: str):
    text_widget.configure(state='normal')
    text_widget.insert(tk.END, f"[{time.strftime('%H:%M:%S')}] {msg}\n")
    text_widget.see(tk.END)
    text_widget.configure(state='disabled')

def create_love_archive(project_path: Path, output_path: Path, logger=None) -> Path:
    """
    Create a .love zip archive of project_path, saved as output_path.
    Caller must ensure output_path is NOT inside project_path (use check_output_safe).
    """
    if logger: logger(f"开始创建 .love：{output_path}")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(output_path, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(project_path):
            dirs[:] = [d for d in dirs if d not in IGNORED_DIRS]
            for f in files:
                if f.endswith(('.pyc', '.pyo', '.DS_Store')):
                    continue
                file_path = Path(root) / f
                arcname = file_path.relative_to(project_path)
                zf.write(file_path, arcname.as_posix())

    if logger: logger(f".love 创建完成：{output_path}")
    return output_path


def check_output_safe(project_path: Path, output_dir: Path) -> str | None:
    """
    Check whether output_dir would cause the packing-itself bug.
    Returns an error message string if unsafe, or None if safe.

    Rule: output_dir (or any of its parents up to filesystem root) must not
    resolve to the same path as project_path.
    """
    try:
        p = project_path.resolve()
        o = output_dir.resolve()
        # Unsafe if output dir IS the project dir, or is directly inside it
        # (we check every ancestor of o up to p to catch nested cases)
        if o == p:
            return (
                f"输出目录与项目目录相同：\n{o}\n\n"
                "打包时会把正在生成的 .love 打包进自身，导致文件无限增长。\n"
                "请将输出目录设置到项目文件夹之外。"
            )
        # Check if o is inside p
        try:
            o.relative_to(p)
            # If we reach here, o is inside p
            return (
                f"输出目录在项目目录内部：\n{o}\n\n"
                "打包时会把 love_exports 文件夹打包进 .love，"
                "导致文件无限增长。\n"
                "请将输出目录设置到项目文件夹之外（例如项目的上级目录）。"
            )
        except ValueError:
            pass  # o is not inside p — safe
    except Exception:
        pass  # If anything goes wrong just allow it
    return None

def make_windows_exe(love_exe_path: Path, love_archive_path: Path, out_exe_path: Path, logger=None) -> Path:
    """
    Create a Windows exe by copying love_exe and appending .love bytes.
    Also tries to copy nearby DLLs from love_exe parent directory if exist.
    """
    if logger: logger(f"开始创建 Windows 可执行文件：{out_exe_path}")
    out_dir = out_exe_path.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    love_dir = love_exe_path.parent
    shutil.copy2(love_exe_path, out_exe_path)

    with open(out_exe_path, 'ab') as out_f, open(love_archive_path, 'rb') as in_f:
        out_f.write(in_f.read())

    if logger: logger(f"已生成 exe（拼接 .love）：{out_exe_path}")
    return out_exe_path


def png_to_ico(png_path: Path, ico_path: Path, logger=None) -> bool:
    """
    Convert a PNG file to ICO format using Pillow.
    Returns True on success.
    """
    try:
        from PIL import Image
    except ImportError:
        if logger: logger("⚠ 未安装 Pillow，无法转换图标。请运行：pip install Pillow")
        return False
    try:
        img = Image.open(png_path).convert("RGBA")
        # Generate multiple sizes for better icon quality
        sizes = [(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)]
        img.save(ico_path, format='ICO', sizes=sizes)
        if logger: logger(f"已将 PNG 转换为 ICO：{ico_path}")
        return True
    except Exception as e:
        if logger: logger(f"PNG 转 ICO 失败：{e}")
        return False


def find_rcedit(logger=None) -> Path | None:
    """
    Try to locate rcedit.exe in PATH or common locations.
    Returns Path if found, else None.
    """
    # Check PATH
    for name in ('rcedit.exe', 'rcedit-x64.exe', 'rcedit-x86.exe'):
        found = shutil.which(name)
        if found:
            return Path(found)
    # Check script directory
    script_dir = Path(__file__).parent
    for name in ('rcedit.exe', 'rcedit-x64.exe'):
        p = script_dir / name
        if p.exists():
            return p
    if logger: logger("未找到 rcedit.exe（可从 https://github.com/electron/rcedit/releases 下载并放在脚本同目录）")
    return None


def find_mt_exe(logger=None) -> Path | None:
    """
    Locate mt.exe (Windows Manifest Tool) from PATH or common VS/SDK install locations.
    """
    found = shutil.which("mt.exe")
    if found:
        return Path(found)

    # Common install paths for Windows SDK / Visual Studio
    sdk_roots = [
        Path(r"C:\Program Files (x86)\Windows Kits\10\bin"),
        Path(r"C:\Program Files\Windows Kits\10\bin"),
    ]
    for sdk_root in sdk_roots:
        if sdk_root.exists():
            # Walk subdirs like 10.0.xxxxx.0/x64/
            for subdir in sorted(sdk_root.iterdir(), reverse=True):
                for arch in ("x64", "x86"):
                    candidate = subdir / arch / "mt.exe"
                    if candidate.exists():
                        return candidate

    if logger:
        logger("未找到 mt.exe（Windows SDK 工具）。将尝试旁加载 manifest 作为备选。")
    return None


def apply_icon_and_manifest(exe_path: Path, ico_path: Path | None, manifest_xml: str | None, logger=None):
    """
    - Embed icon via rcedit (--set-icon only, rcedit does NOT support --set-manifest)
    - Embed manifest via mt.exe (Windows SDK tool)
    - Fall back to sidecar .manifest file if mt.exe is unavailable
    """
    # ── 1. Embed icon with rcedit ──────────────────────────────────────────
    if ico_path and ico_path.exists():
        rcedit = find_rcedit(logger)
        if rcedit:
            cmd = [str(rcedit), str(exe_path), '--set-icon', str(ico_path)]
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                if result.returncode == 0:
                    if logger: logger("✓ 图标已通过 rcedit 嵌入 exe")
                else:
                    if logger: logger(f"rcedit 嵌入图标失败：{result.stderr.strip() or result.stdout.strip()}")
            except Exception as e:
                if logger: logger(f"rcedit 执行失败：{e}")
        else:
            if logger: logger("⚠ 未找到 rcedit，无法嵌入图标（请将 rcedit.exe 放在脚本同目录）")

    # ── 2. Embed manifest with mt.exe ──────────────────────────────────────
    if manifest_xml:
        tmp_manifest = None
        try:
            with tempfile.NamedTemporaryFile(
                suffix='.manifest', delete=False, mode='w', encoding='utf-8'
            ) as tf:
                tf.write(manifest_xml)
                tmp_manifest = tf.name

            mt = find_mt_exe(logger)
            if mt:
                # Resource ID 1 = main application manifest
                cmd = [
                    str(mt),
                    '-nologo',
                    f'-manifest', tmp_manifest,
                    f'-outputresource:{exe_path};1',
                ]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                if result.returncode == 0:
                    if logger: logger("✓ DPI manifest 已通过 mt.exe 嵌入 exe")
                else:
                    err = result.stderr.strip() or result.stdout.strip()
                    if logger: logger(f"mt.exe 嵌入 manifest 失败：{err}，将改用旁加载文件。")
                    _write_sidecar_manifest(exe_path, manifest_xml, logger)
            else:
                _write_sidecar_manifest(exe_path, manifest_xml, logger)
        except Exception as e:
            if logger: logger(f"嵌入 manifest 时出现异常：{e}")
            _write_sidecar_manifest(exe_path, manifest_xml, logger)
        finally:
            if tmp_manifest:
                try:
                    os.unlink(tmp_manifest)
                except Exception:
                    pass


def apply_manifest(exe_path: Path, manifest_xml: str, logger=None):
    """Embed manifest into exe via mt.exe, or fall back to sidecar file."""
    tmp_manifest = None
    try:
        with tempfile.NamedTemporaryFile(
            suffix='.manifest', delete=False, mode='w', encoding='utf-8'
        ) as tf:
            tf.write(manifest_xml)
            tmp_manifest = tf.name

        mt = find_mt_exe(logger)
        if mt:
            cmd = [str(mt), '-nologo', '-manifest', tmp_manifest,
                   f'-outputresource:{exe_path};1']
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                if logger: logger("✓ DPI manifest 已通过 mt.exe 嵌入 exe")
            else:
                err = result.stderr.strip() or result.stdout.strip()
                if logger: logger(f"mt.exe 嵌入 manifest 失败：{err}，改用旁加载文件。")
                _write_sidecar_manifest(exe_path, manifest_xml, logger)
        else:
            _write_sidecar_manifest(exe_path, manifest_xml, logger)
    except Exception as e:
        if logger: logger(f"嵌入 manifest 时出现异常：{e}")
        _write_sidecar_manifest(exe_path, manifest_xml, logger)
    finally:
        if tmp_manifest:
            try:
                os.unlink(tmp_manifest)
            except Exception:
                pass


def _write_sidecar_manifest(exe_path: Path, manifest_xml: str | None, logger=None):
    """Write a sidecar <exe>.manifest file next to the exe."""
    if not manifest_xml:
        return
    manifest_path = exe_path.with_suffix('.exe.manifest')
    try:
        manifest_path.write_text(manifest_xml, encoding='utf-8')
        if logger: logger(f"✓ 已生成外部 manifest 文件（旁加载方式）：{manifest_path.name}")
        if logger: logger("  注意：外部 manifest 在某些系统可能需要管理员权限或组策略允许才能生效。")
        if logger: logger("  最佳方案是安装 rcedit 后重新打包，让 manifest 嵌入 exe 内部。")
    except Exception as e:
        if logger: logger(f"写入外部 manifest 失败：{e}")


def prepare_android_template(project_path: Path, love_archive_path: Path, out_dir: Path, project_name: str, logger=None) -> Path:
    if logger: logger("准备 Android 工程模板...")
    target = out_dir / f"android_build_{project_name}"
    assets_dir = target / "app" / "src" / "main" / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)

    dst_love = assets_dir / "game.love"
    shutil.copy2(love_archive_path, dst_love)
    if logger: logger(f"已把 .love 放到模板：{dst_love}")

    readme = target / "README_BUILD_APK.md"
    readme.write_text(
        f"# Android 构建说明（为 {project_name}）\n\n"
        "此目录为构建准备：\n\n"
        "1. 需要准备的工具：\n"
        "   - Java JDK（建议 11 或 17）\n"
        "   - Android SDK（包含平台工具 platform-tools）\n"
        "   - Android NDK（如果使用原生模板）\n"
        "   - love-android or a Love2D Android gradle project template (推荐参考 https://github.com/love2d/love-android)\n\n"
        "2. 推荐流程（假设你已经拿到 love-android 模板）：\n"
        "   - 将本目录的 app/src/main/assets/game.love 覆盖到 love-android 的对应位置\n"
        "   - 在 love-android 目录中，使用 gradle / Android Studio 构建：\n"
        "       ./gradlew assembleRelease\n"
        "   - 构建成功后，APK 在 app/build/outputs/apk/ 下\n\n"
        "3. 如果你不知道如何安装 JDK：\n"
        "   - 在 Windows 上可以下载 OpenJDK 分发版（Adoptium/Temurin），安装后在环境变量中配置 JAVA_HOME\n"
        "   - 在命令行运行 `java -version` 验证\n\n"
        "4. 本工具只负责生成 game.love 并创建构建模板目录。\n"
    )
    if logger: logger(f"已生成 README：{readme}")
    return target

# -----------------------
# GUI
# -----------------------

class LoveExporterApp:
    def __init__(self, root):
        self.root = root
        self.current_lang = 'zh'  # Default language: Chinese
        self._ui_widgets = {}  # Store widgets that need text updates
        
        # String variables (need to be re-assigned on language change)
        self.project_path = tk.StringVar()
        self.love_exe_path = tk.StringVar()
        self.jdk_path = tk.StringVar()
        self.icon_png_path = tk.StringVar()
        self.export_windows = tk.BooleanVar(value=True)
        self.export_apk = tk.BooleanVar(value=False)
        self.embed_dpi_manifest = tk.BooleanVar(value=True)
        self.output_dir = tk.StringVar(value=str(Path.cwd() / "love_exports"))

        # Progress / timer state
        self._export_running = False
        self._start_time = 0.0
        self._timer_after_id = None

        self._build_ui()
        self._update_ui_texts()  # Initialize UI texts

    def tr(self, key: str, *args) -> str:
        """Get translated text for the current language."""
        text = LANGUAGES[self.current_lang].get(key, key)
        if args:
            return text.format(*args)
        return text

    def _build_ui(self):
        pad = 8
        frm = ttk.Frame(self.root, padding=pad)
        frm.pack(fill=tk.BOTH, expand=True)

        # Top bar with language switch button
        top_bar = ttk.Frame(frm)
        top_bar.pack(fill=tk.X, pady=(0, 4))
        
        self.lang_btn = ttk.Button(top_bar, text="English", command=self._toggle_language)
        self.lang_btn.pack(side=tk.RIGHT)
        self._ui_widgets['lang_btn'] = self.lang_btn

        # Project path
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=4)
        self.project_label = ttk.Label(row, text=self.tr('project_label'))
        self.project_label.pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=self.project_path).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=6)
        self.browse_project_btn = ttk.Button(row, text=self.tr('browse_btn'), command=self.browse_project)
        self.browse_project_btn.pack(side=tk.LEFT)
        self._ui_widgets['project_label'] = self.project_label
        self._ui_widgets['browse_project_btn'] = self.browse_project_btn

        # love.exe path (optional)
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=4)
        self.love_exe_label = ttk.Label(row, text=self.tr('love_exe_label'))
        self.love_exe_label.pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=self.love_exe_path).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=6)
        self.browse_love_btn = ttk.Button(row, text=self.tr('browse_btn'), command=self.browse_love_exe)
        self.browse_love_btn.pack(side=tk.LEFT)
        self.auto_detect_btn = ttk.Button(row, text=self.tr('auto_detect_btn'), command=self.auto_detect_love)
        self.auto_detect_btn.pack(side=tk.LEFT, padx=4)
        self._ui_widgets['love_exe_label'] = self.love_exe_label
        self._ui_widgets['browse_love_btn'] = self.browse_love_btn
        self._ui_widgets['auto_detect_btn'] = self.auto_detect_btn

        # Output dir
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=4)
        self.output_label = ttk.Label(row, text=self.tr('output_label'))
        self.output_label.pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=self.output_dir).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=6)
        self.browse_output_btn = ttk.Button(row, text=self.tr('browse_btn'), command=self.browse_output)
        self.browse_output_btn.pack(side=tk.LEFT)
        self._ui_widgets['output_label'] = self.output_label
        self._ui_widgets['browse_output_btn'] = self.browse_output_btn

        # Icon PNG
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=4)
        self.icon_label = ttk.Label(row, text=self.tr('icon_label'))
        self.icon_label.pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=self.icon_png_path).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=6)
        self.select_png_btn = ttk.Button(row, text=self.tr('select_png_btn'), command=self.browse_icon_png)
        self.select_png_btn.pack(side=tk.LEFT)
        self.clear_icon_btn = ttk.Button(row, text=self.tr('clear_btn'), command=lambda: self.icon_png_path.set(""))
        self.clear_icon_btn.pack(side=tk.LEFT, padx=2)
        self._ui_widgets['icon_label'] = self.icon_label
        self._ui_widgets['select_png_btn'] = self.select_png_btn
        self._ui_widgets['clear_icon_btn'] = self.clear_icon_btn

        # Platforms
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=6)
        self.platform_label = ttk.Label(row, text=self.tr('platform_label'))
        self.platform_label.pack(side=tk.LEFT)
        self.windows_check = ttk.Checkbutton(row, text=self.tr('windows_check'), variable=self.export_windows)
        self.windows_check.pack(side=tk.LEFT, padx=6)
        self.android_check = ttk.Checkbutton(row, text=self.tr('android_check'), variable=self.export_apk)
        self.android_check.pack(side=tk.LEFT, padx=6)
        self.jdk_help_btn = ttk.Button(row, text=self.tr('jdk_help_btn'), command=self.show_jdk_help)
        self.jdk_help_btn.pack(side=tk.LEFT, padx=6)
        self._ui_widgets['platform_label'] = self.platform_label
        self._ui_widgets['windows_check_text'] = self.windows_check
        self._ui_widgets['android_check_text'] = self.android_check
        self._ui_widgets['jdk_help_btn'] = self.jdk_help_btn

        # DPI Manifest
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=2)
        self.dpi_check = ttk.Checkbutton(
            row,
            text=self.tr('dpi_check'),
            variable=self.embed_dpi_manifest
        )
        self.dpi_check.pack(side=tk.LEFT, padx=6)
        self.dpi_help_btn = ttk.Button(row, text=self.tr('dpi_help_btn'), command=self.show_dpi_help)
        self.dpi_help_btn.pack(side=tk.LEFT)
        self._ui_widgets['dpi_check_text'] = self.dpi_check
        self._ui_widgets['dpi_help_btn'] = self.dpi_help_btn

        # JDK path (optional)
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=4)
        self.jdk_label = ttk.Label(row, text=self.tr('jdk_label'))
        self.jdk_label.pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=self.jdk_path).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=6)
        self.check_java_btn = ttk.Button(row, text=self.tr('check_java_btn'), command=self.check_java_version)
        self.check_java_btn.pack(side=tk.LEFT)
        self._ui_widgets['jdk_label'] = self.jdk_label
        self._ui_widgets['check_java_btn'] = self.check_java_btn

        # Buttons
        row = ttk.Frame(frm)
        row.pack(fill=tk.X, pady=8)
        self.btn_export = ttk.Button(row, text=self.tr('export_btn'), command=self.on_export)
        self.btn_export.pack(side=tk.LEFT, padx=6)
        self.open_output_btn = ttk.Button(row, text=self.tr('open_output_btn'), command=self.open_output_dir)
        self.open_output_btn.pack(side=tk.LEFT, padx=6)
        self.exit_btn = ttk.Button(row, text=self.tr('exit_btn'), command=self.root.quit)
        self.exit_btn.pack(side=tk.RIGHT, padx=6)
        self._ui_widgets['export_btn'] = self.btn_export
        self._ui_widgets['open_output_btn'] = self.open_output_btn
        self._ui_widgets['exit_btn'] = self.exit_btn

        # Progress bar + status label + timer
        prog_row = ttk.Frame(frm)
        prog_row.pack(fill=tk.X, padx=4, pady=(0, 2))

        self.progress_bar = ttk.Progressbar(prog_row, mode='indeterminate', length=200)
        self.progress_bar.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 8))

        self.status_label = ttk.Label(prog_row, text=self.tr('status_ready'), width=18, anchor=tk.W)
        self.status_label.pack(side=tk.LEFT)

        self.timer_label = ttk.Label(prog_row, text="", width=8, anchor=tk.E, foreground="#555555")
        self.timer_label.pack(side=tk.LEFT, padx=(4, 0))
        self._ui_widgets['status_label'] = self.status_label

        # Log area
        self.log_label = ttk.Label(frm, text=self.tr('log_label'))
        self.log_label.pack(anchor=tk.W, padx=2)
        self.log_text = ScrolledText(frm, height=12, state='disabled')
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=4, pady=4)
        self._ui_widgets['log_label'] = self.log_label

    def _update_ui_texts(self):
        """Update all UI text elements when language changes."""
        # Update window title
        self.root.title(self.tr('window_title'))
        
        # Update labels and buttons
        for widget_key, widget in self._ui_widgets.items():
            if widget_key.endswith('_label'):
                text_key = widget_key
                if hasattr(widget, 'config'):
                    widget.config(text=self.tr(text_key))
            elif widget_key in ['browse_project_btn', 'browse_love_btn', 'browse_output_btn',
                                'select_png_btn', 'clear_icon_btn', 'auto_detect_btn',
                                'jdk_help_btn', 'dpi_help_btn', 'check_java_btn',
                                'export_btn', 'open_output_btn', 'exit_btn', 'lang_btn']:
                if hasattr(widget, 'config'):
                    text_key = widget_key.replace('_btn', '_btn')
                    if widget_key == 'lang_btn':
                        # Toggle button text based on language
                        widget.config(text=self.tr('language_switch_btn'))
                    else:
                        # Map button keys to translation keys
                        btn_map = {
                            'browse_project_btn': 'browse_btn',
                            'browse_love_btn': 'browse_btn',
                            'browse_output_btn': 'browse_btn',
                            'select_png_btn': 'select_png_btn',
                            'clear_icon_btn': 'clear_btn',
                            'auto_detect_btn': 'auto_detect_btn',
                            'jdk_help_btn': 'jdk_help_btn',
                            'dpi_help_btn': 'dpi_help_btn',
                            'check_java_btn': 'check_java_btn',
                            'export_btn': 'export_btn',
                            'open_output_btn': 'open_output_btn',
                            'exit_btn': 'exit_btn',
                        }
                        widget.config(text=self.tr(btn_map.get(widget_key, widget_key)))
        
        # Update checkbutton texts
        if hasattr(self, 'windows_check'):
            self.windows_check.config(text=self.tr('windows_check'))
        if hasattr(self, 'android_check'):
            self.android_check.config(text=self.tr('android_check'))
        if hasattr(self, 'dpi_check'):
            self.dpi_check.config(text=self.tr('dpi_check'))
        
        # Update status label
        if hasattr(self, 'status_label') and not self._export_running:
            self.status_label.config(text=self.tr('status_ready'))

    def _toggle_language(self):
        """Toggle between Chinese and English."""
        self.current_lang = 'en' if self.current_lang == 'zh' else 'zh'
        self._update_ui_texts()
        self._log(self.tr('export_start'))  # Just to show language change in log

    # -----------------
    # UI callbacks
    # -----------------
    def browse_project(self):
        path = filedialog.askdirectory(title="选择 Love2D 项目文件夹")
        if path:
            self.project_path.set(path)
            self.auto_detect_love()

    def browse_love_exe(self):
        path = filedialog.askopenfilename(title="选择 love.exe",
                                          filetypes=[("EXE", "*.exe"), ("All files", "*.*")])
        if path:
            self.love_exe_path.set(path)

    def browse_icon_png(self):
        path = filedialog.askopenfilename(
            title="选择图标 PNG 文件",
            filetypes=[("PNG 图片", "*.png"), ("所有文件", "*.*")]
        )
        if path:
            self.icon_png_path.set(path)

    def auto_detect_love(self):
        p = Path(self.project_path.get() or "")
        if not p.exists():
            messagebox.showinfo(self.tr('auto_detect_title'), self.tr('auto_detect_msg'))
            return
        candidate = p / "love.exe"
        if candidate.exists():
            self.love_exe_path.set(str(candidate))
            self._log(self.tr('auto_detect_found', str(candidate)))
        else:
            candidate2 = p.parent / "love.exe"
            if candidate2.exists():
                self.love_exe_path.set(str(candidate2))
                self._log(self.tr('auto_detect_parent', str(candidate2)))
            else:
                self._log(self.tr('auto_detect_not_found'))

    def browse_output(self):
        path = filedialog.askdirectory(title="选择输出目录", initialdir=self.output_dir.get())
        if path:
            self.output_dir.set(path)

    def show_dpi_help(self):
        messagebox.showinfo(self.tr('dpi_help_title'), self.tr('dpi_help_msg'))

    def show_jdk_help(self):
        messagebox.showinfo(self.tr('jdk_help_title'), self.tr('jdk_help_msg'))

    def check_java_version(self):
        jdk = self.jdk_path.get().strip()
        if jdk:
            java_bin = Path(jdk) / "bin" / ("java.exe" if os.name == 'nt' else "java")
            cmd = [str(java_bin), "-version"] if java_bin.exists() else ["java", "-version"]
        else:
            cmd = ["java", "-version"]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
            output = proc.stderr.strip() or proc.stdout.strip()
            messagebox.showinfo(self.tr('java_version_title'), f"命令：{' '.join(cmd)}\n\n输出：\n{output}")
        except Exception as e:
            messagebox.showerror(self.tr('java_version_error_title'), self.tr('java_version_error_msg', str(e)))

    def open_output_dir(self):
        out = Path(self.output_dir.get())
        out.mkdir(parents=True, exist_ok=True)
        try:
            if sys.platform == "win32":
                os.startfile(out)
            elif sys.platform == "darwin":
                subprocess.run(["open", str(out)])
            else:
                subprocess.run(["xdg-open", str(out)])
        except Exception as e:
            messagebox.showerror(self.tr('open_output_failed'), f"{e}")

    def _log(self, msg: str):
        log_append(self.log_text, msg)

    # -----------------
    # Progress / timer helpers
    # -----------------
    def _start_progress(self, status=None):
        self._export_running = True
        self._start_time = time.monotonic()
        if status:
            self.status_label.config(text=status)
        else:
            self.status_label.config(text=self.tr('status_processing'))
        self.timer_label.config(text="0:00")
        self.btn_export.config(state=tk.DISABLED)
        self.progress_bar.start(12)
        self._tick_timer()

    def _tick_timer(self):
        if not self._export_running:
            return
        elapsed = int(time.monotonic() - self._start_time)
        mins, secs = divmod(elapsed, 60)
        self.timer_label.config(text=f"{mins}:{secs:02d}")
        self._timer_after_id = self.root.after(500, self._tick_timer)

    def _stop_progress(self, status=None):
        self._export_running = False
        if self._timer_after_id:
            self.root.after_cancel(self._timer_after_id)
            self._timer_after_id = None
        self.progress_bar.stop()
        elapsed = time.monotonic() - self._start_time
        mins, secs = divmod(int(elapsed), 60)
        self.timer_label.config(text=f"{mins}:{secs:02d}")
        if status:
            self.status_label.config(text=status)
        else:
            self.status_label.config(text=self.tr('status_ready'))
        self.btn_export.config(state=tk.NORMAL)

    def _set_status(self, text: str):
        """Update the status label from any thread via root.after."""
        self.root.after(0, lambda: self.status_label.config(text=text))

    def on_export(self):
        project = self.project_path.get().strip()
        if not project:
            messagebox.showwarning(self.tr('warning_no_project'), self.tr('warning_no_project_msg'))
            return
        project_path = Path(project)
        if not project_path.exists() or not project_path.is_dir():
            messagebox.showerror(self.tr('error_invalid_path'), self.tr('error_invalid_path_msg'))
            return
        if not (self.export_windows.get() or self.export_apk.get()):
            messagebox.showwarning(self.tr('warning_no_platform'), self.tr('warning_no_platform_msg'))
            return

        self._start_progress(self.tr('status_processing'))
        t = threading.Thread(target=self._do_export, args=(project_path,), daemon=True)
        t.start()

    def _do_export(self, project_path: Path):
        try:
            self._log(self.tr('export_start'))
            out_base = Path(self.output_dir.get())
            out_base.mkdir(parents=True, exist_ok=True)

            project_name = project_path.name
            love_name = f"{project_name}.love"
            love_archive_path = out_base / love_name

            # 1) Safety check: ensure output dir is not inside project dir
            safety_err = check_output_safe(project_path, out_base)
            if safety_err:
                # Use translated error message - replace with appropriate mapping
                self._log(self.tr('export_blocked', safety_err))
                self.root.after(0, lambda: self._stop_progress(self.tr('status_cancelled')))
                messagebox.showerror(self.tr('export_failed_title'), safety_err)
                return

            # 2) Create .love
            self._set_status(self.tr('status_packing_love'))
            create_love_archive(project_path, love_archive_path, logger=self._log)

            # 2) Prepare ICO (convert PNG if provided)
            ico_path = None
            png_src = self.icon_png_path.get().strip()
            if png_src and Path(png_src).exists():
                self._set_status(self.tr('status_converting_icon'))
                ico_path = out_base / f"{project_name}_icon.ico"
                success = png_to_ico(Path(png_src), ico_path, logger=self._log)
                if not success:
                    ico_path = None
            elif png_src:
                self._log(self.tr('png_convert_failed', "file not found"))

            # 3) Windows export
            if self.export_windows.get():
                self._set_status(self.tr('status_generating_exe'))
                out_exe = self._build_windows_exe(
                    project_path, project_name, love_archive_path, out_base, ico_path,
                    logger=self._log
                )

                # Only embed manifest AFTER .love is appended (rcedit would strip appended data)
                if out_exe and out_exe.exists():
                    manifest_xml = DPI_MANIFEST_XML if self.embed_dpi_manifest.get() else None
                    if manifest_xml:
                        self._set_status(self.tr('status_embedding_manifest'))
                        apply_manifest(out_exe, manifest_xml, logger=self._log)

            # 4) APK template
            if self.export_apk.get():
                self._set_status(self.tr('status_generating_android'))
                try:
                    android_dir = prepare_android_template(project_path, love_archive_path, out_base, project_name, logger=self._log)
                    self._log(self.tr('android_template_generated', str(android_dir)))
                    self._log(self.tr('android_template_readme'))
                except Exception as e:
                    self._log(self.tr('android_template_failed', str(e)))

            self._log(self.tr('export_complete'))
            self.root.after(0, lambda: self._stop_progress(self.tr('status_done')))
            messagebox.showinfo(self.tr('export_done_title'), self.tr('export_done_msg'))
        except Exception as e:
            self._log(self.tr('export_exception', str(e)))
            self.root.after(0, lambda: self._stop_progress(self.tr('status_error')))
            messagebox.showerror(self.tr('export_failed_title'), self.tr('export_failed_msg', str(e)))

    def _build_windows_exe(self, project_path: Path, project_name: str,
                           love_archive_path: Path, out_base: Path,
                           ico_path: Path | None = None, logger=None):
        """
        Build the windows exe and return its path, or None on failure.

        Icon is applied to a TEMP copy of love.exe BEFORE appending .love,
        because rcedit rewrites the PE and would strip any data appended after it.
        """
        love_exe = self.love_exe_path.get().strip()
        found = None
        if love_exe:
            candidate = Path(love_exe)
            if candidate.exists():
                found = candidate
            else:
                self._log(self.tr('love_exe_not_found', str(candidate)))
                return None
        else:
            for c in (project_path / "love.exe", project_path.parent / "love.exe"):
                if c.exists():
                    found = c
                    self._log(self.tr('love_exe_auto_detected', str(found)))
                    break

        if not found:
            self._log(self.tr('love_exe_missing'))
            return None

        out_exe = out_base / f"{project_name}.exe"
        try:
            # --- Step A: copy love.exe to a temp file and apply icon there first ---
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".exe", delete=False, dir=out_base) as tf:
                tmp_base_exe = Path(tf.name)
            shutil.copy2(found, tmp_base_exe)

            if ico_path and ico_path.exists():
                self._set_status("Embedding icon...")
                rcedit = find_rcedit(self._log)
                if rcedit:
                    cmd = [str(rcedit), str(tmp_base_exe), "--set-icon", str(ico_path)]
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                    if result.returncode == 0:
                        self._log(self.tr('icon_embedded_pre'))
                    else:
                        self._log(self.tr('icon_embed_failed', result.stderr.strip() or result.stdout.strip()))
                else:
                    self._log(self.tr('rcedit_missing'))

            # --- Step B: append .love to the (possibly icon-modified) temp exe ---
            self._set_status(self.tr('status_generating_exe'))
            make_windows_exe(tmp_base_exe, love_archive_path, out_exe, logger=self._log)

            # Clean up temp file
            try:
                tmp_base_exe.unlink()
            except Exception:
                pass

            # --- Step C: copy DLLs from the ORIGINAL love.exe directory ---
            love_dir = found.parent
            for candidate in ('love.dll', 'SDL2.dll', 'SDL3.dll', 'openal32.dll', 'lua51.dll', 'mpg123.dll'):
                src = love_dir / candidate
                if src.exists():
                    try:
                        shutil.copy2(src, out_base / src.name)
                        self._log(self.tr('copying_dll', src.name))
                    except Exception as e:
                        self._log(self.tr('copy_dll_failed', src.name, str(e)))

            self._log(self.tr('windows_exe_generated', str(out_exe)))
            return out_exe
        except Exception as e:
            self._log(self.tr('windows_exe_failed', str(e)))
            return None

# -----------------------
# Run app
# -----------------------

def main():
    root = tk.Tk()
    app = LoveExporterApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()