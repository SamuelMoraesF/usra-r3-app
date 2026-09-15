"""Regression tests for release filenames, integrity and archive structure."""

from pathlib import Path
import os
import stat
import subprocess
import tarfile
import tempfile
import unittest
import zipfile

from package_build import checksum, package, verify_package


class PackageBuildTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="usra-package-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.tag = "v1.5.4"
        self.stem = "usra-r3-app-v1.5.4"

    def fixture(self, name, data=b"test build"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def test_individual_platform_names_and_checksums(self):
        cases = [
            ("android", "build/app/outputs/flutter-apk/app-release.apk", f"{self.stem}.apk"),
            ("web", "build/web/index.html", f"{self.stem}-web.zip"),
            ("linux", "build/linux/x64/release/bundle/usra_r3", f"{self.stem}-linux.tar.gz"),
            ("windows", "build/windows/x64/runner/Release/usra_r3.exe", f"{self.stem}-windows.zip"),
            ("macos", "build/macos/Build/Products/Release/usra_r3.app/Contents/MacOS/usra_r3", f"{self.stem}-macos.zip"),
        ]
        for platform, source, filename in cases:
            with self.subTest(platform=platform):
                self.fixture(source)
                package(platform, self.tag, self.root)
                artifact = self.root / "dist" / filename
                manifest = self.root / "dist" / f"SHA256SUMS-{self.stem}-{platform}.txt"
                self.assertEqual(manifest.read_text(), f"{checksum(artifact)}  {filename}\n")
                verify_package(artifact, manifest)
                artifact.write_bytes(b"corrupted download")
                with self.assertRaises(ValueError):
                    verify_package(artifact, manifest)

    def test_ci_preserves_android_and_web_layout(self):
        self.fixture("build/app/outputs/flutter-apk/app-debug.apk")
        package("android", root=self.root)
        self.assertTrue((self.root / "dist/app-debug.apk").is_file())
        self.fixture("build/web/index.html")
        self.fixture("build/web/assets/map.pmtiles")
        # Web is a separate job with a separate output directory.
        for path in (self.root / "dist").iterdir():
            path.unlink()
        package("web", root=self.root)
        manifest = (self.root / "dist/SHA256SUMS-web.txt").read_text()
        self.assertIn("  index.html\n", manifest)
        self.assertIn("  assets/map.pmtiles\n", manifest)
        package("web", root=self.root)
        self.assertEqual((self.root / "dist/SHA256SUMS-web.txt").read_text(), manifest)

    @unittest.skipIf(os.name == "nt", "Unix executable bits and framework symlinks")
    def test_desktop_archives_preserve_permissions_and_symlinks(self):
        binary = self.fixture("build/macos/Build/Products/Release/App.app/Contents/MacOS/app")
        binary.chmod(0o755)
        binary.with_name("alias").symlink_to("app")
        package("macos", self.tag, self.root)
        with zipfile.ZipFile(self.root / f"dist/{self.stem}-macos.zip") as archive:
            executable = archive.getinfo("App.app/Contents/MacOS/app")
            self.assertEqual((executable.external_attr >> 16) & 0o777, 0o755)
            alias = archive.getinfo("App.app/Contents/MacOS/alias")
            self.assertTrue(stat.S_ISLNK(alias.external_attr >> 16))
            self.assertEqual(archive.read(alias), b"app")
        self.fixture("build/linux/x64/release/bundle/usra_r3").chmod(0o755)
        package("linux", self.tag, self.root)
        with tarfile.open(self.root / f"dist/{self.stem}-linux.tar.gz") as archive:
            self.assertEqual(archive.getmember("./usra_r3").mode, 0o755)

    def test_combined_bundle_retains_legacy_structure(self):
        self.fixture("build/app/outputs/flutter-apk/app-release.apk")
        self.fixture("build/web/index.html")
        package("android", self.tag, self.root)
        package("web", self.tag, self.root)
        self.fixture("README.md", b"source fixture")
        for command in [
            ["git", "init", "-q"],
            ["git", "add", "README.md"],
            ["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false", "commit", "-qm", "fixture"],
        ]:
            subprocess.run(command, cwd=self.root, check=True, capture_output=True)
        previous = Path.cwd()
        try:
            os.chdir(self.root)
            package("bundle", self.tag)
        finally:
            os.chdir(previous)
        artifact = self.root / f"dist/{self.stem}.zip"
        verify_package(artifact, self.root / f"dist/SHA256SUMS-{self.tag}.txt")
        with zipfile.ZipFile(artifact) as archive:
            self.assertEqual(set(archive.namelist()), {f"{self.stem}.apk", "web/index.html", "source/README.md"})
            self.assertEqual(archive.read("source/README.md"), b"source fixture")

    def test_rejects_invalid_tag_and_missing_build(self):
        with self.assertRaises(ValueError):
            package("android", "../../wrong", self.root)
        with self.assertRaises(FileNotFoundError):
            package("android", self.tag, self.root)


if __name__ == "__main__":
    unittest.main()
