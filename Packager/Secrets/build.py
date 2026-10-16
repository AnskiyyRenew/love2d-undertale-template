# -*- coding: utf-8 -*-
"""
Builds the native secret store for every target platform.

Pipeline: gen_source.py emits an obfuscated secrets.c, this script compiles it
into a shared library per platform and drops the results where the runtime and
the packager expect them:

    Resources/Libs/Secrets/secrets.dll                  Windows (x86_64)
    Resources/Libs/Secrets/android/<abi>/libsecrets.so  Android

The Windows build needs a 64-bit MinGW gcc -- the LÖVE Windows binary is a
64-bit process, so a 32-bit toolchain produces a DLL that silently fails to
load. The Android build needs the NDK; if it cannot be found the Android step
is skipped with a message instead of failing the whole run, because the Windows
artifact is what you need for day-to-day development.

Usage:
    python build.py                      # everything that a toolchain allows
    python build.py --target windows
    python build.py --target android --ndk D:/android-sdk/ndk/27.3...
    python build.py --gcc D:/tools/Dev-Cpp/MinGW64/bin/gcc.exe
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(HERE, os.pardir, os.pardir))
LIB_DIR = os.path.join(PROJECT_ROOT, "Resources", "Libs", "Secrets")
BUILD_DIR = os.path.join(HERE, "build")
SOURCE_C = os.path.join(BUILD_DIR, "secrets.c")
SECRETS_JSON = os.path.join(HERE, "secrets.local.json")

# Android ABIs to build. arm64-v8a is mandatory for Play; armeabi-v7a covers
# older 32-bit devices; x86_64 is emulator-only but costs nothing.
ANDROID_ABIS = (
    ("arm64-v8a", "aarch64-linux-android"),
    ("armeabi-v7a", "armv7a-linux-androideabi"),
    ("x86_64", "x86_64-linux-android"),
)
ANDROID_API = 21

# Where ffi.load will find the library at runtime. See Secrets.lua.
DLL_NAME = "secrets.dll"
SO_NAME = "libsecrets.so"


def run(cmd: list[str]) -> tuple[int, str]:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True,
                              encoding="utf-8", errors="replace")
    except OSError as exc:
        return 1, str(exc)
    out = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, out.strip()


def find_gcc(explicit: str | None) -> str | None:
    if explicit:
        return explicit if os.path.isfile(explicit) else None
    candidates = [
        r"D:/tools/Dev-Cpp/MinGW64/bin/gcc.exe",
        r"C:/tools/Dev-Cpp/MinGW64/bin/gcc.exe",
        r"C:/msys64/mingw64/bin/gcc.exe",
        r"C:/mingw64/bin/gcc.exe",
        r"C:/TDM-GCC-64/bin/gcc.exe",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    found = shutil_which("gcc")
    return found


def shutil_which(name: str) -> str | None:
    from shutil import which
    return which(name)


def find_ndk(explicit: str | None) -> str | None:
    """Locate an NDK root that actually contains the LLVM toolchain."""
    candidates = []
    if explicit:
        candidates.append(explicit)
    env = os.environ.get("ANDROID_NDK_HOME") or os.environ.get("NDK_HOME")
    if env:
        candidates.append(env)
    for base_var in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        base = os.environ.get(base_var)
        if base:
            ndk_root = os.path.join(base, "ndk")
            if os.path.isdir(ndk_root):
                try:
                    for entry in sorted(os.listdir(ndk_root), reverse=True):
                        candidates.append(os.path.join(ndk_root, entry))
                except OSError:
                    pass
    for base in (r"C:/Users/%s/AppData/Local/Android/Sdk/ndk" % os.environ.get("USERNAME", ""),
                 r"C:/Android/Sdk/ndk", r"D:/Android/Sdk/ndk",
                 r"D:/android-sdk/ndk", r"D:/android-setup/ndk"):
        if os.path.isdir(base):
            try:
                for entry in sorted(os.listdir(base), reverse=True):
                    candidates.append(os.path.join(base, entry))
            except OSError:
                pass

    for root in candidates:
        if not root or not os.path.isdir(root):
            continue
        clang = os.path.join(root, "toolchains", "llvm", "prebuilt",
                             "windows-x86_64", "bin", "clang.exe")
        if os.path.isfile(clang):
            return root
    return None


def ndk_clang(ndk_root: str) -> str:
    return os.path.join(ndk_root, "toolchains", "llvm", "prebuilt",
                        "windows-x86_64", "bin", "clang.exe")


def generate_source(seed: int | None) -> bool:
    cmd = [sys.executable, os.path.join(HERE, "gen_source.py"),
           "--input", SECRETS_JSON, "--output", SOURCE_C]
    if seed is not None:
        cmd += ["--seed", str(seed)]
    code, out = run(cmd)
    print(out)
    if code != 0:
        print("[secrets] source generation FAILED")
        return False
    return True


def build_windows(gcc: str) -> bool:
    out_path = os.path.join(LIB_DIR, DLL_NAME)
    os.makedirs(LIB_DIR, exist_ok=True)
    cmd = [gcc, "-O2", "-shared", "-s", "-fvisibility=hidden",
           "-o", out_path, SOURCE_C]
    code, out = run(cmd)
    if code != 0:
        print("[secrets] Windows build FAILED:\n%s" % out)
        return False
    if out:
        print("  (compiler notes) %s" % out.replace("\n", "\n  "))
    print("[secrets] Windows  -> %s (%d bytes)"
          % (out_path, os.path.getsize(out_path)))
    return True


def build_android(ndk_root: str, abis: list[str], api: int) -> bool:
    clang = ndk_clang(ndk_root)
    ok = True
    for abi, target in ANDROID_ABIS:
        if abis and abi not in abis:
            continue
        out_dir = os.path.join(LIB_DIR, "android", abi)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, SO_NAME)
        cmd = [
            clang,
            "--target=%s%d" % (target, api),
            "-O2", "-shared", "-fPIC", "-s",
            "-fvisibility=hidden",
            "-o", out_path, SOURCE_C,
        ]
        code, out = run(cmd)
        if code != 0:
            print("[secrets] Android %s FAILED:\n%s" % (abi, out))
            ok = False
            continue
        print("[secrets] Android %s -> %s (%d bytes)"
              % (abi, out_path, os.path.getsize(out_path)))
    return ok


def main() -> int:
    ap = argparse.ArgumentParser(description="Build the native secret store.")
    ap.add_argument("--target", default="all",
                    choices=("all", "windows", "android"),
                    help="which platform to build (default: all)")
    ap.add_argument("--gcc", default=None, help="path to a 64-bit MinGW gcc.exe")
    ap.add_argument("--ndk", default=None, help="path to the Android NDK root")
    ap.add_argument("--abi", default=None,
                    help="comma-separated Android ABIs (default: all three)")
    ap.add_argument("--api", type=int, default=ANDROID_API,
                    help="Android API level (default: %d)" % ANDROID_API)
    ap.add_argument("--seed", type=int, default=None,
                    help="fixed RNG seed for reproducible builds")
    args = ap.parse_args()

    if not os.path.isfile(SECRETS_JSON):
        print("missing %s" % SECRETS_JSON)
        print("copy secrets.local.example.json -> secrets.local.json and fill it in")
        return 1

    if not generate_source(args.seed):
        return 1

    abis = [a.strip() for a in args.abi.split(",")] if args.abi else []
    status = 0

    if args.target in ("all", "windows"):
        gcc = find_gcc(args.gcc)
        if not gcc:
            print("[secrets] no 64-bit MinGW gcc found; pass --gcc <path>")
            status = 1
        else:
            print("[secrets] gcc: %s" % gcc)
            if not build_windows(gcc):
                status = 1

    if args.target in ("all", "android"):
        ndk = find_ndk(args.ndk)
        if not ndk:
            print("[secrets] Android NDK not found -- skipping Android build.")
            print("           install it and re-run with --ndk <path>")
            print("           (APK packaging needs the .so files; the Windows")
            print("            build alone is fine for local development)")
        else:
            print("[secrets] ndk: %s" % ndk)
            if not build_android(ndk, abis, args.api):
                status = 1

    return status


if __name__ == "__main__":
    sys.exit(main())
