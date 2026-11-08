"""Pack the project into a .love file without opening the tkinter GUI.

This mirrors Packager/build_tool.py's defaults (same exclusion set, same
deflate level, same lower-cased sort order) so the archive is byte-for-byte
comparable to what the GUI produces. It deliberately does NOT import
build_tool.py: that module imports tkinter at load time, and a Python build
without tkinter would fail here for no reason.

    python make_love.py                     # -> <project>/Export/soulengine.love
    python make_love.py --name mygame
    python make_love.py --out D:/tmp/x.love
"""

import argparse
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))

# Directory *names* never packaged: VCS/tooling (as in build_tool.py) plus the
# packager itself, its output, and the separately maintained docs dump.
EXCLUDE_DIRS = {
    ".git", ".svn", ".hg", ".idea", ".vscode", "__pycache__", "node_modules",
    ".cache", ".gradle", ".workbuddy",
    "documentation", "packager", "export", "soulengine-doc3",
}
EXCLUDE_EXTS = {".love", ".pyc", ".pyo", ".tmp", ".bak"}


def iter_files(project):
    project = os.path.abspath(project)
    for root, dirs, files in os.walk(project, onerror=lambda e: None):
        dirs[:] = [d for d in dirs if d.lower() not in EXCLUDE_DIRS]
        for name in files:
            if os.path.splitext(name)[1].lower() in EXCLUDE_EXTS:
                continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, project).replace(os.sep, "/")
            yield rel, path


def main():
    ap = argparse.ArgumentParser(description="Pack the project into a .love file.")
    ap.add_argument("--project", default=os.path.dirname(HERE), help="project root")
    ap.add_argument("--name", default="soulengine", help="output base name")
    ap.add_argument("--out", default=None, help="output .love path")
    args = ap.parse_args()

    project = os.path.abspath(args.project)
    if not os.path.isfile(os.path.join(project, "main.lua")):
        sys.exit("[ERROR] no main.lua in %s" % project)

    out = os.path.abspath(args.out or os.path.join(project, "Export", args.name + ".love"))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if os.path.isfile(out):
        os.remove(out)

    items = sorted(iter_files(project), key=lambda t: t[0].lower())
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for rel, path in items:
            zf.write(path, rel)

    print("files = %d" % len(items))
    print("size  = %.1f MB" % (os.path.getsize(out) / 1048576.0))
    print("out   = %s" % out)


if __name__ == "__main__":
    main()
