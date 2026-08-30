"""统计项目中 Lua 文件的行数和大小，并列出最大的十个文件。"""

import argparse
from pathlib import Path


def file_stats(path):
    data = path.read_bytes()
    lines = data.count(b"\n")
    if data and not data.endswith(b"\n"):
        lines += 1
    return lines, len(data)


def collect_stats(root):
    stats = []
    for path in root.rglob("*.lua"):
        if path.is_file():
            lines, size = file_stats(path)
            stats.append((path, lines, size))
    return stats


def format_size(size):
    units = ("B", "KB", "MB", "GB")
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{size} B"
        value /= 1024


def main():
    parser = argparse.ArgumentParser(
        description="统计目录下所有 Lua 文件的行数和大小，并列出最大的十个文件。"
    )
    parser.add_argument(
        "root",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="要统计的目录，默认是项目根目录",
    )
    args = parser.parse_args()
    root = args.root.resolve()

    if not root.is_dir():
        parser.error(f"目录不存在: {root}")

    stats = collect_stats(root)
    stats.sort(key=lambda item: item[2], reverse=True)

    print(f"统计目录: {root}")
    print(f"Lua 文件总数: {len(stats)}")
    print(f"总行数: {sum(item[1] for item in stats):,}")
    print(f"总大小: {format_size(sum(item[2] for item in stats))}")
    print("\n按文件大小排序的前十个文件:")
    print(f"{'排名':>4}  {'大小':>10}  {'行数':>8}  文件")
    print("-" * 70)

    for rank, (path, lines, size) in enumerate(stats[:10], start=1):
        relative_path = path.relative_to(root)
        print(f"{rank:>4}  {format_size(size):>10}  {lines:>8,}  {relative_path}")


if __name__ == "__main__":
    main()