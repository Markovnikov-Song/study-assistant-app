#!/usr/bin/env python3
"""Download NotoSansSC-Regular.ttf for use by PdfBookExporter.

Run this script from the repository root:
    python backend/assets/fonts/download_fonts.py

The script downloads the NotoSans Simplified Chinese variable TTF from the
official Google Fonts / noto-cjk GitHub repository and saves it as
``NotoSansSC-Regular.ttf`` in the same directory as this script.
"""

from __future__ import annotations

import os
import sys
import urllib.request
from pathlib import Path

FONTS_DIR = Path(__file__).parent
DEST = FONTS_DIR / "NotoSansSC-Regular.ttf"

# Primary source: noto-cjk variable TTF subset (SC) — valid TTF, works with reportlab
PRIMARY_URL = (
    "https://github.com/googlefonts/noto-cjk/raw/main"
    "/Sans/Variable/TTF/Subset/NotoSansSC-VF.ttf"
)

FALLBACK_URLS: list[str] = []


def download(url: str, dest: Path) -> bool:
    print(f"Downloading from:\n  {url}")
    try:
        urllib.request.urlretrieve(url, dest)
        size = dest.stat().st_size
        print(f"Saved to {dest} ({size:,} bytes)")
        return True
    except Exception as exc:
        print(f"Failed: {exc}")
        if dest.exists():
            dest.unlink()
        return False


def main() -> int:
    if DEST.exists():
        print(f"Font already exists: {DEST} ({DEST.stat().st_size:,} bytes)")
        return 0

    for url in [PRIMARY_URL, *FALLBACK_URLS]:
        if download(url, DEST):
            print("Done.")
            return 0

    print(
        "\nAll download attempts failed.\n"
        "Please download NotoSansSC-Regular.ttf manually and place it at:\n"
        f"  {DEST}\n"
        "See README.md in this directory for manual instructions."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
