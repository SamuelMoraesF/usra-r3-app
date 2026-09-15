"""Package each platform without changing the established release filenames."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tarfile
import zipfile


def checksum(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_checksum(path, manifest):
    manifest.write_text(f"{checksum(path)}  {path.name}\n", encoding="utf-8")


def add_tree(archive, directory, prefix=""):
    """Preserve executable bits and macOS framework symlinks in ZIP files."""
    if not directory.is_dir():
        raise FileNotFoundError(directory)
    for root, dirs, files in os.walk(directory):
        dirs.sort()
        for name in sorted(files + [d for d in dirs if (Path(root) / d).is_symlink()]):
            path = Path(root) / name
            entry = prefix + path.relative_to(directory).as_posix()
            if path.is_symlink():
                info = zipfile.ZipInfo(entry)
                info.create_system = 3
                info.external_attr = path.lstat().st_mode << 16
                archive.writestr(info, os.readlink(path).encode())
            else:
                archive.write(path, entry)


def zip_tree(directory, output):
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
        add_tree(archive, directory)


def verify_package(path, manifest):
    expected = f"{checksum(path)}  {path.name}"
    if manifest.read_text(encoding="utf-8").strip() != expected:
        raise ValueError(f"Checksum mismatch: {path}")


def package_bundle(dist, tag):
    stem = f"usra-r3-app-{tag}"
    apk = dist / f"{stem}.apk"
    web = dist / f"{stem}-web.zip"
    verify_package(apk, dist / f"SHA256SUMS-{stem}-android.txt")
    verify_package(web, dist / f"SHA256SUMS-{stem}-web.txt")
    output = dist / f"{stem}.zip"
    # Stream the source archive and Web files; no duplicate build trees on disk.
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
        archive.write(apk, apk.name, compress_type=zipfile.ZIP_STORED)
        with zipfile.ZipFile(web) as web_archive:
            for member in web_archive.infolist():
                with web_archive.open(member) as source:
                    info = zipfile.ZipInfo("web/" + member.filename, member.date_time)
                    info.external_attr = member.external_attr
                    info.compress_type = zipfile.ZIP_DEFLATED
                    with archive.open(info, "w") as target:
                        shutil.copyfileobj(source, target)
        with subprocess.Popen(["git", "archive", "HEAD"], stdout=subprocess.PIPE) as process:
            with tarfile.open(fileobj=process.stdout, mode="r|") as sources:
                for member in sources:
                    if not member.isfile() and not member.issym():
                        continue
                    info = zipfile.ZipInfo("source/" + member.name)
                    info.create_system = 3
                    info.compress_type = zipfile.ZIP_DEFLATED
                    kind = stat.S_IFLNK if member.issym() else stat.S_IFREG
                    info.external_attr = (kind | member.mode) << 16
                    if member.issym():
                        archive.writestr(info, member.linkname)
                    else:
                        with sources.extractfile(member) as source, archive.open(info, "w") as target:
                            shutil.copyfileobj(source, target)
            if process.wait() != 0:
                raise RuntimeError("git archive failed")
    # Retain the historical checksum filename for the historical combined ZIP.
    write_checksum(output, dist / f"SHA256SUMS-{tag}.txt")


def package(platform, tag="", root=Path(".")):
    if tag and not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Use a stable release tag in the format vMAJOR.MINOR.PATCH")
    dist = root / "dist"
    dist.mkdir(exist_ok=True)
    stem = f"usra-r3-app-{tag or 'ci'}"
    if platform == "bundle":
        if not tag:
            raise ValueError("A release tag is required for the combined bundle")
        package_bundle(dist, tag)
        return
    if platform == "android":
        filename = "app-release.apk" if tag else "app-debug.apk"
        output = dist / (f"{stem}.apk" if tag else filename)
        shutil.copy2(root / "build/app/outputs/flutter-apk" / filename, output)
    elif platform == "web" and not tag:
        # Preserve the existing CI Web artifact layout (unpacked site at root).
        shutil.copytree(root / "build/web", dist, dirs_exist_ok=True)
        entries = sorted(path for path in dist.rglob("*") if path.is_file() and path.name != "SHA256SUMS-web.txt")
        (dist / "SHA256SUMS-web.txt").write_text(
            "".join(f"{checksum(path)}  {path.relative_to(dist).as_posix()}\n" for path in entries),
            encoding="utf-8",
        )
        return
    else:
        directories = {
            "web": "build/web",
            "linux": "build/linux/x64/release/bundle",
            "windows": "build/windows/x64/runner/Release",
            "macos": "build/macos/Build/Products/Release",
        }
        directory = root / directories[platform]
        extension = "tar.gz" if platform == "linux" else "zip"
        output = dist / f"{stem}-{platform}.{extension}"
        if platform == "linux":
            with tarfile.open(output, "w:gz", compresslevel=1) as archive:
                archive.add(directory, arcname=".")
        else:
            zip_tree(directory, output)
    manifest = f"SHA256SUMS-{stem}-{platform}.txt" if tag else f"SHA256SUMS-{platform}.txt"
    write_checksum(output, dist / manifest)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["android", "web", "linux", "windows", "macos", "bundle"])
    parser.add_argument("--tag", default="")
    arguments = parser.parse_args()
    package(arguments.platform, arguments.tag)
