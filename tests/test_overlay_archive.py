from __future__ import annotations

import hashlib
import io
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOL = REPO_ROOT / "scripts" / "overlay_archive.py"


class OverlayArchiveTests(unittest.TestCase):
    def run_tool(self, *arguments: str, expected: int = 0) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [sys.executable, str(TOOL), *arguments],
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(expected, result.returncode, result.stderr)
        return result

    def test_round_trip_is_deterministic_and_root_owned(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "opt" / "gar").mkdir(parents=True)
            executable = source / "opt" / "gar" / "run"
            executable.write_text("#!/bin/sh\n", encoding="utf-8")
            executable.chmod(0o755)
            first = root / "first.tar.bz2"
            second = root / "second.tar.bz2"

            self.run_tool("create", "--input", str(source), "--output", str(first))
            self.run_tool("create", "--input", str(source), "--output", str(second))
            self.assertEqual(
                hashlib.sha256(first.read_bytes()).digest(),
                hashlib.sha256(second.read_bytes()).digest(),
            )
            with tarfile.open(first, "r:bz2") as archive:
                members = archive.getmembers()
                self.assertTrue(all(member.uid == 0 and member.gid == 0 for member in members))
                self.assertTrue(all(member.mtime == 0 for member in members))

            extracted = root / "extracted"
            self.run_tool("extract", "--input", str(first), "--output", str(extracted))
            self.assertEqual("#!/bin/sh\n", (extracted / "opt" / "gar" / "run").read_text())
            self.assertEqual(0o755, (extracted / "opt" / "gar" / "run").stat().st_mode & 0o777)

    def test_rejects_traversal_and_links_before_extraction(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name, member in (
                ("traversal", tarfile.TarInfo("../escape")),
                ("symlink", tarfile.TarInfo("opt")),
            ):
                archive_path = root / f"{name}.tar.bz2"
                payload = b"bad"
                if name == "symlink":
                    member.type = tarfile.SYMTYPE
                    member.linkname = "/tmp"
                    member.size = 0
                else:
                    member.size = len(payload)
                with tarfile.open(archive_path, "w:bz2") as archive:
                    archive.addfile(member, None if member.issym() else io.BytesIO(payload))
                output = root / f"{name}-output"
                self.run_tool(
                    "extract",
                    "--input",
                    str(archive_path),
                    "--output",
                    str(output),
                    expected=1,
                )
                self.assertEqual([], list(output.iterdir()))
            self.assertFalse((root / "escape").exists())

    def test_create_rejects_source_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "link").symlink_to("/tmp")
            self.run_tool(
                "create",
                "--input",
                str(source),
                "--output",
                str(root / "output.tar.bz2"),
                expected=1,
            )


if __name__ == "__main__":
    unittest.main()
