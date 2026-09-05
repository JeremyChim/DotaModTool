"""Build the Windows application and create its release archive.

The generated archive contains the executable and its external runtime data.
All intermediate PyInstaller files are created in a temporary directory.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENTRY_POINT = PROJECT_ROOT / "win.py"
RELEASE_DIR = PROJECT_ROOT / "release"
RESOURCE_DIRS = ("npc", "gi", "vpk")
RESOURCE_FILES = ("config.json",)
DEFAULT_NAME = "DotaModTool"
REPLACE_RETRIES = 10


class BuildError(RuntimeError):
    """Raised when the release cannot be built."""


def check_inputs() -> None:
    """Fail early with a useful message when a required input is missing."""
    required = [ENTRY_POINT]
    required.extend(PROJECT_ROOT / name for name in RESOURCE_DIRS)
    required.extend(PROJECT_ROOT / name for name in RESOURCE_FILES)
    missing = [path for path in required if not path.exists()]
    if missing:
        paths = "\n".join(f"  - {path}" for path in missing)
        raise BuildError(f"缺少打包所需的文件或目录：\n{paths}")


def run_pyinstaller(name: str, temp_dir: Path, console: bool) -> Path:
    """Build and return the executable produced by PyInstaller."""
    dist_dir = temp_dir / "dist"
    work_dir = temp_dir / "work"
    spec_dir = temp_dir / "spec"
    spec_dir.mkdir(parents=True)
    command = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--onefile",
        "--name",
        name,
        "--distpath",
        str(dist_dir),
        "--workpath",
        str(work_dir),
        "--specpath",
        str(spec_dir),
        "--console" if console else "--windowed",
        str(ENTRY_POINT),
    ]

    print(f"[1/3] 正在构建 {name}.exe ...")
    try:
        subprocess.run(command, cwd=PROJECT_ROOT, check=True)
    except subprocess.CalledProcessError as exc:
        raise BuildError(f"PyInstaller 构建失败（退出码 {exc.returncode}）") from exc

    executable = dist_dir / f"{name}.exe"
    if not executable.is_file():
        raise BuildError(f"PyInstaller 未生成预期文件：{executable}")
    return executable


def copy_release_files(executable: Path, stage_dir: Path) -> None:
    """Create the directory tree that will become the archive contents."""
    print("[2/3] 正在整理发布文件 ...")
    shutil.copy2(executable, stage_dir / executable.name)
    for directory in RESOURCE_DIRS:
        shutil.copytree(
            PROJECT_ROOT / directory,
            stage_dir / directory,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo"),
        )
    for filename in RESOURCE_FILES:
        shutil.copy2(PROJECT_ROOT / filename, stage_dir / filename)


def create_zip(stage_dir: Path, archive: Path) -> None:
    """Create via a temporary file so a failed build preserves the old ZIP."""
    print(f"[3/3] 正在生成 {archive.name} ...")
    temporary_archive = archive.with_suffix(archive.suffix + ".tmp")
    try:
        with zipfile.ZipFile(
            temporary_archive,
            mode="w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as output:
            for path in sorted(stage_dir.rglob("*")):
                if path.is_file():
                    output.write(path, path.relative_to(stage_dir))
        for attempt in range(REPLACE_RETRIES):
            try:
                os.replace(temporary_archive, archive)
                break
            except PermissionError:
                if attempt == REPLACE_RETRIES - 1:
                    raise
                time.sleep(0.5)
    finally:
        temporary_archive.unlink(missing_ok=True)


def build(name: str = DEFAULT_NAME, console: bool = False) -> Path:
    """Build the executable and return the finished ZIP path."""
    check_inputs()
    RELEASE_DIR.mkdir(parents=True, exist_ok=True)
    archive = RELEASE_DIR / f"{name}.zip"

    with tempfile.TemporaryDirectory(prefix="dota-mod-tool-build-") as raw_temp:
        temp_dir = Path(raw_temp)
        executable = run_pyinstaller(name, temp_dir, console)
        stage_dir = temp_dir / "package"
        stage_dir.mkdir()
        copy_release_files(executable, stage_dir)
        create_zip(stage_dir, archive)

    return archive


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="构建 DotaModTool Windows 发布包")
    parser.add_argument(
        "--name",
        default=DEFAULT_NAME,
        help=f"可执行文件和 ZIP 的名称（默认：{DEFAULT_NAME}）",
    )
    parser.add_argument(
        "--console",
        action="store_true",
        help="保留控制台窗口，便于调试",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        archive = build(args.name, args.console)
    except BuildError as exc:
        print(f"构建失败：{exc}", file=sys.stderr)
        return 1
    except (OSError, zipfile.BadZipFile) as exc:
        print(f"构建失败：{exc}", file=sys.stderr)
        return 1

    size_mb = archive.stat().st_size / (1024 * 1024)
    print(f"构建完成：{archive}（{size_mb:.1f} MiB）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
