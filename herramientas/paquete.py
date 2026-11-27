"""Mantiene el ZIP descargable a partir del addon preparado en el índice de Git."""

import argparse
from io import BytesIO
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
from tempfile import NamedTemporaryFile
from zipfile import BadZipFile, ZIP_DEFLATED, ZipFile, ZipInfo
from zlib import error as CompressionError


ROOT = Path(__file__).resolve().parents[1]
ADDON = "GuiaAventurero"
TOC = f"{ADDON}/{ADDON}.toc"
PACKAGE = f"{ADDON}-ultima.zip"


def git(root, *args, data=None, check=True):
    return subprocess.run(["git", *args], cwd=root, input=data, capture_output=True, check=check)


def staged_addon(root):
    entries = []
    index = git(root, "ls-files", "--stage", "-z", "--", f"{ADDON}/").stdout
    for entry in index.split(b"\0")[:-1]:
        metadata, name = entry.split(b"\t", 1)
        mode, object_id, stage = metadata.split()
        if mode not in (b"100644", b"100755") or stage != b"0":
            raise ValueError(f"Entrada del addon inapropiada para el ZIP: {name.decode('utf-8')}")
        entries.append((name.decode("utf-8"), object_id))

    query = b"".join(object_id + b"\n" for _, object_id in entries)
    blobs = BytesIO(git(root, "cat-file", "--batch", data=query).stdout)
    files = {}
    for name, object_id in entries:
        stored_id, kind, size = blobs.readline().split()
        if stored_id != object_id or kind != b"blob":
            raise ValueError(f"Git no devolvió el contenido preparado de {name}")
        contents = blobs.read(int(size))
        if blobs.read(1) != b"\n":
            raise ValueError(f"Contenido incompleto en Git para {name}")
        files[name] = contents
    return files


def addon_files(source):
    with ZipFile(source) as archive:
        files = {}
        names = set()
        for entry in archive.infolist():
            name = PurePosixPath(entry.filename)
            if (not name.parts or name.parts[0] != ADDON or ".." in name.parts
                    or "\\" in entry.filename or ":" in entry.filename
                    or name.as_posix().casefold() in names or stat.S_ISLNK(entry.external_attr >> 16)
                    or (not entry.is_dir() and len(name.parts) < 2)):
                raise ValueError(f"Entrada inesperada en el ZIP: {entry.filename}")
            names.add(name.as_posix().casefold())
            if not entry.is_dir():
                files[entry.filename] = archive.read(entry)
        return files


def matches(source, expected):
    try:
        return addon_files(source) == expected
    except (FileNotFoundError, BadZipFile, CompressionError, NotImplementedError, RuntimeError, ValueError):
        return False


def write_package(path, files):
    with NamedTemporaryFile(dir=path.parent, suffix=".zip", delete=False) as temporary:
        pending = Path(temporary.name)
    try:
        with ZipFile(pending, "w") as archive:
            for name, contents in sorted(files.items()):
                archive.writestr(ZipInfo(name), contents, compress_type=ZIP_DEFLATED)
        if not matches(pending, files):
            raise ValueError("El ZIP generado no coincide con el addon.")
        pending.replace(path)
    finally:
        pending.unlink(missing_ok=True)


def main(root=ROOT, argv=None):
    arguments = argparse.ArgumentParser(description=__doc__)
    arguments.add_argument("--check", action="store_true", help="Comprueba el ZIP preparado en el índice de Git.")
    args = arguments.parse_args(argv)
    try:
        expected = staged_addon(root)
        version, = re.findall(r"^## Version:[ \t]*(\S+)[ \t]*\r?$", expected[TOC].decode("utf-8-sig"), re.M)
        path = root / PACKAGE
        if args.check:
            staged = git(root, "show", f":{PACKAGE}", check=False)
            if staged.returncode or not matches(BytesIO(staged.stdout), expected):
                raise ValueError(f"{PACKAGE} falta o está desactualizado en Git. Genera y añade el ZIP.")
        elif not matches(path, expected):
            write_package(path, expected)
        print(f"{PACKAGE} · {version} · {len(expected)} archivos verificados")
        return 0
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode("utf-8", errors="replace").strip(), file=sys.stderr)
    except (BadZipFile, KeyError, OSError, ValueError) as error:
        print(error, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
