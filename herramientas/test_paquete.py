import io
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from zipfile import ZipFile

from paquete import ADDON, PACKAGE, TOC, git, main


class PackageTest(unittest.TestCase):
    def setUp(self):
        temporary = TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        git(self.root, "init", "-q")
        git(self.root, "config", "core.autocrlf", "true")
        (self.root / ADDON).mkdir()
        (self.root / TOC).write_bytes(b"## Version: 9.8.0\nModulo.lua\n")
        self.module = self.root / ADDON / "Modulo.lua"
        self.module.write_bytes(b"return 1\n")
        self.package = self.root / PACKAGE
        git(self.root, "add", ADDON)

    def command(self, *args):
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return main(self.root, args)

    def test_packages_only_the_staged_addon_and_keeps_matching_zip(self):
        self.module.write_bytes(b"return 2\n")
        (self.root / ADDON / "no-rastreado.lua").write_bytes(b"return 3")
        self.assertEqual(self.command(), 0)
        with ZipFile(self.package) as archive:
            self.assertEqual(set(archive.namelist()), {TOC, f"{ADDON}/Modulo.lua"})
            self.assertEqual(archive.read(f"{ADDON}/Modulo.lua"), b"return 1\n")
        git(self.root, "add", PACKAGE)
        self.assertEqual(self.command("--check"), 0)
        time = self.package.stat().st_mtime_ns
        self.assertEqual(self.command(), 0)
        self.assertEqual(self.package.stat().st_mtime_ns, time)

    def test_rejects_missing_and_stale_zip_then_rebuilds(self):
        self.assertEqual(self.command("--check"), 1)
        self.assertEqual(self.command(), 0)
        git(self.root, "add", PACKAGE)
        self.module.write_bytes(b"return 2\n")
        git(self.root, "add", str(self.module))
        self.assertEqual(self.command("--check"), 1)
        self.assertEqual(self.command(), 0)
        git(self.root, "add", PACKAGE)
        self.assertEqual(self.command("--check"), 0)
        with ZipFile(self.package) as archive:
            self.assertEqual(archive.read(f"{ADDON}/Modulo.lua"), b"return 2\n")

    def test_repairs_a_zip_with_an_extra_file(self):
        self.assertEqual(self.command(), 0)
        with ZipFile(self.package, "a") as archive:
            archive.writestr("AGENTS.md", "Solo para el repositorio")
        git(self.root, "add", PACKAGE)
        self.assertEqual(self.command("--check"), 1)
        self.assertEqual(self.command(), 0)
        git(self.root, "add", PACKAGE)
        self.assertEqual(self.command("--check"), 0)
