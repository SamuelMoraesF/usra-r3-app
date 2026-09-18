"""Rebuild the browser-only PDF worker (also required before local web builds)."""

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dart", default="dart", help="Dart SDK executable")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory(prefix="usra-pdf-worker-") as temporary:
        output = Path(temporary) / "report_pdf_worker.js"
        subprocess.run(
            [args.dart, "compile", "js", "-O2", "--no-source-maps",
             "-o", str(output), "tool/report_pdf_worker.dart"],
            cwd=root, check=True,
        )
        shutil.copyfile(output, root / "web" / output.name)


if __name__ == "__main__":
    main()
